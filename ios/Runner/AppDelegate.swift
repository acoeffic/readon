import Flutter
import UIKit
import GoogleMaps
import Firebase
import FirebaseMessaging
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Channel utilisé pour piloter les Live Activities depuis Flutter.
  private let liveActivityChannelName = "fr.lexday.app/reading_live_activity"

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
    // Évite les doublons si une activity est déjà en cours pour cette session.
    if Activity<ReadingActivityAttributes>.activities.contains(where: { $0.attributes.sessionId == sessionId }) {
      await updateActivity(sessionId: sessionId, accumulatedSeconds: accumulatedSeconds, isPaused: isPaused)
      return
    }

    let attributes = ReadingActivityAttributes(
      sessionId: sessionId, bookTitle: title, bookAuthor: author, coverBase64: coverBase64
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
