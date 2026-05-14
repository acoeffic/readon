import Flutter
import UIKit
import SwiftUI
import GoogleMaps
import Firebase
import FirebaseMessaging
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Channel utilisé pour piloter les Live Activities depuis Flutter.
  private let liveActivityChannelName = "fr.lexday.app/reading_live_activity"
  /// Channel pour présenter le paywall natif SubscriptionStoreView.
  private let paywallChannelName = "fr.lexday.app/paywall"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Read Google Places API key from env.json (injected via --dart-define-from-file)
    if let path = Bundle.main.path(forResource: "env", ofType: "json"),
       let data = FileManager.default.contents(atPath: path),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
       let apiKey = json["GOOGLE_PLACES_API_KEY"], !apiKey.isEmpty, apiKey != "PLACEHOLDER" {
      GMSServices.provideAPIKey(apiKey)
    }
    FirebaseApp.configure()

    // With FirebaseAppDelegateProxyEnabled = false, we must explicitly
    // register for remote notifications so APNs tokens are delivered.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Forward APNs token to Firebase Messaging (required when proxy is disabled)
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Enregistre le MethodChannel Live Activity sur le moteur Flutter implicite.
    // On passe par le PluginRegistrar pour obtenir un BinaryMessenger de manière stable
    // quelle que soit la version de l'API du bridge.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReadingLiveActivityChannel") {
      setupLiveActivityChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SubscriptionPaywallChannel") {
      setupPaywallChannel(messenger: registrar.messenger())
    }
  }

  // MARK: - Subscription paywall MethodChannel (iOS 17+)

  private func setupPaywallChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: paywallChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "isAvailable":
        if #available(iOS 17.0, *) {
          result(true)
        } else {
          result(false)
        }
      case "present":
        guard #available(iOS 17.0, *) else {
          result(FlutterError(code: "UNSUPPORTED_OS",
                              message: "SubscriptionStoreView requires iOS 17+",
                              details: nil))
          return
        }
        let args = call.arguments as? [String: Any]
        let productIDs = args?["productIDs"] as? [String] ?? []
        self.presentNativePaywall(productIDs: productIDs, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @available(iOS 17.0, *)
  private func presentNativePaywall(productIDs: [String], result: @escaping FlutterResult) {
    guard let rootVC = self.window?.rootViewController else {
      result(FlutterError(code: "NO_ROOT_VC",
                          message: "No root view controller available",
                          details: nil))
      return
    }

    // Trouve le topmost presented VC pour présenter modal par-dessus tout.
    var top = rootVC
    while let presented = top.presentedViewController {
      top = presented
    }

    var hosting: UIViewController?
    let view = SubscriptionPaywallView(productIDs: productIDs) {
      hosting?.dismiss(animated: true)
    }
    let controller = UIHostingController(rootView: view)
    controller.modalPresentationStyle = .pageSheet
    hosting = controller

    top.present(controller, animated: true) {
      result(true)
    }
  }

  // MARK: - Live Activity MethodChannel

  private func setupLiveActivityChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: liveActivityChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if #available(iOS 16.1, *) {
        self.handleLiveActivityCall(call, result: result)
      } else {
        result(FlutterError(code: "UNSUPPORTED_OS",
                            message: "Live Activities require iOS 16.1+",
                            details: nil))
      }
    }
  }

  @available(iOS 16.1, *)
  private func handleLiveActivityCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(ActivityAuthorizationInfo().areActivitiesEnabled)

    case "start":
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String,
            let title = args["bookTitle"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "sessionId + bookTitle requis", details: nil))
        return
      }
      let author = args["bookAuthor"] as? String ?? ""
      let cover = args["coverBase64"] as? String ?? ""
      let accumulated = args["accumulatedSeconds"] as? Int ?? 0
      let isPaused = args["isPaused"] as? Bool ?? false

      Task {
        do {
          try await self.startActivity(
            sessionId: sessionId, title: title, author: author,
            coverBase64: cover, accumulatedSeconds: accumulated, isPaused: isPaused
          )
          result(true)
        } catch {
          result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
      }

    case "update":
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "sessionId requis", details: nil))
        return
      }
      let accumulated = args["accumulatedSeconds"] as? Int ?? 0
      let isPaused = args["isPaused"] as? Bool ?? false
      Task {
        await self.updateActivity(sessionId: sessionId, accumulatedSeconds: accumulated, isPaused: isPaused)
        result(true)
      }

    case "end":
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "sessionId requis", details: nil))
        return
      }
      Task {
        await self.endActivity(sessionId: sessionId)
        result(true)
      }

    case "pollPendingCommand":
      result(self.consumePendingCommand())

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - ActivityKit helpers

  @available(iOS 16.1, *)
  private func startActivity(
    sessionId: String, title: String, author: String,
    coverBase64: String, accumulatedSeconds: Int, isPaused: Bool
  ) async throws {
    // Écrit la couverture dans le container App Group AVANT de créer
    // l'activity, pour que le widget puisse la lire. On ne la met pas dans
    // les attributes car ActivityKit limite leur taille à ~4 Ko.
    writeCoverToSharedContainer(sessionId: sessionId, base64: coverBase64)

    // Évite les doublons si une activity est déjà en cours pour cette session.
    if Activity<ReadingActivityAttributes>.activities.contains(where: { $0.attributes.sessionId == sessionId }) {
      await updateActivity(sessionId: sessionId, accumulatedSeconds: accumulatedSeconds, isPaused: isPaused)
      return
    }

    let attributes = ReadingActivityAttributes(
      sessionId: sessionId, bookTitle: title, bookAuthor: author
    )
    let referenceDate = Date().addingTimeInterval(-Double(accumulatedSeconds))
    let state = ReadingActivityAttributes.ContentState(
      timerReferenceDate: referenceDate,
      accumulatedSeconds: accumulatedSeconds,
      isPaused: isPaused
    )

    if #available(iOS 16.2, *) {
      _ = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: state, staleDate: nil),
        pushType: nil
      )
    } else {
      _ = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
    }
  }

  /// Décode `base64` en image, la redimensionne si besoin, et l'écrit
  /// dans le container App Group pour que le widget puisse la lire.
  @available(iOS 16.1, *)
  private func writeCoverToSharedContainer(sessionId: String, base64: String) {
    guard let fileURL = ReadingActivityAttributes.coverFileURL(for: sessionId) else { return }
    guard !base64.isEmpty, let data = Data(base64Encoded: base64),
          let image = UIImage(data: data) else {
      // Si pas de couverture, on supprime l'ancienne si elle existe.
      try? FileManager.default.removeItem(at: fileURL)
      return
    }
    // Redimensionne à max 240px pour limiter la taille disque (on reste
    // très en-dessous du quota mémoire des widgets).
    let resized = image.resizedForLiveActivity(maxDimension: 240)
    guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { return }
    try? jpeg.write(to: fileURL, options: .atomic)
  }

  @available(iOS 16.1, *)
  private func updateActivity(sessionId: String, accumulatedSeconds: Int, isPaused: Bool) async {
    for activity in Activity<ReadingActivityAttributes>.activities
    where activity.attributes.sessionId == sessionId {
      let currentReference: Date
      if #available(iOS 16.2, *) {
        currentReference = activity.content.state.timerReferenceDate
      } else {
        currentReference = activity.contentState.timerReferenceDate
      }
      let reference = isPaused
        ? currentReference
        : Date().addingTimeInterval(-Double(accumulatedSeconds))
      let newState = ReadingActivityAttributes.ContentState(
        timerReferenceDate: reference,
        accumulatedSeconds: accumulatedSeconds,
        isPaused: isPaused
      )
      if #available(iOS 16.2, *) {
        await activity.update(ActivityContent(state: newState, staleDate: nil))
      } else {
        await activity.update(using: newState)
      }
    }
  }

  @available(iOS 16.1, *)
  private func endActivity(sessionId: String) async {
    for activity in Activity<ReadingActivityAttributes>.activities
    where activity.attributes.sessionId == sessionId {
      if #available(iOS 16.2, *) {
        await activity.end(nil, dismissalPolicy: .immediate)
      } else {
        await activity.end(dismissalPolicy: .immediate)
      }
    }
    // Nettoie le fichier de couverture dans le container App Group.
    if let fileURL = ReadingActivityAttributes.coverFileURL(for: sessionId) {
      try? FileManager.default.removeItem(at: fileURL)
    }
  }

  /// Lit et efface la commande en attente (pause/resume) écrite par un App Intent.
  @available(iOS 16.1, *)
  private func consumePendingCommand() -> [String: Any]? {
    guard let defaults = UserDefaults(suiteName: "group.fr.lexday.app") else { return nil }
    guard let command = defaults.string(forKey: "pendingReadingCommand"),
          let sessionId = defaults.string(forKey: "pendingReadingCommandSession") else {
      return nil
    }
    let timestamp = defaults.double(forKey: "pendingReadingCommandTimestamp")
    defaults.removeObject(forKey: "pendingReadingCommand")
    defaults.removeObject(forKey: "pendingReadingCommandSession")
    defaults.removeObject(forKey: "pendingReadingCommandTimestamp")
    return [
      "command": command,
      "sessionId": sessionId,
      "timestamp": timestamp
    ]
  }
}

// MARK: - UIImage helpers

extension UIImage {
  /// Redimensionne l'image pour qu'elle rentre dans `maxDimension` x `maxDimension`
  /// tout en conservant le ratio. Retourne l'image inchangée si elle est déjà
  /// plus petite.
  func resizedForLiveActivity(maxDimension: CGFloat) -> UIImage {
    let maxSide = max(size.width, size.height)
    guard maxSide > maxDimension else { return self }
    let scale = maxDimension / maxSide
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: newSize))
    }
  }
}
