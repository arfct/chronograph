import SwiftUI

@main
struct ChronographWatchApp: App {
  init() {
    WatchLaunchOptions.applyAtLaunch()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
