# iOS Widget target setup

This checkout contains no `.xcodeproj` or `.xcworkspace` (only the Flutter
`ios/Runner` source scaffold), so a WidgetKit target cannot be registered,
embedded, or signed from repository configuration here. Complete these Xcode
steps once the Runner Xcode project is generated/openable:

1. Add a **Widget Extension** target named `CaliMindWidget` (Swift, WidgetKit).
   Set its bundle identifier to a unique identifier under your Apple team and
   use `ios/CaliMindWidget/Info.plist` as its Info.plist.
2. Add `CaliMindNextTaskWidget.swift` to the extension target only. Set the
   extension's deployment target to iOS 14 or later.
3. Add the App Groups capability to both the Runner app target and the widget
   extension target. Register `group.io.supabase.calimind` for your team and
   select that exact group on both targets. Assign
   `ios/Runner/Runner.entitlements` to Runner and
   `ios/CaliMindWidget/CaliMindWidget.entitlements` to the extension.
4. Set the widget extension's code-signing team and provisioning profile, then
   embed the extension in the Runner app using Xcode's normal Widget Extension
   target configuration.

`WidgetService.refresh` calls `HomeWidget.updateWidget(iOSName:
"CaliMindNextTaskWidget")`; the kind in the Swift source and the app-group
identifier must remain aligned with those Dart constants.

Task and schedule providers refresh the widget after changes, passing scheduled
task IDs in display order. Task-title sharing is opt-in and defaults to off.
The Settings toggle calls `WidgetService.setTaskTitleSharingEnabled`; it only
publishes a title when sharing is enabled.
`WidgetService.setTaskTitleSharingEnabled(false)` clears the published title
and restores generic copy while retaining the voice shortcut.

The action URI contract for both platforms is exactly
`io.supabase.calimind://voice-capture`
(`WidgetService.voiceCaptureDeepLink`). It uses the app's existing
`io.supabase.calimind` custom scheme and `voice-capture` URI host. Android
declares this scheme/host on `MainActivity`; its widget pending intent also
uses the `home_widget` launch action. iOS already registers the same scheme in
Runner's `Info.plist`, and the widget uses the same URI as its `widgetURL`.
The Flutter router sends this URI to the dashboard and prompts the user to tap
the microphone; speech recognition does not start automatically.
