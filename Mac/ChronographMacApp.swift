//
//  txet_macApp.swift
//  txet.mac
//
//  Created by Nicholas Jitkoff on 7/10/24.
//

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
