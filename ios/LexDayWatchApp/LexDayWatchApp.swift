// LexDayWatchApp.swift
// Point d'entrée de l'app Apple Watch LexDay.
//
// L'app affiche la lecture en cours (couverture, titre, auteur, stats du jour)
// et permet de piloter une session de lecture : Lancer / Pause / Reprendre /
// Arrêter. Les commandes sont envoyées à l'iPhone via WatchConnectivity ;
// l'iPhone les relaie à l'app Flutter via l'App Group `group.fr.lexday.app`.

import SwiftUI

@main
struct LexDayWatchApp: App {
    // Le manager WCSession doit vivre aussi longtemps que l'app : on le garde
    // en @StateObject pour qu'il survive aux re-render de la vue racine.
    @StateObject private var session = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}
