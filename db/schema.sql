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
CREATE INDEX IF NOT EXISTS idx_activity_started ON activity_events(started_at);
CREATE INDEX IF NOT EXISTS idx_activity_user ON activity_events(user_id, started_at);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices(status);
