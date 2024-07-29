import SwiftUI
import WidgetKit
import AppIntents
import EventKit

struct ContentView: View {
  var body: some View {
    
    ScrollView {
      
      VStack {
      Image("Wordmark")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .padding(.top, 40)
        .padding(.leading, 20)
        .padding(.trailing, 60)
      
      
      Text("A large widget for the modular watch face")
        .frame(maxWidth:.infinity)
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
      .padding(.bottom, 16)
      .background(.white.opacity(0.1))
      
      
      VStack(spacing:10) {
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
          WidgetPreviewView(config:ConfigurationIntent.calendarConfig)
            .frame(minHeight: 600)
        } else {
          Button(action: {
            
          }) {
            Label("Enable Calendar Access", systemImage: "lock")
          }
        }
        Divider()
          .padding(.leading, 36)
        if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
          
          WidgetPreviewView(config: ConfigurationIntent.remindersConfig)
            .frame(minHeight: 100)
            .listRowBackground(Color.clear)
        } else {
          Button(action: {
            
          }) {
            Label("Enable Reminders Access", systemImage: "lock")
          }
        }
      }.padding(.vertical)
    }
      .edgesIgnoringSafeArea(.all)
    
  }
}

#Preview {
  ContentView()
}
