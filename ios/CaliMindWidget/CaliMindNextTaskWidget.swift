import SwiftUI
import WidgetKit

private let widgetKind = "CaliMindNextTaskWidget"
private let appGroupIdentifier = "group.io.supabase.calimind"

struct CaliMindWidgetEntry: TimelineEntry {
    let date: Date
    let taskTitle: String?
}

struct CaliMindWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaliMindWidgetEntry {
        CaliMindWidgetEntry(date: Date(), taskTitle: nil)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (CaliMindWidgetEntry) -> Void
    ) {
        completion(currentEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CaliMindWidgetEntry>) -> Void
    ) {
        let entry = currentEntry()
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60))))
    }

    private func currentEntry() -> CaliMindWidgetEntry {
        let storedTitle = UserDefaults(suiteName: appGroupIdentifier)?
            .string(forKey: "next_task_title")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return CaliMindWidgetEntry(
            date: Date(),
            taskTitle: storedTitle?.isEmpty == false ? storedTitle : nil
        )
    }
}

struct CaliMindNextTaskWidgetView: View {
    var entry: CaliMindWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UP NEXT")
                .font(.caption.weight(.bold))
                .foregroundColor(Color(red: 0.85, green: 0.74, blue: 0.95))

            Text(entry.taskTitle ?? "Open CaliMind to see your next task")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Text("＋ Voice capture")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(red: 0.54, green: 0.32, blue: 0.70))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.39, green: 0.10, blue: 0.57),
                    Color(red: 0.20, green: 0.07, blue: 0.30),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .widgetURL(URL(string: "io.supabase.calimind://voice-capture"))
    }
}

struct CaliMindNextTaskWidget: Widget {
    let kind = widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaliMindWidgetProvider()) { entry in
            CaliMindNextTaskWidgetView(entry: entry)
        }
        .configurationDisplayName("CaliMind Next Task")
        .description("See your next task and open voice capture.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CaliMindWidgetBundle: WidgetBundle {
    var body: some Widget {
        CaliMindNextTaskWidget()
    }
}
