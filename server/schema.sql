create extension if not exists pgcrypto;

create table if not exists access_keys (
  id uuid primary key default gen_random_uuid(),
  key_hash text unique not null,
  key_hint text not null,
  expires_at timestamptz not null,
  max_devices integer not null check (max_devices between 1 and 100),
  device_ids text[] not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists portal_features (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  title text not null,
  description text not null default '',
  icon text not null default 'sparkles',
  url text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists portal_notices (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists access_keys_active_expiry_idx on access_keys (active, expires_at);
create index if not exists portal_features_enabled_idx on portal_features (enabled, category);

