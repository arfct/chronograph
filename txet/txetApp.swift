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
              print("Opening URL: \(url)")
              UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}
