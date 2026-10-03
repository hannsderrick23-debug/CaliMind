# CaliMind

> **Voice-first daily task planner & intelligent scheduling assistant**
> Built with Flutter 3.24+ · Dart 3.5+ · Supabase · Riverpod

---

## Overview

CaliMind lets you capture tasks by speaking naturally, confirms them before saving, and computes a **deterministic, conflict-free, priority-weighted daily schedule** with 15-minute rest buffers — 100% offline-capable.

| Feature | Details |
|---|---|
| **Platform** | iOS 16+ · Android 12+ (API 31+) |
| **Framework** | Flutter 3.24+ / Dart 3.5+ |
| **State Management** | Riverpod 2.x |
| **Backend** | Supabase (PostgreSQL + Auth + RLS) |
| **Voice** | Native `speech_to_text` + Whisper fallback |

---

## Quick Start

### Prerequisites
- Flutter SDK ≥ 3.24 · Dart ≥ 3.5
- Supabase project (free tier works)

### 1. Clone & install
```bash
git clone <repo-url>
cd CaliMind
flutter pub get
```

### 2. Configure Supabase
Run `supabase/schema.sql` in your Supabase SQL editor. On an existing project,
apply `supabase/migrations/20261003000000_task_categories_and_reminders.sql` and
`supabase/migrations/20261003163900_task_persistence.sql` and
`supabase/migrations/20261003165300_schedule_persistence.sql`. These migrations
add task fields used by the app, enable authenticated-user task and schedule
access with row-level security, and grant the authenticated role the required
table operations.
Configure
`SUPABASE_URL` and `SUPABASE_ANON_KEY` at build time if you are not using the
project defaults:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Flutter does not automatically load `.env`; build-time values must be passed
with `--dart-define` (or supplied through your IDE's launch configuration).

### 3. Configure secure Groq AI
Groq requests run through the authenticated `groq` Supabase Edge Function.
The Groq API key must remain server-side; do not add it to Flutter assets,
`--dart-define`, or a distributed app build.

1. In the Supabase Dashboard, open **Edge Functions → Secrets** and add
   `GROQ_API_KEY` using the value in your local, git-ignored `.env`.
2. Deploy the function:
   ```bash
   supabase functions deploy groq --project-ref YOUR_PROJECT_ID
   ```

The function verifies the caller's Supabase session before using Groq for
Whisper transcription or command parsing. Command parsing uses Groq's
`openai/gpt-oss-120b` model. Audio uploads are limited to 5 MB.

### Task reminders and device security
Tasks can include an exact start time, due date, and local notification reminder.
Allow notification permission when saving a task with a reminder. Reminders are
scheduled on the device and restored after reboot. Biometric unlock can be
enabled in **Settings → Security**; the app verifies biometrics before opening
a restored signed-in session.

### Firebase push notifications
Local task reminders work without Firebase. Remote reminders require Firebase
platform configuration and a Supabase Edge Function deployment:

1. Create/register the Android and iOS apps in a Firebase project. Add
   `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
   using Firebase's setup instructions. The Android Google Services Gradle
   plugin is applied when `google-services.json` is present. Keep these project
   configuration files out of public repositories where your project policy
   requires it.
2. Enable Firebase Cloud Messaging and configure APNs for iOS. Firebase
   notification permission is requested when a signed-in user registers a
   device. The app sends its FCM token only to the authenticated
   `push-notifications` function.
3. Apply
   `supabase/migrations/20261004000000_push_notifications.sql` to create the
   private token registry and server-side reminder queue.
4. Add these secrets in **Supabase Dashboard → Edge Functions → Secrets**:
   `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT` (the service-account JSON text),
   and a random `PUSH_DISPATCH_SECRET`. The service account should have
   Firebase Cloud Messaging send permission. `SUPABASE_URL`,
   `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are provided to hosted
   Supabase functions; never put the service-account private key or service
   role key in the Flutter app.
5. Deploy the function with platform JWT verification disabled because the
   function performs its own Supabase user check for registration and validates
   the dispatch secret for cron requests:
   ```bash
   supabase functions deploy push-notifications --no-verify-jwt \
     --project-ref YOUR_PROJECT_ID
   ```
6. Enable the `pg_cron`, `pg_net`, and Vault extensions in Supabase. Store the
   function URL and the same random dispatch secret in Vault, then schedule the
   dispatcher once per minute:
   ```sql
   select vault.create_secret(
     'https://YOUR_PROJECT_ID.supabase.co/functions/v1/push-notifications',
     'calimind_push_function_url'
   );
   select vault.create_secret('YOUR_RANDOM_PUSH_DISPATCH_SECRET',
     'calimind_push_dispatch_secret');

   select cron.schedule('calimind-push-reminders', '* * * * *', $$
     select net.http_post(
       url := (select decrypted_secret from vault.decrypted_secrets
               where name = 'calimind_push_function_url'),
       headers := jsonb_build_object(
         'Content-Type', 'application/json',
         'X-Push-Dispatch-Secret',
           (select decrypted_secret from vault.decrypted_secrets
            where name = 'calimind_push_dispatch_secret')
       ),
       body := '{"action":"dispatch"}'::jsonb
     );
   $$);
   ```

The task trigger queues future reminders server-side. The scheduled dispatcher
sends them to registered devices and removes invalid FCM tokens. If Firebase
native configuration is missing, startup logs the setup issue and preserves
the existing local reminder behavior. Generating a schedule sends an immediate
"Schedule ready" push to the signed-in user's registered devices; it uses the
same deployed function and Firebase secrets but does not depend on the cron
dispatcher. A message in the app explains when the device has no registered
token or the push could not be delivered.

### 4. Run
```bash
flutter run
flutter test                   # run unit test suite
flutter build apk --release    # Android release build
flutter build ipa              # iOS release build
```

### Authentication providers

Email/password sign-in and registration use Supabase Auth. For Google and Apple
sign-in, enable each provider in the Supabase project's Authentication settings
and add `io.supabase.calimind://login-callback` to its allowed redirect URLs.
Configure the provider's OAuth credentials in Supabase as required by that
provider. Password recovery uses the same callback URL and returns to CaliMind
to complete the password change.

The Android and iOS projects register the `io.supabase.calimind` callback
scheme. If you change it, update the app's OAuth/reset redirect URI and the
native URL scheme declarations together.

---

## Architecture

```
lib/
├── main.dart                  # Entry point, Supabase init, ProviderScope
├── app.dart                   # MaterialApp.router + CaliMind dark theme
├── core/                      # Constants, services, utilities
├── data/                      # Datasources + repositories
├── domain/                    # Models + pure Dart use-cases
└── presentation/              # Riverpod providers + screens + widgets
```

### Key Architectural Decisions
- **Offline-first**: `GenerateScheduleUseCase` is pure Dart — works in-flight with no network.
- **Explicit confirmation**: Voice → Parse → Edit → Confirm → Save. No phantom tasks.
- **Deterministic scheduler**: Phase 1 fixes exact-time tasks; Phase 2 floats tasks by priority rank with 15m buffers.
- **Study cap**: Any study task >120min is auto-chunked into ≤120min blocks.
- **Secure token storage**: `flutter_secure_storage` (iOS Keychain / Android EncryptedSharedPrefs).

---

## Voice Commands

Speak naturally; you do not need to begin with "add" or "create". CaliMind
transcribes the recording, asks the AI parser to structure the request, and
shows a review card before saving. For example, "I have to email my lecturer
tomorrow", "I should revise calculus tonight", and "Don't let me forget to call
Mum" are task requests. "Thank you" or a general question is not a task.

| Phrase | Effect |
|---|---|
| *"Add study calculus for 45 minutes priority 1"* | Adds a Study task |
| *"Remind me to submit class rep report for 20 minutes"* | Adds a Class Rep task |
| *"I need to prepare club budget for 2 hours priority 1"* | Adds a Club President task |
| *"Create buy groceries"* | Adds a Personal task (30m default) |
| *"Plan my day"* or *"Generate my schedule"* | Runs the scheduler |

**FAB gestures:**
- **Tap** → Start/stop voice capture
- **Long-press** → Open manual task input sheet

---

## Tests

```bash
flutter test
```

Covers all PRD acceptance criteria (Section 14):
- ✅ Buffer invariant (≥15m between every slot)
- ✅ Study cap (no slot >120min)
- ✅ Exact-time priority (fixed before floating)
- ✅ Diagnostic integrity (human-readable failure reasons)
- ✅ Voice parser for all 5 acceptance phrases
- ✅ Completed tasks excluded from scheduling

---

## Database Schema

See [`supabase/schema.sql`](supabase/schema.sql) for full SQL including:
- RLS policies (all tables bound to `auth.uid()`)
- `tasks_timestamps` trigger (auto-updates `updated_at`, sets `completed_at`)
- `on_auth_user_created` trigger (auto-creates `profiles` row)
- GiST exclusion constraint (zero overlapping schedule blocks)

---

## Roadmap

| Phase | Features |
|---|---|
| **MVP (Weeks 1–4)** | ✅ Domain models · ✅ Scheduler · ✅ Voice capture · ✅ Dashboard · ✅ Task CRUD |
| **Phase 2 (Weeks 5–7)** | TTS confirmations · MFA setup screen · Data retention · share_plus announcements |
| **Phase 3 (Weeks 8–10)** | Lock screen widgets · Local notifications · Biometric app lock |
