import SwiftUI

@main
struct ChronographMacApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusBarController: StatusBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusBarController = StatusBarController()
  }
}
