// WatchSessionManager.swift
// Côté Apple Watch : gère la connexion WatchConnectivity avec l'iPhone.
//
// - Reçoit l'état courant (livre en cours + stats + état de session) poussé par
//   l'iPhone via `updateApplicationContext`.
// - Envoie les commandes utilisateur (start / pause / resume / stop) à l'iPhone
//   via `sendMessage` (avec repli `transferUserInfo` si l'iPhone est injoignable).

import Foundation
import WatchConnectivity

/// État de lecture tel que connu par la Watch (miroir de l'iPhone).
struct WatchReadingState: Equatable {
    var bookTitle: String = ""
    var bookAuthor: String = ""
    var coverData: Data? = nil
    var todayMinutes: Int = 0
    var streak: Int = 0
    var progressPercent: Double = 0.0
    var isReading: Bool = false
    var isPaused: Bool = false
    var sessionId: String = ""

    var hasBook: Bool { !bookTitle.isEmpty && bookTitle != "Aucun livre" }
}

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    /// État publié à l'UI SwiftUI.
    @Published private(set) var state = WatchReadingState()
    /// Vrai tant qu'une commande est en cours d'envoi (pour désactiver les boutons).
    @Published private(set) var isSending = false
    /// Vrai si l'iPhone est joignable en temps réel.
    @Published private(set) var isReachable = false

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Envoi de commandes vers l'iPhone

    /// Commandes possibles, mappées 1:1 avec le handler Dart côté app.
    enum Command: String {
        case start, pause, resume, stop
    }

    func send(_ command: Command) {
        let payload: [String: Any] = [
            "command": command.rawValue,
            "sessionId": state.sessionId,
            "timestamp": Date().timeIntervalSince1970,
        ]

        // Mise à jour optimiste de l'UI pour une sensation de réactivité.
        applyOptimistic(command)

        let session = WCSession.default
        guard session.activationState == .activated else {
            // Pas encore activée : on tente quand même via transferUserInfo.
            session.transferUserInfo(payload)
            return
        }

        if session.isReachable {
            isSending = true
            session.sendMessage(payload, replyHandler: { [weak self] _ in
                DispatchQueue.main.async { self?.isSending = false }
            }, errorHandler: { [weak self] _ in
                // Repli fiable si le message direct échoue.
                session.transferUserInfo(payload)
                DispatchQueue.main.async { self?.isSending = false }
            })
        } else {
            // iPhone non joignable (app fermée) : file d'attente garantie.
            session.transferUserInfo(payload)
        }
    }

    /// Reflète immédiatement l'action sur l'UI Watch sans attendre l'aller-retour.
    private func applyOptimistic(_ command: Command) {
        switch command {
        case .start:
            state.isReading = true
            state.isPaused = false
        case .pause:
            state.isPaused = true
        case .resume:
            state.isPaused = false
        case .stop:
            state.isReading = false
            state.isPaused = false
        }
    }

    // MARK: - Réception de l'état depuis l'iPhone

    private func apply(context: [String: Any]) {
        var newState = WatchReadingState()
        newState.bookTitle = context["currentBook"] as? String ?? ""
        newState.bookAuthor = context["currentAuthor"] as? String ?? ""
        newState.todayMinutes = context["todayMinutes"] as? Int ?? 0
        newState.streak = context["streak"] as? Int ?? 0
        newState.progressPercent = context["progressPercent"] as? Double ?? 0.0
        newState.isReading = context["isReading"] as? Bool ?? false
        newState.isPaused = context["isPaused"] as? Bool ?? false
        newState.sessionId = context["sessionId"] as? String ?? ""

        if let base64 = context["coverBase64"] as? String, !base64.isEmpty {
            newState.coverData = Data(base64Encoded: base64)
        }

        DispatchQueue.main.async { self.state = newState }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { self.isReachable = session.isReachable }
        // Applique le dernier contexte connu au démarrage.
        if !session.receivedApplicationContext.isEmpty {
            apply(context: session.receivedApplicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(context: applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        apply(context: userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(context: message)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isReachable = session.isReachable }
    }
}
