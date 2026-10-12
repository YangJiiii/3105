# Portal API and admin site

The API validates license keys and device limits, serves the enabled feature catalog to the iOS app, and hosts the web admin page at `/`.

## Recommended first deployment

Use Supabase Postgres for persistent data and Render for the Node API/admin site. GitHub Actions builds the iOS app; it is not a persistent web server. Render's free web service sleeps after 15 minutes without traffic and its local files are temporary. Supabase's free projects can pause after a week of low activity, so this combination is suitable for a prototype. For continuous availability, use paid hosting/database plans.

1. Create a Supabase project and run `schema.sql` in its SQL Editor.
2. Copy its Postgres connection string. Keep it private.
3. In Render, create a Web Service from your fork using the root `render.yaml`, or set the root directory to `server`, build command to `npm install`, and start command to `npm start`.
4. Add environment variables in Render:
   - `DATABASE_URL`: the private Postgres connection string.
   - `DATABASE_SSL`: `true` for the hosted Supabase database.
   - `ADMIN_PASSWORD`: a unique, long password for the admin page.
   - `TOKEN_SECRET`: a random secret with at least 32 characters.
5. Open the Render URL. `/health` should return `{"ok":true}`; `/` is the admin page.
6. Set `PortalAPI.baseURL` in `ThreeOneOSFive/ContentView.swift` to the deployed HTTPS URL, then push the change to your fork so GitHub Actions can build it.

The admin creates keys with an expiry and device limit. The raw key is shown once; the database stores only its SHA-256 hash. The admin can revoke a key or clear its device bindings. Feature links must use HTTPS and open inside the app's web view. Never put `ADMIN_PASSWORD`, `TOKEN_SECRET`, or database credentials in the iOS app or a public repository.

For the app's server address, replace `https://YOUR-API-HOST` in `PortalAPI.baseURL` with the Render HTTPS URL. The API URL is public configuration; the admin password, token secret, and database connection string are private secrets and belong only in Render's environment settings.

## App build

The workflow at `.github/workflows/ios-build.yml` builds the iOS Simulator app on a GitHub-hosted macOS runner and publishes it as an artifact. That artifact is for the iOS Simulator. Installing on a physical iPhone requires Apple signing credentials and provisioning; a successful build alone does not install it.

