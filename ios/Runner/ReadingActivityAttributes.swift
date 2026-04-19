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
    public let sessionId: String
    public let bookTitle: String
    public let bookAuthor: String
    /// Image de couverture encodée en base64 (récupérée via WidgetService).
    /// Peut être vide : on affiche alors un placeholder.
    public let coverBase64: String

    public init(sessionId: String, bookTitle: String, bookAuthor: String, coverBase64: String) {
        self.sessionId = sessionId
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.coverBase64 = coverBase64
    }
}
