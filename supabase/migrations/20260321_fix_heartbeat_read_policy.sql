-- Allow anon to read heartbeat events (for debug UI)
CREATE POLICY "anon_read_heartbeat" ON device_heartbeat
    FOR SELECT USING (true);
