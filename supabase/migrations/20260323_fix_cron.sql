-- Drop the old cron job that uses current_setting()
SELECT cron.unschedule('send-push-hourly');

-- Recreate with hardcoded values
SELECT cron.schedule(
    'send-push-hourly',
    '0 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://nexrclgaqaeykpopvwmv.supabase.co/functions/v1/send-push',
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leHJjbGdhcWFleWtwb3B2d212Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDAxMDUzNiwiZXhwIjoyMDg5NTg2NTM2fQ._0uAP2txApL6wtEwSPa4o4blGkQY5b8sfHP3gQqUzYI"}'::jsonb,
        body := '{}'::jsonb
    );
    $$
);
