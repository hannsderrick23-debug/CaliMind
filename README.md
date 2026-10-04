<div align="center">
  <img src="assets/branding/calimind_icon.png" alt="CaliMind app icon" width="88" height="88">

  # CaliMind

  **Make room for what matters.**

  A voice-first daily planner for calmer, more intentional days.

  [![Latest release](https://img.shields.io/github/v/release/hannsderrick23-debug/CaliMind?style=for-the-badge&color=641A91)](https://github.com/hannsderrick23-debug/CaliMind/releases/latest)
  [![Android release workflow](https://img.shields.io/github/actions/workflow/status/hannsderrick23-debug/CaliMind/release.yml?branch=main&label=Android%20release&style=for-the-badge)](https://github.com/hannsderrick23-debug/CaliMind/actions/workflows/release.yml)
  ![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-641A91?style=for-the-badge&logo=flutter&logoColor=white)
  ![Dart](https://img.shields.io/badge/Dart-3.5%2B-641A91?style=for-the-badge&logo=dart&logoColor=white)
</div>

## What CaliMind does

CaliMind brings task capture, daily planning, and focused work together in a
mobile app. Add tasks by speaking or typing, organize them around your day, and
adjust your plan as priorities change.

## Features

- **Voice task capture** — speak naturally, review the interpreted task, and
  confirm it before saving.
- **Flexible task management** — create, edit, complete, and organize tasks by
  focus category, due date, priority, duration, and recurrence.
- **Task notes and details** — open a task card to review its details and keep a
  short note with it.
- **Daily scheduling** — generate a proposed schedule, review it, and choose
  what to save. Replan remaining tasks while preserving completed work.
- **Calendar-aware planning** — optionally use busy times from calendars synced
  to an Android device, including Google Calendar. Event details stay on-device.
- **Calendar event handoff** — on Android, open a task as a draft in an installed
  calendar app, choose a synced calendar, and review it before saving.
- **Focus sessions** — use a built-in timer to give one task your attention.
- **Progress insights** — review weekly progress and recognize steady effort.
- **Aventor Eye** — opt in to short, AI-generated schedule insights. Task titles
  and timing are sent to Groq only while this feature is enabled; calendar busy
  times are included only when calendar access is separately enabled. Generated
  insights are cached on the device.
- **Reminders and notifications** — configure device notifications and reminder
  sounds for tasks and schedule updates.
- **Phone Clock alarms** — optionally open Android Clock with a task time
  prefilled, then review and confirm the alarm in Clock. This is separate from
  task-date notifications.
- **Secure sign-in** — account access, password recovery, and biometric unlock
  where supported.
- **Home-screen widgets** — view useful task information on supported devices.

## Get CaliMind

Download the latest Android APK from
[GitHub Releases](https://github.com/hannsderrick23-debug/CaliMind/releases/latest).
New Android releases are built and published automatically when a `v*` version
tag is pushed.

## Run from source

### Requirements

- Flutter SDK 3.35 or later
- Dart SDK 3.9 or later

### Start the app

```sh
flutter pub get
flutter run
```

### Enable Aventor Eye

Aventor Eye requires the Supabase Edge Function and a Groq API key:

```sh
supabase functions deploy aventor-eye
supabase secrets set GROQ_API_KEY=your-groq-api-key
```

The function authenticates requests using Supabase and calls Groq server-side;
the Groq key must never be added to the mobile app.

## Plan your day

1. Create an account or sign in.
2. Add a task with the microphone or task form. Review voice-captured details
   and confirm before saving.
3. Set a focus category and add details such as priority, duration, due date,
   or recurrence.
4. Open **Schedule**, generate a proposed plan, and review scheduled and
   unscheduled tasks before saving.
5. Start a focus session from a task and check weekly progress as you complete
   work.
6. Configure reminders, calendar access, security, and profile preferences in
   **Settings**.

## Why CaliMind

CaliMind is designed to make planning feel more manageable—not to fill every
minute. Voice capture gets tasks out of your head, schedule review keeps
changes in your hands, and focus sessions help turn a busy list into one clear
next step.

## Built by

CaliMind is developed by **Aventorgo LLC**.

[![Visit Aventorgo](https://img.shields.io/badge/Visit-Aventorgo%20LLC-641A91?style=for-the-badge)](https://aventorgo.vercel.app/)

## License

This repository does not currently include a `LICENSE` file. All rights are
reserved by the copyright holder; this README does not grant permission to
reuse, modify, or redistribute the app.
