# Background task reminder delivery

Task reminders are scheduled as native local notifications on the device and
as queued push jobs in Supabase. The local notification can fire while the app
is closed, provided the user granted notification permission and the
operating system has not restricted CaliMind. The scheduled Edge Function
dispatches queued FCM notifications once per minute, including when the app is
not running.

## Configure the dispatcher

1. Deploy the `push-notifications` Edge Function. Configure these Edge
   Function secrets in Supabase; never commit their values:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `FCM_PROJECT_ID`
   - `FCM_SERVICE_ACCOUNT`
   - `PUSH_DISPATCH_SECRET`
2. In the Supabase SQL Editor, store the project URL, anon key, and the exact
   same dispatch secret in Vault before applying the scheduler migration:

   ```sql
   select vault.create_secret(
     'https://YOUR_PROJECT_REF.supabase.co',
     'SUPABASE_URL'
   );
   select vault.create_secret('YOUR_SUPABASE_ANON_KEY', 'SUPABASE_ANON_KEY');
   select vault.create_secret(
     'THE_SAME_VALUE_AS_PUSH_DISPATCH_SECRET',
     'PUSH_DISPATCH_SECRET'
   );
   ```

   If a secret already exists, update it in Vault rather than creating a
   duplicate.
3. Apply the migrations, including
   `20261004160000_schedule_push_dispatch.sql`. It enables `pg_cron` and
   `pg_net` and schedules the authenticated dispatcher every minute.
4. Confirm the `calimind-dispatch-push-reminders` job is active in
   `cron.job`. Review recent request results in `net._http_response` and Edge
   Function logs if delivery fails.

The dispatcher endpoint has JWT verification disabled so Cron can call it;
it separately checks the `PUSH_DISPATCH_SECRET` header before accessing the
service-role queue. Keep this secret private and rotate it in both Edge
Function secrets and Vault together.

## Delivery behavior

The database creates a push job only for a future reminder on an incomplete
task. Updating the reminder, title, or completion state cancels pending jobs
and queues the current reminder when applicable. Push delivery requires an
authenticated device registered for that same Supabase user, working FCM
credentials, and operating-system notification permission. Native local
reminders remain a device-side fallback.

Push and local delivery can both reach the same device; users may see both
notifications for a reminder. Delivery timing is best-effort and can be
affected by device power-management settings or network availability.
