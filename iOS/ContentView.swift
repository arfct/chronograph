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
      
      VStack {
        VStack(alignment: .leading, spacing:10) {
          Image("Wordmark")
          Text("A simple text-based widget for reminders and calendars. Each widget can customize the visible items and style.\n\nPreview the items that will be displayed below. Add widgets from the home screen.")
            .foregroundStyle(.secondary)
        }
        .padding(.top,40)
        .padding(.leading, 36)
        .padding(.bottom, 10)
        .padding()
        
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
            }.frame(maxWidth:400)
            
            Divider()
              .padding(.vertical, 20)
              .padding(.leading, 36)
            
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
            }.frame(maxWidth:400)
          }
            .background(.background)
          //          .cornerRadius(20)
          if horizontalSizeClass == .compact {
            VStack(spacing:0) {
              previews
            }.padding()
          } else {
            HStack(spacing:0) {
              previews
            }.padding()
          }
          
        }
        .background(.background)
      }
      
      .background(.regularMaterial)
    }
  }
}

#Preview {
  ContentView()
}
