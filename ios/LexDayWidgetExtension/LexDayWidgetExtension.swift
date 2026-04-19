import WidgetKit
import SwiftUI

// MARK: - Data Model

struct LexDayEntry: TimelineEntry {
    let date: Date
    let currentBook: String
    let currentAuthor: String
    let coverUrl: String
    let coverImage: UIImage?
    let todayMinutes: Int
    let streak: Int
    let progressPercent: Double
}

// MARK: - Provider

struct Provider: TimelineProvider {
    let appGroup = "group.fr.lexday.app"

    func placeholder(in context: Context) -> LexDayEntry {
        LexDayEntry(date: Date(), currentBook: "Le Petit Prince",
                    currentAuthor: "Saint-Exupéry", coverUrl: "",
                    coverImage: nil,
                    todayMinutes: 32, streak: 7, progressPercent: 0.65)
    }

    func getSnapshot(in context: Context, completion: @escaping (LexDayEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LexDayEntry>) -> Void) {
        let entry = buildEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func buildEntry() -> LexDayEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        let base64 = defaults?.string(forKey: "coverBase64") ?? ""
        var image: UIImage? = nil
        if !base64.isEmpty, let data = Data(base64Encoded: base64) {
            image = UIImage(data: data)
        }
        return LexDayEntry(
            date: Date(),
            currentBook: defaults?.string(forKey: "currentBook") ?? "Aucun livre",
            currentAuthor: defaults?.string(forKey: "currentAuthor") ?? "",
            coverUrl: defaults?.string(forKey: "coverUrl") ?? "",
            coverImage: image,
            todayMinutes: defaults?.integer(forKey: "todayMinutes") ?? 0,
            streak: defaults?.integer(forKey: "streak") ?? 0,
            progressPercent: defaults?.double(forKey: "progressPercent") ?? 0.0
        )
    }
}

// MARK: - Colors

extension Color {
    static let lexstaGreen = Color(red: 107/255, green: 152/255, blue: 141/255)
    static let lexstaCream = Color(red: 250/255, green: 245/255, blue: 235/255)
    static let lexstaGreenDark = Color(red: 80/255, green: 115/255, blue: 106/255)
}

// MARK: - Book Cover View

struct BookCoverView: View {
    let image: UIImage?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }

    private var placeholder: some View {
        ZStack {
            Color.lexstaGreen.opacity(0.15)
            Image(systemName: "book.closed.fill")
                .font(.system(size: 24))
                .foregroundColor(.lexstaGreen.opacity(0.6))
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: LexDayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                BookCoverView(image: entry.coverImage, width: 36, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.currentBook)
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(.lexstaGreenDark)
                        .lineLimit(2)
                    Text(entry.currentAuthor)
                        .font(.system(size: 9, design: .serif))
                        .foregroundColor(.lexstaGreen)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.lexstaGreen.opacity(0.2))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.lexstaGreen)
                        .frame(width: geo.size.width * entry.progressPercent, height: 3)
                }
            }
            .frame(height: 3)
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8))
                    Text("\(entry.todayMinutes) min")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.lexstaGreen)
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                    Text("\(entry.streak)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.lexstaGreenDark)
                }
            }
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: LexDayEntry

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(image: entry.coverImage, width: 70, height: 105)

            VStack(alignment: .leading, spacing: 3) {
                Text("EN COURS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.lexstaGreen.opacity(0.7))
                    .tracking(1.2)
                Text(entry.currentBook)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(.lexstaGreenDark)
                    .lineLimit(2)
                Text(entry.currentAuthor)
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(.lexstaGreen)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(Int(entry.progressPercent * 100))%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.lexstaGreen)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.lexstaGreen.opacity(0.2))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.lexstaGreen)
                            .frame(width: geo.size.width * entry.progressPercent, height: 4)
                    }
                }
                .frame(height: 4)
            }

            VStack(spacing: 8) {
                VStack(spacing: 1) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.lexstaGreen)
                    Text("\(entry.todayMinutes)")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(.lexstaGreenDark)
                    Text("min today")
                        .font(.system(size: 8))
                        .foregroundColor(.lexstaGreen.opacity(0.8))
                }
                VStack(spacing: 1) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                    Text("\(entry.streak)")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(.lexstaGreenDark)
                    Text("day streak")
                        .font(.system(size: 8))
                        .foregroundColor(.lexstaGreen.opacity(0.8))
                }
            }
            .frame(width: 60)
        }
    }
}

// MARK: - Entry View & Widget

struct LexDayWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: LexDayEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
                .widgetURL(URL(string: "lexday://start-session"))
        default:
            MediumWidgetView(entry: entry)
                .widgetURL(URL(string: "lexday://start-session"))
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
