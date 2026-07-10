import WidgetKit
import SwiftUI

struct MoodEntryData: TimelineEntry {
    let date: Date
    let mood: MoodFace?
    let dateLabel: String
}

struct MoodProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodEntryData {
        MoodEntryData(date: .now, mood: getMoodFace(id: 8), dateLabel: WidgetData.dateLabel)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodEntryData) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodEntryData>) -> Void) {
        let nextMidnight = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> MoodEntryData {
        MoodEntryData(date: .now, mood: WidgetData.todayMood(), dateLabel: WidgetData.dateLabel)
    }
}

struct AuraMoodWidgetView: View {
    let entry: MoodEntryData

    var body: some View {
        VStack(spacing: 6) {
            Text("Today's Mood")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if let mood = entry.mood {
                Image(mood.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                Text(mood.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(mood.color)
            } else {
                ZStack {
                    Circle()
                        .fill(.quaternary)
                        .frame(width: 56, height: 56)
                    Text("+")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text("Log your mood")
                    .font(.system(size: 15, weight: .semibold))
            }

            Text(entry.dateLabel)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(entry.mood == nil ? URL(string: "aura://logMood") : URL(string: "aura://open"))
    }
}

struct AuraMoodWidget: Widget {
    let kind: String = "AuraMoodWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodProvider()) { entry in
            AuraMoodWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Mood")
        .description("Shows the mood you logged today.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    AuraMoodWidget()
} timeline: {
    MoodEntryData(date: .now, mood: getMoodFace(id: 8), dateLabel: "Today")
    MoodEntryData(date: .now, mood: nil, dateLabel: "Today")
}
