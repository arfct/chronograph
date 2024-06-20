//
//  ContentView.swift
//  txet Watch App
//
//  Created by Nicholas Jitkoff on 6/13/24.
//

import SwiftUI
import WidgetKit
import AppIntents
import EventKit

struct ContentView: View {
    var body: some View {

          List {
            Text("txet provides a large widget for your watch's main screen in layouts like modular compact.")
            
            if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
              WidgetPreviewView(kind: "calendar")
                .frame(minHeight: 100)
            } else {
              Button(action: {
               
              }) {
                Label("Enable Calendar Access", systemImage: "lock")
              }
            }
            
            if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
              
              WidgetPreviewView(kind: "reminders")
                .frame(minHeight: 100)
            } else {
              Button(action: {
               
              }) {
                Label("Enable Reminders Access", systemImage: "lock")
              }
            }
            


          }
        
    }
}

#Preview {
    ContentView()
}
