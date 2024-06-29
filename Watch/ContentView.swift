import SwiftUI
import WidgetKit
import AppIntents
import EventKit

struct ContentView: View {
    var body: some View {

          List {
            Text("Chronograph provides a large widget for your watch's modular layout.")
                .listRowBackground(Color.clear)
                .font(.footnote)
            if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
              WidgetPreviewView(config:ConfigurationIntent.calendarConfig)
                .frame(minHeight: 100)
            } else {
              Button(action: {
               
              }) {
                Label("Enable Calendar Access", systemImage: "lock")
              }
            }
            
            if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
              
              WidgetPreviewView(config: ConfigurationIntent.remindersConfig)
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
