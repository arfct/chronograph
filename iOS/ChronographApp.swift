//
//  txetApp.swift
//  txet
//
//  Created by Nicholas Jitkoff on 6/13/24.
//

import SwiftUI

@main
struct txetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            .onOpenURL { url in
              var urlToOpen = url
              if urlToOpen.absoluteString.starts(with:"settings:") {
                // TODO: allow prompting for permission before opening settings
                if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                  urlToOpen = appSettings
                }
              }
              print("Opening URL: \(urlToOpen)")
              UIApplication.shared.open(urlToOpen, options: [:], completionHandler: nil)
            }
        }
    }
}
