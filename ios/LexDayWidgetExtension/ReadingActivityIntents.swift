// ReadingActivityIntents.swift
// Boutons interactifs (Pause / Reprendre) dans la Live Activity.
// Requiert iOS 17+.
//
// Stratégie : les intents écrivent la commande dans l'App Group via UserDefaults.
// L'app Flutter observe ce fichier (à son prochain réveil ou via polling léger)
// pour mettre à jour sa propre machine à états côté Dart.
// En parallèle, l'intent met IMMÉDIATEMENT à jour la Live Activity pour une UX fluide.

import AppIntents
import ActivityKit
import Foundation

@available(iOS 17.0, *)
public struct PauseReadingIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Mettre en pause la lecture"
    public static var description = IntentDescription("Met en pause le chronomètre de lecture.")

    @Parameter(title: "Session ID")
    public var sessionId: String

    public init() {}
    public init(sessionId: String) {
        self.sessionId = sessionId
    }

    public func perform() async throws -> some IntentResult {
        ReadingActivityBridge.signal(command: "pause", sessionId: sessionId)
        await ReadingActivityBridge.applyPause(sessionId: sessionId)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct ResumeReadingIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Reprendre la lecture"
    public static var description = IntentDescription("Reprend le chronomètre de lecture.")

    @Parameter(title: "Session ID")
    public var sessionId: String

    public init() {}
    public init(sessionId: String) {
        self.sessionId = sessionId
    }

    public func perform() async throws -> some IntentResult {
        ReadingActivityBridge.signal(command: "resume", sessionId: sessionId)
        await ReadingActivityBridge.applyResume(sessionId: sessionId)
        return .result()
    }
}

// MARK: - Bridge partagé

@available(iOS 16.1, *)
enum ReadingActivityBridge {
    static let appGroupId = "group.fr.lexday.app"
    static let pendingCommandKey = "pendingReadingCommand"
    static let pendingCommandSessionKey = "pendingReadingCommandSession"
    static let pendingCommandTimestampKey = "pendingReadingCommandTimestamp"

    /// Écrit la commande pause/resume dans l'App Group pour que Flutter la lise à sa prochaine foregrounding.
    static func signal(command: String, sessionId: String) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(command, forKey: pendingCommandKey)
        defaults.set(sessionId, forKey: pendingCommandSessionKey)
        defaults.set(Date().timeIntervalSince1970, forKey: pendingCommandTimestampKey)
    }

    /// Applique la pause directement sur la Live Activity iOS (mise à jour UI immédiate).
    @available(iOS 16.1, *)
    static func applyPause(sessionId: String) async {
        for activity in Activity<ReadingActivityAttributes>.activities
        where activity.attributes.sessionId == sessionId {
            let current = activity.content.state
            guard !current.isPaused else { return }
            let elapsed = Int(Date().timeIntervalSince(current.timerReferenceDate))
            let newState = ReadingActivityAttributes.ContentState(
                timerReferenceDate: current.timerReferenceDate,
                accumulatedSeconds: current.accumulatedSeconds + max(0, elapsed),
                isPaused: true
            )
            await activity.update(ActivityContent(state: newState, staleDate: nil))
        }
    }

    /// Applique la reprise directement sur la Live Activity iOS.
    @available(iOS 16.1, *)
    static func applyResume(sessionId: String) async {
        for activity in Activity<ReadingActivityAttributes>.activities
        where activity.attributes.sessionId == sessionId {
            let current = activity.content.state
            guard current.isPaused else { return }
            // Nouvelle référence : now - accumulatedSeconds pour que le compteur reprenne exactement.
            let newRef = Date().addingTimeInterval(-Double(current.accumulatedSeconds))
            let newState = ReadingActivityAttributes.ContentState(
                timerReferenceDate: newRef,
                accumulatedSeconds: current.accumulatedSeconds,
                isPaused: false
            )
            await activity.update(ActivityContent(state: newState, staleDate: nil))
        }
    }
}
