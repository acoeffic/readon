# App Apple Watch LexDay — mise en place

Une cible app **watchOS** (`LexDayWatchApp`) a été ajoutée au projet. Elle affiche
la lecture en cours et permet de **Lancer / Mettre en pause / Reprendre / Arrêter**
une session depuis le poignet.

## Ce qui a été créé / modifié

App Watch (`ios/LexDayWatchApp/`) :
- `LexDayWatchApp.swift` — point d'entrée SwiftUI (`@main`).
- `ContentView.swift` — UI : couverture, titre, auteur, stats du jour (min + flow), boutons de contrôle.
- `WatchSessionManager.swift` — WatchConnectivity côté Watch (reçoit l'état, envoie les commandes).
- `Info.plist`, `LexDayWatch.entitlements` (App Group `group.fr.lexday.app`), `Assets.xcassets`.

Pont iPhone :
- `ios/Runner/WatchConnectivityManager.swift` — WCSession côté iPhone. Reçoit les commandes de la Watch et les écrit dans l'App Group ; pousse l'état (livre + stats) vers la Watch.
- `ios/Runner/AppDelegate.swift` — active le pont au lancement + expose le MethodChannel `fr.lexday.app/watch`.

Flutter :
- `lib/services/watch_control_service.dart` — pousse l'état vers la Watch et applique par polling les commandes reçues (start/pause/resume/stop) via `ReadingSessionService`.
- `lib/pages/splash/splash_screen.dart` — démarre le service au lancement.
- `lib/services/widget_service.dart` — pousse l'état vers la Watch à chaque rafraîchissement du widget.

Projet Xcode :
- `Runner.xcodeproj/project.pbxproj` — cible `LexDayWatchApp` (bundle `fr.lexday.app.watchkitapp`, SDK watchOS, équipe 9WN55FN2D3), phase **Embed Watch Content** + dépendance dans Runner. Le script reproductible est `ios/tool_add_watch_target.py`.

## Architecture (résumé)

```
Watch (boutons)  --WatchConnectivity-->  iPhone (WatchConnectivityManager)
                                              |  écrit dans App Group
                                              v
                                   Flutter WatchControlService (polling)
                                              |  start/pause/resume/stop
                                              v
                                      ReadingSessionService

iPhone (livre + stats App Group) --pushState--> WatchConnectivity --> Watch (UI)
```

Le mécanisme réutilise l'App Group `group.fr.lexday.app` déjà utilisé par le widget
et la Live Activity. Les commandes Watch passent par des clés dédiées
(`watchPendingCommand*`) distinctes de celles des App Intents de la Live Activity.

## À finaliser dans Xcode (étapes manuelles)

1. Ouvrir `ios/Runner.xcworkspace`. La cible `LexDayWatchApp` apparaît.
2. `LexDayWatchApp` → **Signing & Capabilities** : vérifier l'équipe (déjà réglée sur 9WN55FN2D3) et « Automatically manage signing ». Xcode créera l'App ID `fr.lexday.app.watchkitapp`.
3. Vérifier que la capability **App Groups** liste bien `group.fr.lexday.app` (lue depuis l'entitlements). Si besoin, l'activer pour le nouvel App ID.
4. (Recommandé) lancer `pod install` puis builder le schéma **Runner** sur un iPhone avec une Apple Watch appairée. L'app Watch s'installe via l'app compagnon.
5. Optionnel : retirer le fichier de sauvegarde `Runner.xcodeproj/project.pbxproj.bak`.

WatchConnectivity est un framework système (auto-lié via `import WatchConnectivity`),
aucun pod n'est requis pour la Watch.

## Limites connues (à garder en tête)

- Le pilotage en temps réel suppose que l'app iPhone tourne (au premier plan ou récemment en arrière-plan). Les commandes sont mises en file et appliquées au prochain réveil de l'app.
- **Lancer** démarre une session pour le livre en cours, à sa dernière page connue.
- **Arrêter** termine la session à la page courante du livre (ou la page de départ si inconnue) ; l'enregistrement fin de session par photo/OCR reste possible côté iPhone.
- Couverture et stats proviennent des données du widget (App Group), rafraîchies quand le widget se rafraîchit.
