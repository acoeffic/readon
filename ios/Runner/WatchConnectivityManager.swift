// WatchConnectivityManager.swift
// Côté iPhone : pont WatchConnectivity entre l'app Watch et l'app Flutter.
//
// Deux sens de communication :
//
//  Watch → iPhone (commandes de l'utilisateur)
//   La Watch envoie {command, id, sessionId, timestamp} via sendMessage /
//   transferUserInfo. Les commandes sont mises dans une FILE (App Group, clé
//   `watchPendingCommands`), dédoublonnées par `id` (un même ordre peut arriver
//   par deux canaux) ; le service Dart `WatchControlService` les consomme une
//   par une et pilote la session de lecture (start / pause / resume / stop).
//   La commande spéciale `sync` n'entre pas dans la file : la Watch demande
//   l'état courant et on lui répond tout de suite.
//
//  iPhone → Watch (état courant)
//   `pushState(...)` construit le contexte (livre + stats lus dans l'App Group,
//   état de session fourni par Dart), le mémorise, et le pousse via
//   `updateApplicationContext` (+ `sendMessage` si la Watch est joignable).
//   Le dernier état est automatiquement renvoyé à l'activation de la session,
//   quand la Watch devient joignable / change d'état, et sur demande `sync`.

import Foundation
import WatchConnectivity
import UIKit

