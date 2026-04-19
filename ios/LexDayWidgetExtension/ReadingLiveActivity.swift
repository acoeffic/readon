// ReadingLiveActivity.swift
// Widget Live Activity (écran verrouillage + Dynamic Island) pendant une session de lecture.
// Requiert iOS 16.1+.

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct ReadingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            // --- Lock screen / Banner ---
            LockScreenReadingView(context: context)
                .activityBackgroundTint(Color.lexstaCream)
                .activitySystemActionForegroundColor(Color.lexstaGreenDark)
        } dynamicIsland: { context in
            DynamicIsland {
                // --- Dynamic Island expanded ---
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityCover(base64: context.attributes.coverBase64, size: 48)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Lecture")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.lexstaGreen.opacity(0.8))
                            .tracking(1.0)
                        LiveTimerText(state: context.state, font: .system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.lexstaGreenDark)
                            .monospacedDigit()
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.bookTitle)
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundColor(.lexstaGreenDark)
                            .lineLimit(1)
                        if !context.attributes.bookAuthor.isEmpty {
                            Text(context.attributes.bookAuthor)
                                .font(.system(size: 10, design: .serif))
                                .foregroundColor(.lexstaGreen)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PauseResumeButton(context: context)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "book.fill")
                    .foregroundColor(.lexstaGreen)
            } compactTrailing: {
                LiveTimerText(state: context.state, font: .system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.lexstaGreenDark)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "book.fill")
                    .foregroundColor(.lexstaGreen)
            }
            .widgetURL(URL(string: "lexday://reading-session/\(context.attributes.sessionId)"))
            .keylineTint(Color.lexstaGreen)
        }
    }
}

// MARK: - Lock screen layout

@available(iOS 16.1, *)
struct LockScreenReadingView: View {
    let context: ActivityViewContext<ReadingActivityAttributes>

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LiveActivityCover(base64: context.attributes.coverBase64, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: context.state.isPaused ? "pause.circle.fill" : "book.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.lexstaGreen)
                    Text(context.state.isPaused ? "LECTURE EN PAUSE" : "LECTURE EN COURS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.lexstaGreen.opacity(0.85))
                        .tracking(1.1)
                }

                Text(context.attributes.bookTitle)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(.lexstaGreenDark)
                    .lineLimit(1)

                if !context.attributes.bookAuthor.isEmpty {
                    Text(context.attributes.bookAuthor)
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.lexstaGreen)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(alignment: .center, spacing: 10) {
                    LiveTimerText(state: context.state, font: .system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.lexstaGreenDark)
                        .monospacedDigit()

                    Spacer(minLength: 0)

                    PauseResumeButton(context: context)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Composants réutilisables

@available(iOS 16.1, *)
struct LiveActivityCover: View {
    let base64: String
    let size: CGFloat

    private var uiImage: UIImage? {
        guard !base64.isEmpty, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.lexstaGreen.opacity(0.15)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.lexstaGreen.opacity(0.6))
                }
            }
        }
        .frame(width: size, height: size * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
    }
}

/// Timer live géré par SwiftUI (Text(timerInterval:) met à jour automatiquement
/// la Live Activity sans besoin de réveiller l'app Flutter).
@available(iOS 16.1, *)
struct LiveTimerText: View {
    let state: ReadingActivityAttributes.ContentState
    let font: Font

    var body: some View {
        if state.isPaused {
            Text(formatSeconds(state.accumulatedSeconds))
                .font(font)
        } else {
            // Fin fictive à +24h : SwiftUI va décompter depuis timerReferenceDate.
            let far = state.timerReferenceDate.addingTimeInterval(60 * 60 * 24)
            Text(timerInterval: state.timerReferenceDate...far, countsDown: false)
                .font(font)
        }
    }

    private func formatSeconds(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        if m >= 60 {
            let h = m / 60
            let rm = m % 60
            return String(format: "%d:%02d:%02d", h, rm, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }
}

@available(iOS 16.1, *)
struct PauseResumeButton: View {
    let context: ActivityViewContext<ReadingActivityAttributes>

    var body: some View {
        if #available(iOS 17.0, *) {
            if context.state.isPaused {
                Button(intent: ResumeReadingIntent(sessionId: context.attributes.sessionId)) {
                    Label("Reprendre", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .semibold))
                }
                .tint(Color.lexstaGreen)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button(intent: PauseReadingIntent(sessionId: context.attributes.sessionId)) {
                    Label("Pause", systemImage: "pause.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .semibold))
                }
                .tint(Color.lexstaGreen.opacity(0.85))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        } else {
            // iOS 16.1–16.4 : pas de boutons interactifs. On affiche juste un indicateur.
            HStack(spacing: 4) {
                Image(systemName: context.state.isPaused ? "pause.fill" : "book.fill")
                Text(context.state.isPaused ? "En pause" : "En cours")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.lexstaGreen)
        }
    }
}
