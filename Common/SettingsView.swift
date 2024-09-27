//
//  SettingsView.swift
//  Chronograph
//
//  Created by Nicholas Jitkoff on 7/15/24.
//

import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) var dismiss
  @AppStorage(Keys.tokenizeParens, store: UserDefaults(suiteName: Keys.suiteName)) private var tokenize = false
  @AppStorage(Keys.compactTime, store: UserDefaults(suiteName: Keys.suiteName)) private var compactTime = true
  @AppStorage(Keys.hideIntroduction, store: UserDefaults(suiteName: Keys.suiteName)) private var hideIntroduction = false
  
    var body: some View {
      NavigationStack {
        Form {
          Section {
            Toggle(isOn: $tokenize) {
              Text("Wrap Parenthesis")
            }
            Toggle(isOn: $compactTime) {
              Text("Compact Time")
            }
//            Toggle(isOn: $hideIntroduction) {
//              Text("Hide App Header")
//            }
          }
        }
        .toolbar {
          ToolbarItemGroup(placement: .automatic) {
            Button("Done") {
              dismiss()
            }
          }
        }
      }
    }
}

#Preview {
    SettingsView()
}