final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    private let appGroupId = "group.fr.lexday.app"

    // File de commandes Watch (distincte de `pendingReadingCommand` utilisé par
    // les App Intents de la Live Activity, pour éviter toute collision).
    private let queueKey = "watchPendingCommands"
    private let seenIdsKey = "watchSeenCommandIds"
    private let maxSeenIds = 50
    /// Une commande de démarrage/pause/reprise plus vieille que ça est périmée
    /// (ex. transferUserInfo livré très tard) : l'appliquer surprendrait.
    private let staleAfter: TimeInterval = 90
    /// Le stop reste valable plus longtemps (ne pas perdre le temps lu).
    private let staleStopAfter: TimeInterval = 600

    private let lock = NSLock()
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

    /// Dernier état de session fourni par Dart (rejoué à la reconnexion).
    private var lastSession: (isReading: Bool, isPaused: Bool, sessionId: String)?

    /// Cache de la couverture redimensionnée (évite de ré-encoder à chaque push).
    private var coverCacheKey: Int = 0
    private var coverCacheValue: String?

    /// Notifie Flutter (via le MethodChannel, câblé dans AppDelegate) qu'une
    /// commande vient d'arriver. Toujours appelé sur le main thread.
    var onCommandReceived: (() -> Void)?

    private override init() { super.init() }

    // MARK: - Temps d'exécution en arrière-plan

    /// Quand une commande arrive alors que l'app iPhone est en arrière-plan,
    /// iOS peut la suspendre avant que Dart ait fini (réseau Supabase). On
    /// demande du temps ; il est rendu quand la file est vide ou après 25 s.
    private var bgTask: UIBackgroundTaskIdentifier = .invalid

    private func beginBackgroundWork() {
        DispatchQueue.main.async {
            guard self.bgTask == .invalid else { return }
            let id = UIApplication.shared.beginBackgroundTask(withName: "watch-command") { [weak self] in
                self?.endBackgroundWork()
            }
            self.bgTask = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
                if self?.bgTask == id { self?.endBackgroundWork() }
            }
        }
    }

    private func endBackgroundWork() {
        DispatchQueue.main.async {
            guard self.bgTask != .invalid else { return }
            UIApplication.shared.endBackgroundTask(self.bgTask)
            self.bgTask = .invalid
        }
    }

    /// À appeler tôt (depuis AppDelegate) pour commencer à écouter la Watch.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Indique si une Apple Watch appairée peut recevoir l'app compagnon.
    var isSupported: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isPaired
    }

    // MARK: - iPhone → Watch : pousser l'état courant

    /// Mémorise l'état de session fourni par Dart puis le transmet à la Watch.
    func pushState(isReading: Bool, isPaused: Bool, sessionId: String) {
        lock.lock()
        lastSession = (isReading, isPaused, sessionId)
        lock.unlock()
        pushLastState()
    }

    /// Pousse le dernier état connu. Appelé aussi à l'activation, au changement
    /// de joignabilité et au changement d'état de la Watch.
    private func pushLastState() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        // Pas encore activée : activationDidCompleteWith rappellera cette méthode.
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        let context = buildContext()

        // `updateApplicationContext` garantit la livraison du dernier état même
        // si la Watch est hors de portée pour le moment.
        do {
            try session.updateApplicationContext(context)
        } catch {
            NSLog("WatchConnectivity: updateApplicationContext a échoué: \(error)")
        }

        // Si la Watch est joignable, on pousse aussi en temps réel.
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: { error in
                NSLog("WatchConnectivity: sendMessage état a échoué: \(error)")
            })
        }
    }

    /// Construit le contexte (livre + stats depuis l'App Group, état de session
    /// mémorisé). `ts` permet à la Watch d'ignorer un état plus ancien que celui
    /// déjà appliqué.
    private func buildContext() -> [String: Any] {
        lock.lock()
        let s = lastSession ?? (false, false, "")
        lock.unlock()

        let d = defaults
        var context: [String: Any] = [
            "currentBook": d?.string(forKey: "currentBook") ?? "",
            "currentAuthor": d?.string(forKey: "currentAuthor") ?? "",
            "todayMinutes": d?.integer(forKey: "todayMinutes") ?? 0,
            "streak": d?.integer(forKey: "streak") ?? 0,
            "progressPercent": d?.double(forKey: "progressPercent") ?? 0.0,
            "isReading": s.isReading,
            "isPaused": s.isPaused,
            "sessionId": s.sessionId,
            "ts": Date().timeIntervalSince1970,
        ]

        if let cover = resizedCoverBase64(from: d?.string(forKey: "coverBase64")) {
            context["coverBase64"] = cover
        }
        return context
    }

    /// Redimensionne la couverture (reste sous la limite de taille du contexte)
    /// et met le résultat en cache tant que la source ne change pas.
    private func resizedCoverBase64(from source: String?) -> String? {
        guard let base64 = source, !base64.isEmpty else { return nil }
        let key = base64.count &* 31 &+ base64.prefix(64).hashValue &+ base64.suffix(64).hashValue
        lock.lock()
        if key == coverCacheKey, let cached = coverCacheValue {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else { return nil }
        let small = image.resizedForLiveActivity(maxDimension: 160)
        guard let jpeg = small.jpegData(compressionQuality: 0.8) else { return nil }
        let encoded = jpeg.base64EncodedString()

        lock.lock()
        coverCacheKey = key
        coverCacheValue = encoded
        lock.unlock()
        return encoded
    }

    // MARK: - Watch → iPhone : recevoir les commandes

    /// Traite un message de la Watch. Retourne la réponse à renvoyer (replyHandler).
    @discardableResult
    private func handleWatchPayload(_ payload: [String: Any]) -> [String: Any] {
        guard let command = payload["command"] as? String else { return ["ok": false] }

        // La Watch demande l'état courant : réponse immédiate, pas de file.
        if command == "sync" {
            pushLastState()
            return buildContext()
        }

        let id = payload["id"] as? String ?? UUID().uuidString
        let sessionId = payload["sessionId"] as? String ?? ""
        let timestamp = payload["timestamp"] as? Double ?? Date().timeIntervalSince1970

        guard let d = defaults else { return ["ok": false] }

        lock.lock()
        // Dédoublonnage : même ordre reçu par sendMessage ET transferUserInfo.
        var seen = d.stringArray(forKey: seenIdsKey) ?? []
        if seen.contains(id) {
            lock.unlock()
            return ["ok": true, "duplicate": true]
        }
        seen.append(id)
        if seen.count > maxSeenIds { seen.removeFirst(seen.count - maxSeenIds) }
        d.set(seen, forKey: seenIdsKey)

        var queue = d.array(forKey: queueKey) as? [[String: Any]] ?? []
        queue.append([
            "command": command,
            "sessionId": sessionId,
            "timestamp": timestamp,
            "id": id,
        ])
        d.set(queue, forKey: queueKey)
        lock.unlock()

        beginBackgroundWork()

        // Les callbacks WCSession arrivent sur un thread background ; le
        // MethodChannel Flutter exige le main thread.
        DispatchQueue.main.async { [weak self] in
            self?.onCommandReceived?()
        }
        return ["ok": true]
    }

    /// Dépile la plus ancienne commande valide en attente (les périmées sont
    /// ignorées). Appelé par le MethodChannel côté Flutter, en boucle jusqu'à nil.
    func consumePendingCommand() -> [String: Any]? {
        guard let d = defaults else { return nil }
        lock.lock()
        defer { lock.unlock() }

        var queue = d.array(forKey: queueKey) as? [[String: Any]] ?? []
        let now = Date().timeIntervalSince1970
        while !queue.isEmpty {
            let item = queue.removeFirst()
            let command = item["command"] as? String ?? ""
            let timestamp = item["timestamp"] as? Double ?? now
            let limit = command == "stop" ? staleStopAfter : staleAfter
            if now - timestamp > limit { continue }
            d.set(queue, forKey: queueKey)
            return [
                "command": command,
                "sessionId": item["sessionId"] as? String ?? "",
                "timestamp": timestamp,
            ]
        }
        d.set(queue, forKey: queueKey)
        // File vide : Dart a tout traité, on rend le temps d'arrière-plan.
        endBackgroundWork()
        return nil
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            NSLog("WatchConnectivity: activation a échoué: \(error)")
            return
        }
        // Renvoie l'état connu dès que la session est prête (un push fait avant
        // l'activation, ex. au splash, avait été ignoré).
        if activationState == .activated { pushLastState() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Réactive pour rester connecté après un changement de Watch appairée.
        WCSession.default.activate()
    }

    /// Watch appairée / app Watch installée ou retirée.
    func sessionWatchStateDidChange(_ session: WCSession) {
        pushLastState()
    }

    /// La Watch redevient joignable : on lui renvoie l'état frais.
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable { pushLastState() }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleWatchPayload(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler(handleWatchPayload(message))
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleWatchPayload(userInfo)
    }
}
