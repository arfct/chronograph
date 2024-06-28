import SwiftUI
import EventKit

struct Reminder: Identifiable {
  var id: String
  var reminder: EKReminder
}

struct Event: Identifiable {
  var id: String
  var event: EKEvent
}

struct ContentView: View {
  @Environment(\.horizontalSizeClass) var horizontalSizeClass
  
  let eventStore = EKEventStore()
  @State var reminders: [EventEntry]? = []
  @State var events: [EventEntry]? = []
  @State var remindersAccessGranted: Bool = false
  @State var eventsAccessGranted: Bool = false
  
  private func checkRemindersAccess(interactive: Bool = false) async {
    do {
      remindersAccessGranted = try await eventStore.requestFullAccessToReminders()
      if remindersAccessGranted {
        reminders = await fetchReminders()
      } else if interactive {
        openAppSettings()
      }
    } catch {
      print("Access to reminders denied: \(String(describing: error.localizedDescription))")
        

    }
  }
  
  private func checkEventsAccess(interactive: Bool = false) async {
    do {
      eventsAccessGranted = try await eventStore.requestFullAccessToEvents()
      if eventsAccessGranted {
        events = await fetchEvents(calendarIDs: [])
      } else if interactive {
        openAppSettings()
      }
    } catch {
      print("Access to events denied: \(String(describing: error.localizedDescription))")
    }
  }
  
  
  private func openAppSettings() {
#if os(iOS)
    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(appSettings)
    }
#elseif os(macOS)
    
#endif
  }
  
  var body: some View {
    NavigationStack {
      
      VStack(alignment: .leading) {
        Text("Chronograph").font(.system(size: 24, design:.monospaced).weight(.semibold).width(.condensed)).padding(.bottom, 10)
        Text("provides a pair of simple text-based widgets for reminders and calendars. Add widgets from the home screen.\n\nPreview the items that will be displayed below — each widget can customize the visible calendars and style.")
        
        
      }.padding()
      
      ScrollView {
        let previews = Group {
          VStack {
            if remindersAccessGranted || EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
              WidgetPreviewView(config: ConfigurationIntent.remindersConfig)
                .frame(minHeight: 230)
            } else {
              Button(action: {
                Task {
                  await checkRemindersAccess(interactive: true)
                  remindersAccessGranted = true
                }
              }) {
                Label("Enable Reminders Access", systemImage: "lock")
              }
            }
            
          }
          VStack {
            if eventsAccessGranted || EKEventStore.authorizationStatus(for: .event) == .fullAccess {
              WidgetPreviewView(config: ConfigurationIntent.calendarConfig)
                .frame(minHeight: 230)
            } else {
              Button(action: {
                Task {
                  await checkEventsAccess(interactive: true)
                  
                  eventsAccessGranted = true
                }
              }) {
                Label("Enable Calendar Access", systemImage: "lock")
              }
            }
          }
        }.padding()
          .background(.background)
          .cornerRadius(20)
        if horizontalSizeClass == .compact {
          VStack(spacing:20) {
            previews
          }.padding()
        } else {
          HStack(spacing:20) {
            previews
          }.padding()
        }
        
    
      }
      .background(.gray.opacity(0.1))
    }
    .task {
//      await checkRemindersAccess()
//      await checkEventsAccess()
    }
    
  }
}

#Preview {
  ContentView()
}
