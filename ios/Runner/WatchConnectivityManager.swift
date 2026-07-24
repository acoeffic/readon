// WatchConnectivityManager.swift
// Côté iPhone : pont WatchConnectivity entre l'app Watch et l'app Flutter.
//
// Deux sens de communication :
//
//  Watch → iPhone (commandes de l'utilisateur)
//   La Watch envoie {command, sessionId} via sendMessage / transferUserInfo.
//   On écrit la commande dans l'App Group (clés `watchPendingCommand*`) ;
//   le service Dart `WatchControlService` la consomme par polling et pilote
//   réellement la session de lecture (start / pause / resume / stop).
//
//  iPhone → Watch (état courant)
//   `pushState(...)` lit le livre en cours + les stats déjà écrits dans l'App
//   Group par `WidgetService` (côté Flutter), y ajoute l'état de session fourni
//   par Dart, redimensionne la couverture, et pousse le tout à la Watch via
//   `updateApplicationContext` (+ `sendMessage` si la Watch est joignable).

import Foundation
import WatchConnectivity
import UIKit

final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    private let appGroupId = "group.fr.lexday.app"

    // Clés de commande dédiées à la Watch (distinctes de `pendingReadingCommand`
    // utilisé par les App Intents de la Live Activity, pour éviter toute collision).
    private let cmdKey = "watchPendingCommand"
    private let cmdSessionKey = "watchPendingCommandSession"
    private let cmdTimestampKey = "watchPendingCommandTimestamp"

    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

    private override init() { super.init() }

    /// À appeler tôt (depuis AppDelegate) pour commencer à écouter la Watch.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Indique si un Apple Watch appairé peut recevoir l'app compagnon.
    var isSupported: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isPaired
    }

    // MARK: - iPhone → Watch : pousser l'état courant

    /// Construit le contexte (livre + stats depuis l'App Group, état de session
    /// fourni par Dart) et le transmet à la Watch.
    func pushState(isReading: Bool, isPaused: Bool, sessionId: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let d = defaults
        var context: [String: Any] = [
            "currentBook": d?.string(forKey: "currentBook") ?? "",
            "currentAuthor": d?.string(forKey: "currentAuthor") ?? "",
            "todayMinutes": d?.integer(forKey: "todayMinutes") ?? 0,
            "streak": d?.integer(forKey: "streak") ?? 0,
            "progressPercent": d?.double(forKey: "progressPercent") ?? 0.0,
            "isReading": isReading,
            "isPaused": isPaused,
            "sessionId": sessionId,
            "ts": Date().timeIntervalSince1970,
        ]

        // Couverture : on redimensionne fortement pour rester bien sous la
        // limite de taille d'`updateApplicationContext`.
        if let base64 = d?.string(forKey: "coverBase64"), !base64.isEmpty,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            let small = image.resizedForLiveActivity(maxDimension: 160)
            if let jpeg = small.jpegData(compressionQuality: 0.8) {
                context["coverBase64"] = jpeg.base64EncodedString()
            }
        }

        // `updateApplicationContext` garantit la livraison du dernier état même
        // si la Watch est hors de portée pour le moment.
        try? session.updateApplicationContext(context)

        // Si la Watch est joignable, on pousse aussi en temps réel.
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: nil)
        }
    }

    // MARK: - Watch → iPhone : recevoir les commandes

    private func handleWatchPayload(_ payload: [String: Any]) {
        guard let command = payload["command"] as? String else { return }
        let sessionId = payload["sessionId"] as? String ?? ""
        guard let d = defaults else { return }
        d.set(command, forKey: cmdKey)
        d.set(sessionId, forKey: cmdSessionKey)
        d.set(Date().timeIntervalSince1970, forKey: cmdTimestampKey)
    }

    /// Lit puis efface la commande en attente émise par la Watch.
    /// Appelé par le MethodChannel côté Flutter.
    func consumePendingCommand() -> [String: Any]? {
        guard let d = defaults,
              let command = d.string(forKey: cmdKey) else { return nil }
        let sessionId = d.string(forKey: cmdSessionKey) ?? ""
        let timestamp = d.double(forKey: cmdTimestampKey)
        d.removeObject(forKey: cmdKey)
        d.removeObject(forKey: cmdSessionKey)
        d.removeObject(forKey: cmdTimestampKey)
        return ["command": command, "sessionId": sessionId, "timestamp": timestamp]
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Réactive pour rester connecté après un changement de Watch appairée.
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleWatchPayload(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        handleWatchPayload(message)
        replyHandler(["ok": true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleWatchPayload(userInfo)
    }
}
