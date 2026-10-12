import crypto from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import express from "express";
import rateLimit from "express-rate-limit";
import pg from "pg";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const { Pool } = pg;
const required = ["DATABASE_URL", "ADMIN_PASSWORD", "TOKEN_SECRET"];
for (const name of required) if (!process.env[name]) throw new Error(`Missing ${name}`);

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL === "true" ? { rejectUnauthorized: false } : undefined
});
const app = express();
app.disable("x-powered-by");
app.use(express.json({ limit: "32kb" }));
app.use(express.static(path.join(__dirname, "public"), { index: false }));
app.get("/", (_req, res) => res.sendFile(path.join(__dirname, "public", "admin.html")));
app.get("/health", async (_req, res) => {
  try { await pool.query("select 1"); res.json({ ok: true }); }
  catch { res.status(503).json({ ok: false }); }
});

const activateLimit = rateLimit({ windowMs: 15 * 60 * 1000, limit: 20, standardHeaders: "draft-8", legacyHeaders: false });
const adminLoginLimit = rateLimit({ windowMs: 15 * 60 * 1000, limit: 8, standardHeaders: "draft-8", legacyHeaders: false });
const b64 = (value) => Buffer.from(value).toString("base64url");
const signature = (value) => crypto.createHmac("sha256", process.env.TOKEN_SECRET).update(value).digest("base64url");
function issueToken(payload, seconds) {
  const head = b64(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = b64(JSON.stringify({ ...payload, exp: Math.floor(Date.now() / 1000) + seconds }));
  const unsigned = `${head}.${body}`;
  return `${unsigned}.${signature(unsigned)}`;
}
function readToken(value) {
  try {
    const [head, body, sig] = value.split(".");
    const expected = signature(`${head}.${body}`);
    const a = Buffer.from(sig); const b = Buffer.from(expected);
    if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
    const payload = JSON.parse(Buffer.from(body, "base64url").toString("utf8"));
    return payload.exp > Math.floor(Date.now() / 1000) ? payload : null;
  } catch { return null; }
}
function bearer(req) {
  const match = /^Bearer (.+)$/.exec(req.get("authorization") ?? "");
  return match ? readToken(match[1]) : null;
}
function requireAdmin(req, res, next) {
  const token = bearer(req);
  if (token?.role !== "admin") return res.status(401).json({ message: "Phiên quản trị đã hết hạn. Hãy đăng nhập lại." });
  req.admin = token;
  next();
}
function normalizeKey(value) { return String(value ?? "").toUpperCase().replace(/[^A-Z0-9]/g, ""); }
function hashKey(value) { return crypto.createHash("sha256").update(normalizeKey(value)).digest("hex"); }
function safeEqualText(left, right) {
  const a = Buffer.from(String(left)); const b = Buffer.from(String(right));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
function cleanText(value, max) { return String(value ?? "").trim().slice(0, max); }
function httpsURL(value) {
  try { const url = new URL(value); return url.protocol === "https:" ? url.toString() : null; }
  catch { return null; }
}
function newKey() {
  const raw = crypto.randomBytes(10).toString("hex").toUpperCase();
  return raw.match(/.{1,5}/g).join("-");
}

app.post("/api/admin/login", adminLoginLimit, (req, res) => {
  if (!safeEqualText(req.body?.password, process.env.ADMIN_PASSWORD)) return res.status(401).json({ message: "Mật khẩu quản trị không đúng." });
  res.json({ token: issueToken({ role: "admin" }, 8 * 60 * 60) });
});

app.post("/api/activate", activateLimit, async (req, res, next) => {
  const client = await pool.connect();
  try {
    const key = normalizeKey(req.body?.key);
    const deviceID = cleanText(req.body?.deviceID, 128);
    if (key.length < 12 || !deviceID) return res.status(400).json({ message: "Nhập key và mã thiết bị hợp lệ." });
    await client.query("begin");
    const result = await client.query("select id, expires_at, max_devices, device_ids, active from access_keys where key_hash = $1 for update", [hashKey(key)]);
    const license = result.rows[0];
    if (!license || !license.active || new Date(license.expires_at) <= new Date()) {
      await client.query("rollback");
      return res.status(403).json({ message: "Key không hợp lệ, đã hết hạn hoặc đã bị thu hồi." });
    }
    let devices = license.device_ids ?? [];
    if (!devices.includes(deviceID)) {
      if (devices.length >= license.max_devices) {
        await client.query("rollback");
        return res.status(403).json({ message: "Key đã dùng hết số thiết bị được cấp." });
      }
      devices = [...devices, deviceID];
      await client.query("update access_keys set device_ids = $1 where id = $2", [devices, license.id]);
    }
    await client.query("commit");
    const seconds = Math.max(60, Math.floor((new Date(license.expires_at).getTime() - Date.now()) / 1000));
    res.json({ token: issueToken({ role: "device", keyId: license.id, deviceID }, seconds), expiresAt: new Date(license.expires_at).toISOString() });
  } catch (error) { await client.query("rollback").catch(() => {}); next(error); }
  finally { client.release(); }
});

app.get("/api/catalog", async (req, res, next) => {
  try {
    const token = bearer(req);
    if (token?.role !== "device" || !token.keyId || !token.deviceID) return res.status(401).json({ message: "Key không hợp lệ. Nhập lại key để tiếp tục." });
    const licenseResult = await pool.query("select expires_at, device_ids from access_keys where id = $1 and active = true", [token.keyId]);
    const license = licenseResult.rows[0];
    if (!license || new Date(license.expires_at) <= new Date() || !(license.device_ids ?? []).includes(token.deviceID)) return res.status(401).json({ message: "Key đã hết hạn hoặc không còn hiệu lực." });
    const [featureResult, noticeResult] = await Promise.all([
      pool.query("select id, category, title, description, icon, url from portal_features where enabled = true order by category, created_at desc"),
      pool.query("select id, title, body from portal_notices where active = true order by created_at desc limit 10")
    ]);
    res.json({ features: featureResult.rows, notices: noticeResult.rows, expiresAt: new Date(license.expires_at).toISOString() });
  } catch (error) { next(error); }
});

app.get("/api/admin/keys", requireAdmin, async (_req, res, next) => {
  try {
    const result = await pool.query("select id, key_hint as \"keyHint\", expires_at as \"expiresAt\", max_devices as \"maxDevices\", cardinality(device_ids) as \"deviceCount\", active, created_at as \"createdAt\" from access_keys order by created_at desc");
    res.json(result.rows);
  } catch (error) { next(error); }
});
app.post("/api/admin/keys", requireAdmin, async (req, res, next) => {
  try {
    const expiresAt = new Date(req.body?.expiresAt);
    const maxDevices = Number(req.body?.maxDevices);
    if (!Number.isFinite(expiresAt.getTime()) || expiresAt <= new Date() || !Number.isInteger(maxDevices) || maxDevices < 1 || maxDevices > 100) return res.status(400).json({ message: "Chọn ngày hết hạn trong tương lai và giới hạn thiết bị từ 1 đến 100." });
    const key = newKey();
    const hint = `••••-${key.slice(-5)}`;
    const result = await pool.query("insert into access_keys (key_hash, key_hint, expires_at, max_devices) values ($1, $2, $3, $4) returning id, expires_at as \"expiresAt\", max_devices as \"maxDevices\"", [hashKey(key), hint, expiresAt.toISOString(), maxDevices]);
    res.status(201).json({ ...result.rows[0], key });
  } catch (error) { next(error); }
});
app.post("/api/admin/keys/:id/revoke", requireAdmin, async (req, res, next) => {
  try { await pool.query("update access_keys set active = false where id = $1", [req.params.id]); res.json({ ok: true }); }
  catch (error) { next(error); }
});
app.post("/api/admin/keys/:id/reset-devices", requireAdmin, async (req, res, next) => {
  try { await pool.query("update access_keys set device_ids = '{}' where id = $1", [req.params.id]); res.json({ ok: true }); }
  catch (error) { next(error); }
});

app.get("/api/admin/features", requireAdmin, async (_req, res, next) => {
  try { const result = await pool.query("select id, category, title, description, icon, url, enabled from portal_features order by category, created_at desc"); res.json(result.rows); }
  catch (error) { next(error); }
});
app.post("/api/admin/features", requireAdmin, async (req, res, next) => {
  try {
    const category = cleanText(req.body?.category, 48); const title = cleanText(req.body?.title, 80);
    const description = cleanText(req.body?.description, 240); const icon = cleanText(req.body?.icon, 48) || "sparkles";
    const url = httpsURL(req.body?.url);
    if (!category || !title || !url) return res.status(400).json({ message: "Cần có nhóm, tên chức năng và liên kết HTTPS hợp lệ." });
    const result = await pool.query("insert into portal_features (category, title, description, icon, url) values ($1,$2,$3,$4,$5) returning id, category, title, description, icon, url, enabled", [category, title, description, icon, url]);
    res.status(201).json(result.rows[0]);
  } catch (error) { next(error); }
});
app.delete("/api/admin/features/:id", requireAdmin, async (req, res, next) => {
  try { await pool.query("delete from portal_features where id = $1", [req.params.id]); res.json({ ok: true }); }
  catch (error) { next(error); }
});
app.post("/api/admin/features/:id/toggle", requireAdmin, async (req, res, next) => {
  try { await pool.query("update portal_features set enabled = not enabled where id = $1", [req.params.id]); res.json({ ok: true }); }
  catch (error) { next(error); }
});

app.get("/api/admin/notices", requireAdmin, async (_req, res, next) => {
  try { const result = await pool.query("select id, title, body, active from portal_notices order by created_at desc"); res.json(result.rows); }
  catch (error) { next(error); }
});
app.post("/api/admin/notices", requireAdmin, async (req, res, next) => {
  try {
    const title = cleanText(req.body?.title, 100); const body = cleanText(req.body?.body, 600);
    if (!title || !body) return res.status(400).json({ message: "Nhập tiêu đề và nội dung thông báo." });
    const result = await pool.query("insert into portal_notices (title, body) values ($1,$2) returning id, title, body, active", [title, body]);
    res.status(201).json(result.rows[0]);
  } catch (error) { next(error); }
});
app.delete("/api/admin/notices/:id", requireAdmin, async (req, res, next) => {
  try { await pool.query("delete from portal_notices where id = $1", [req.params.id]); res.json({ ok: true }); }
  catch (error) { next(error); }
});

app.use((error, _req, res, _next) => {
  console.error("request failed", error?.message);
  res.status(500).json({ message: "Máy chủ gặp lỗi. Thử lại sau." });
});
const port = Number(process.env.PORT) || 3000;
app.listen(port, "0.0.0.0", () => console.log(`Portal server listening on ${port}`));

