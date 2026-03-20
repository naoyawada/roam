-- Device tokens table: stores APNs tokens per device
CREATE TABLE IF NOT EXISTS device_tokens (
    device_id TEXT PRIMARY KEY,
    token TEXT NOT NULL,
    timezone TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Device heartbeat table: observability events from iOS
CREATE TABLE IF NOT EXISTS device_heartbeat (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_id TEXT NOT NULL,
    event TEXT NOT NULL,
    payload JSONB,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Push log table: tracks push notifications sent by the Edge Function
CREATE TABLE IF NOT EXISTS push_log (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_id TEXT NOT NULL,
    status TEXT NOT NULL,
    apns_response JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_heartbeat_device_id ON device_heartbeat(device_id);
CREATE INDEX IF NOT EXISTS idx_heartbeat_timestamp ON device_heartbeat(timestamp);
CREATE INDEX IF NOT EXISTS idx_push_log_device_id ON push_log(device_id);
CREATE INDEX IF NOT EXISTS idx_push_log_created_at ON push_log(created_at);

-- Auto-update updated_at on device_tokens
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER device_tokens_updated_at
    BEFORE UPDATE ON device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- RLS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_heartbeat ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_log ENABLE ROW LEVEL SECURITY;

-- Device tokens: anon can upsert
CREATE POLICY "anon_upsert_device_tokens" ON device_tokens
    FOR ALL USING (true) WITH CHECK (true);

-- Heartbeat: anon can insert
CREATE POLICY "anon_insert_heartbeat" ON device_heartbeat
    FOR INSERT WITH CHECK (true);

-- Push log: service_role can write (Edge Function)
CREATE POLICY "service_insert_push_log" ON push_log
    FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- Push log: anon can read
CREATE POLICY "anon_read_push_log" ON push_log
    FOR SELECT USING (true);
