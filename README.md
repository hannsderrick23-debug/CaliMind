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
Run `supabase/schema.sql` in your Supabase SQL editor.

Then run with your keys:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Or set them in `.env` (values already pre-filled for the demo project).

### 3. Run
```bash
flutter run                    # dev run (mock data works without Supabase)
flutter test                   # run unit test suite
flutter build apk --release    # Android release build
flutter build ipa              # iOS release build
```

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
flutter test test/scheduler_test.dart
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
