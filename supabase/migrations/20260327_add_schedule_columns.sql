-- Add per-device capture schedule columns
ALTER TABLE device_tokens 
    ADD COLUMN IF NOT EXISTS primary_hour INT DEFAULT 2,
    ADD COLUMN IF NOT EXISTS primary_minute INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS retry_hour INT DEFAULT 5,
    ADD COLUMN IF NOT EXISTS retry_minute INT DEFAULT 0;
