// WatchSessionManager.swift
// Côté Apple Watch : gère la connexion WatchConnectivity avec l'iPhone.
//
// - Reçoit l'état courant (livre en cours + stats + état de session) poussé par
//   l'iPhone via `updateApplicationContext` / `sendMessage`, et le DEMANDE
//   activement (`requestSync`) au lancement, à la reconnexion et au retour au
//   premier plan.
// - Envoie les commandes utilisateur (start / pause / resume / stop) à l'iPhone
//   via `sendMessage` (repli `transferUserInfo` si l'iPhone est injoignable ou
//   si le message échoue). Chaque commande porte un `id` unique : l'iPhone
//   dédoublonne si elle arrive par les deux canaux.

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

    /// Horodatage (côté iPhone) du dernier état appliqué : un état plus ancien
    /// (livré en retard, ou doublon sendMessage / applicationContext) est ignoré.
    private var lastAppliedTs: Double = 0
    /// Commandes émises avant l'activation de la session, rejouées ensuite.
    private var pendingBeforeActivation: [[String: Any]] = []
    private var syncInFlight = false

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
            "id": UUID().uuidString,
            "sessionId": state.sessionId,
            "timestamp": Date().timeIntervalSince1970,
        ]

        // Mise à jour optimiste de l'UI pour une sensation de réactivité.
        applyOptimistic(command)
        deliver(payload)
    }

    private func deliver(_ payload: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated else {
            // Pas encore activée : on garde la commande et on la rejoue ensuite
            // (transferUserInfo avant activation serait perdu).
            DispatchQueue.main.async { self.pendingBeforeActivation.append(payload) }
            return
        }

        if session.isReachable {
            DispatchQueue.main.async { self.isSending = true }
            session.sendMessage(payload, replyHandler: { [weak self] _ in
                DispatchQueue.main.async { self?.isSending = false }
            }, errorHandler: { [weak self] _ in
                // Repli fiable si le message direct échoue (même id : dédoublonné
                // côté iPhone si le message était en fait arrivé).
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
        DispatchQueue.main.async {
            switch command {
            case .start:
                self.state.isReading = true
                self.state.isPaused = false
            case .pause:
                self.state.isPaused = true
            case .resume:
                self.state.isPaused = false
            case .stop:
                self.state.isReading = false
                self.state.isPaused = false
            }
        }
    }

    // MARK: - Demande d'état à l'iPhone

    /// Demande à l'iPhone son état courant (lancement, reconnexion, retour au
    /// premier plan). Sans effet si l'iPhone n'est pas joignable : on retombe
    /// alors sur le dernier applicationContext reçu.
    func requestSync() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        // Dernier contexte garanti livré par le système, même sans iPhone joignable.
        if !session.receivedApplicationContext.isEmpty {
            apply(context: session.receivedApplicationContext)
        }

        guard session.isReachable, !syncInFlight else { return }
        syncInFlight = true
        session.sendMessage(["command": "sync"], replyHandler: { [weak self] reply in
            DispatchQueue.main.async { self?.syncInFlight = false }
            self?.apply(context: reply)
        }, errorHandler: { [weak self] _ in
            DispatchQueue.main.async { self?.syncInFlight = false }
        })
    }

    // MARK: - Réception de l'état depuis l'iPhone

    private func apply(context: [String: Any]) {
        // Ignore les messages qui ne sont pas un état (ex. accusé {"ok": true}).
        guard context["currentBook"] != nil else { return }

        let ts = context["ts"] as? Double ?? 0

        DispatchQueue.main.async {
            // État plus ancien que celui déjà affiché : on ne régresse pas.
            if ts > 0 && ts < self.lastAppliedTs { return }
            if ts > 0 { self.lastAppliedTs = ts }

            var newState = WatchReadingState()
            newState.bookTitle = context["currentBook"] as? String ?? ""
            newState.bookAuthor = context["currentAuthor"] as? String ?? ""
            newState.todayMinutes = (context["todayMinutes"] as? NSNumber)?.intValue ?? 0
            newState.streak = (context["streak"] as? NSNumber)?.intValue ?? 0
            newState.progressPercent = (context["progressPercent"] as? NSNumber)?.doubleValue ?? 0.0
            newState.isReading = context["isReading"] as? Bool ?? false
            newState.isPaused = context["isPaused"] as? Bool ?? false
            newState.sessionId = context["sessionId"] as? String ?? ""

            if let base64 = context["coverBase64"] as? String, !base64.isEmpty,
               let data = Data(base64Encoded: base64) {
                newState.coverData = data
            } else if newState.bookTitle == self.state.bookTitle {
                // Même livre, pas de couverture dans ce message : on garde l'ancienne.
                newState.coverData = self.state.coverData
            }

            if newState != self.state { self.state = newState }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            // Rejoue les commandes émises avant l'activation.
            let queued = self.pendingBeforeActivation
            self.pendingBeforeActivation.removeAll()
            queued.forEach { self.deliver($0) }
        }
        guard activationState == .activated else { return }
        // Applique le dernier contexte connu puis demande un état frais.
        requestSync()
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

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        apply(context: message)
        replyHandler(["ok": true])
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isReachable = session.isReachable }
        // L'iPhone redevient joignable : on récupère l'état à jour.
        if session.isReachable { requestSync() }
    }
}
