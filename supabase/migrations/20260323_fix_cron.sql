-- Drop the old cron job that uses current_setting()
SELECT cron.unschedule('send-push-hourly');

-- Recreate — key is stored in vault (see 20260324 migration)
SELECT cron.schedule(
    'send-push-hourly',
    '0 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://nexrclgaqaeykpopvwmv.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
        ),
        body := '{}'::jsonb
    );
    $$
);
