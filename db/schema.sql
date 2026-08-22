-- Homey Work Insights PostgreSQL schema
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT NOT NULL UNIQUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), email TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
  password_hash TEXT NOT NULL DEFAULT '', role TEXT NOT NULL DEFAULT 'employee' CHECK (role IN ('employee','manager','admin')),
  department_id UUID REFERENCES departments(id), active BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), external_id TEXT UNIQUE, serial_number TEXT UNIQUE,
  name TEXT NOT NULL, user_id UUID REFERENCES users(id), os TEXT, os_version TEXT, status TEXT NOT NULL DEFAULT 'unknown',
  mdm_source TEXT, last_seen_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS activity_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID REFERENCES users(id), device_id UUID REFERENCES devices(id),
  application TEXT, event_type TEXT NOT NULL, started_at TIMESTAMPTZ NOT NULL, ended_at TIMESTAMPTZ,
  duration_minutes INTEGER NOT NULL DEFAULT 0, source TEXT NOT NULL DEFAULT 'agent', metadata JSONB NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), provider TEXT NOT NULL UNIQUE, enabled BOOLEAN NOT NULL DEFAULT false,
  last_sync_at TIMESTAMPTZ, config JSONB NOT NULL DEFAULT '{}', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), actor_user_id UUID REFERENCES users(id), action TEXT NOT NULL,
  resource_type TEXT, resource_id TEXT, ip_address INET, metadata JSONB NOT NULL DEFAULT '{}', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS screenshot_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), device_id UUID NOT NULL REFERENCES devices(id), requested_by UUID NOT NULL REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','captured','rejected','expired')),
  reason TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), completed_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS screenshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), device_id UUID NOT NULL REFERENCES devices(id), request_id UUID REFERENCES screenshot_requests(id),
  image_url TEXT NOT NULL, captured_at TIMESTAMPTZ NOT NULL DEFAULT now(), admin_name TEXT, source TEXT NOT NULL DEFAULT 'Scalefusion Remote Cast', deleted_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS enrollment_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), key_hash TEXT NOT NULL UNIQUE, key_hint TEXT NOT NULL,
  created_by UUID REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(), expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ, revoked_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_activity_started ON activity_events(started_at);
CREATE INDEX IF NOT EXISTS idx_activity_user ON activity_events(user_id, started_at);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices(status);
CREATE INDEX IF NOT EXISTS idx_screenshot_captured ON screenshots(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_screenshot_requests_device ON screenshot_requests(device_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_enrollment_keys_active ON enrollment_keys(expires_at, revoked_at, used_at);
