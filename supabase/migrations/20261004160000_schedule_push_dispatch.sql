CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

DO $migration$
DECLARE
  existing_job_id bigint;
BEGIN
  SELECT jobid
    INTO existing_job_id
    FROM cron.job
   WHERE jobname = 'calimind-dispatch-push-reminders';

  IF existing_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(existing_job_id);
  END IF;

  PERFORM cron.schedule(
    'calimind-dispatch-push-reminders',
    '* * * * *',
    $job$
      SELECT net.http_post(
        url := (
          SELECT decrypted_secret
            FROM vault.decrypted_secrets
           WHERE name = 'SUPABASE_URL'
        ) || '/functions/v1/push-notifications',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'apikey', (
            SELECT decrypted_secret
              FROM vault.decrypted_secrets
             WHERE name = 'SUPABASE_ANON_KEY'
          ),
          'x-push-dispatch-secret', (
            SELECT decrypted_secret
              FROM vault.decrypted_secrets
             WHERE name = 'PUSH_DISPATCH_SECRET'
          )
        ),
        body := '{"action":"dispatch"}'::jsonb,
        timeout_milliseconds := 10000
      );
    $job$
  );
END
$migration$;
