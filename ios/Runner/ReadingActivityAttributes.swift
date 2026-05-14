// ReadingActivityAttributes.swift
// Modèle partagé entre l'app principale (Runner) et l'extension widget (LexDayWidgetExtension).
//
// IMPORTANT Xcode : ce fichier DOIT être ajouté aux deux cibles (Runner + LexDayWidgetExtension).
// Dans Xcode : File Inspector → Target Membership → cocher Runner ET LexDayWidgetExtension.

import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct ReadingActivityAttributes: ActivityAttributes {
    public typealias ReadingSessionStatus = ContentState

    public struct ContentState: Codable, Hashable {
        /// Date de démarrage (ou de dernière reprise) utilisée par le timer live.
        /// Pour Text(timerInterval:) on utilise `timerReferenceDate` = now - accumulatedSeconds
        /// afin que SwiftUI affiche un compteur qui reprend exactement où on en était.
        public var timerReferenceDate: Date

        /// Secondes déjà accumulées de lecture effective (hors pauses).
        /// Utile lorsque `isPaused == true` pour afficher une valeur gelée.
        public var accumulatedSeconds: Int

        /// État pause / en cours.
        public var isPaused: Bool

        public init(timerReferenceDate: Date, accumulatedSeconds: Int, isPaused: Bool) {
            self.timerReferenceDate = timerReferenceDate
            self.accumulatedSeconds = accumulatedSeconds
            self.isPaused = isPaused
        }
    }

    /// Attributs fixes pendant toute la durée de la Live Activity.
    ///
    /// IMPORTANT : ActivityKit impose une limite de ~4 Ko sur l'ensemble
    /// attributes + content state. On ne stocke donc PAS l'image de couverture
    /// ici (elle ferait plusieurs dizaines de Ko). À la place, elle est écrite
    /// dans le container App Group partagé et le widget la lit à partir du
    /// sessionId.
    public let sessionId: String
    public let bookTitle: String
    public let bookAuthor: String

    public init(sessionId: String, bookTitle: String, bookAuthor: String) {
        self.sessionId = sessionId
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
    }

    /// Chemin sur disque de la couverture pour une session donnée, dans le
    /// container partagé App Group. Le widget et l'app utilisent cette même
    /// méthode pour écrire / lire l'image.
    public static func coverFileURL(for sessionId: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.fr.lexday.app")?
            .appendingPathComponent("live_activity_cover_\(sessionId).jpg")
    }
}
