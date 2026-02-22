import WidgetKit
import SwiftUI

// MARK: - Data Model

struct LexstaEntry: TimelineEntry {
    let date: Date
    let currentBook: String
    let currentAuthor: String
    let todayMinutes: Int
    let streak: Int
    let progressPercent: Double
}

// MARK: - Provider

struct Provider: TimelineProvider {
    let appGroup = "group.com.acoeffic.readon"
    
    func placeholder(in context: Context) -> LexstaEntry {
        LexstaEntry(date: Date(), currentBook: "Le Petit Prince",
                    currentAuthor: "Saint-Exupéry", todayMinutes: 32,
                    streak: 7, progressPercent: 0.65)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LexstaEntry) -> Void) {
        completion(placeholder(in: context))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LexstaEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: appGroup)
        let entry = LexstaEntry(
            date: Date(),
            currentBook: defaults?.string(forKey: "currentBook") ?? "Aucun livre",
            currentAuthor: defaults?.string(forKey: "currentAuthor") ?? "",
            todayMinutes: defaults?.integer(forKey: "todayMinutes") ?? 0,
            streak: defaults?.integer(forKey: "streak") ?? 0,
            progressPercent: defaults?.double(forKey: "progressPercent") ?? 0.0
        )
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Colors

extension Color {
    static let lexstaGreen = Color(red: 107/255, green: 152/255, blue: 141/255)
    static let lexstaCream = Color(red: 250/255, green: 245/255, blue: 235/255)
    static let lexstaGreenDark = Color(red: 80/255, green: 115/255, blue: 106/255)
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: LexstaEntry
    
    var body: some View {
        ZStack {
            Color.lexstaCream
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("LEXSTA")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .foregroundColor(.lexstaGreen)
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("\(entry.streak)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.lexstaGreenDark)
                    }
                }
                Spacer()
                Text(entry.currentBook)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(.lexstaGreenDark)
                    .lineLimit(2)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.lexstaGreen.opacity(0.2))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.lexstaGreen)
                            .frame(width: geo.size.width * entry.progressPercent, height: 4)
                    }
                }
                .frame(height: 4)
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.lexstaGreen)
                    Text("\(entry.todayMinutes) min aujourd'hui")
                        .font(.system(size: 10))
                        .foregroundColor(.lexstaGreen)
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: LexstaEntry
    
    var body: some View {
        ZStack {
            Color.lexstaCream
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EN COURS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.lexstaGreen.opacity(0.7))
                        .tracking(1.5)
                    Text(entry.currentBook)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundColor(.lexstaGreenDark)
                        .lineLimit(2)
                    Text(entry.currentAuthor)
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.lexstaGreen)
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(entry.progressPercent * 100))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.lexstaGreen)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.lexstaGreen.opacity(0.2))
                                    .frame(height: 5)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.lexstaGreen)
                                    .frame(width: geo.size.width * entry.progressPercent, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                }
                Divider().background(Color.lexstaGreen.opacity(0.3))
                VStack(spacing: 12) {
                    Spacer()
                    VStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.lexstaGreen)
                        Text("\(entry.todayMinutes)")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundColor(.lexstaGreenDark)
                        Text("min today")
                            .font(.system(size: 9))
                            .foregroundColor(.lexstaGreen.opacity(0.8))
                    }
                    VStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                        Text("\(entry.streak)")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundColor(.lexstaGreenDark)
                        Text("day streak")
                            .font(.system(size: 9))
                            .foregroundColor(.lexstaGreen.opacity(0.8))
                    }
                    Spacer()
                }
                .frame(width: 80)
            }
            .padding(14)
        }
    }
}

// MARK: - Entry View & Widget

struct LexDayWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: LexstaEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}


struct LexDayWidget: Widget {
    let kind: String = "LexDayWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LexDayWidgetEntryView(entry: entry)
                .containerBackground(Color.lexstaCream, for: .widget)
        }
        .configurationDisplayName("LexDay")
        .description("Votre lecture en cours et vos stats du jour.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
