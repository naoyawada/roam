-- Revert the test "minutely" cron job to a properly named schedule.
-- The cron still runs every minute because users can configure arbitrary
-- capture times (e.g. 2:37 AM). The send-push Edge Function exits fast
-- when no devices match and includes dedup logic to prevent double-sends.
SELECT cron.unschedule('send-push-minutely');
SELECT cron.schedule(
    'send-push-scheduled',
    '* * * * *',
    $$
    SELECT net.http_post(
        url := 'https://nexrclgaqaeykpopvwmv.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key_new')
        ),
        body := '{}'::jsonb
    );
    $$
);
