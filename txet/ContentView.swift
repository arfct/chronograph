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
  
  let eventStore = EKEventStore()
  @State var reminders: [EventEntry]? = []
  @State var events: [EventEntry]? = []
  @State var remindersAccessGranted: Bool = false
  @State var eventsAccessGranted: Bool = false
  
  private func checkRemindersAccess() async {
    do {
      remindersAccessGranted = try await eventStore.requestFullAccessToReminders()
      if remindersAccessGranted {
        reminders = await fetchReminders()
      }
    } catch {
      print("Access to reminders denied: \(String(describing: error.localizedDescription))")
    }
  }
  
  private func checkEventsAccess() async {
    do {
      eventsAccessGranted = try await eventStore.requestFullAccessToEvents()
      if eventsAccessGranted {
        events = await fetchEvents(calendarIDs: [])
      }
    } catch {
      print("Access to events denied: \(String(describing: error.localizedDescription))")
    }
  }
  
  private func openAppSettings() {
    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(appSettings)
    }
  }
  
  var body: some View {
    NavigationStack {
      VStack(alignment: .leading) {
        Text("txet").font(.largeTitle)
        Text("provides a pair of simple text-based widgets for reminders and calendars. Add widgets from the home screen.\n\nPreview the items that will be displayed below — each widget can customize the visible calendars and style.")
    
        
      }.padding()
      List {
        Section("Reminders") {
          if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
            WidgetPreviewView(kind: "reminders")
              .frame(minHeight: 200)
          } else {
            Button(action: {
              openAppSettings()
            }) {
              Label("Enable Reminders Access", systemImage: "lock")
            }
          }
          
        }
        Section("Calendar") {
          if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            WidgetPreviewView(kind: "calendar")
              .frame(minHeight: 200)
          } else {
            Button(action: {
              openAppSettings()
            }) {
              Label("Enable Calendar Access", systemImage: "lock")
            }
          }
          
        }
      }
    }
    .task {
      await checkRemindersAccess()
      await checkEventsAccess()
    }
    
  }
}

#Preview {
  ContentView()
}
