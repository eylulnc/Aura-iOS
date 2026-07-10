import WidgetKit
import SwiftUI

struct StreakEntryData: TimelineEntry {
    let date: Date
    let streak: Int
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntryData {
        StreakEntryData(date: .now, streak: 4)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntryData) -> Void) {
        completion(StreakEntryData(date: .now, streak: WidgetData.streak()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntryData>) -> Void) {
        let nextMidnight = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(3600)
        let entry = StreakEntryData(date: .now, streak: WidgetData.streak())
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct AuraStreakWidgetView: View {
    let entry: StreakEntryData

    var body: some View {
        VStack(spacing: 6) {
            Text("Streak")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if entry.streak != 0 {
                Text("🔥")
                    .font(.system(size: 28))
            }

            Text("\(entry.streak)")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(entry.streak > 0 ? Color.orange : .primary)

            Text(entry.streak == 1 ? "day" : "days")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "aura://open"))
    }
}

struct AuraStreakWidget: Widget {
    let kind: String = "AuraStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            AuraStreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Mood Streak")
        .description("Shows your current consecutive-day logging streak.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    AuraStreakWidget()
} timeline: {
    StreakEntryData(date: .now, streak: 4)
}
