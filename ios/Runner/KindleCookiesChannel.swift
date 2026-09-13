import Flutter
import WebKit

/// Channel `fr.lexday.app/kindle_cookies` : expose en lecture les cookies
/// *.amazon.* du store partagé des WebViews (WKWebsiteDataStore.default()).
///
/// webview_flutter ne sait que poser/effacer des cookies, jamais les lire.
/// Le sync Kindle en arrière-plan (workmanager, isolate headless, pas de
/// WebView) a besoin de l'en-tête `Cookie` : Flutter le lit ici au premier
/// plan et le met en cache (KindleCookieStore).
enum KindleCookiesChannel {
  static let name = "fr.lexday.app/kindle_cookies"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "getAmazonCookies" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // WKHTTPCookieStore doit être interrogé sur le main thread.
      DispatchQueue.main.async {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
          let now = Date()
          let amazon = cookies.filter { c in
            c.domain.contains("amazon") && (c.expiresDate == nil || c.expiresDate! > now)
          }
          let payload: [[String: Any]] = amazon.map { c in
            [
              "name": c.name,
              "value": c.value,
              "domain": c.domain,
              "path": c.path,
              "secure": c.isSecure,
            ]
          }
          result(payload)
        }
      }
    }
  }
}
