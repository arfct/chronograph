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
  @State var remindersAccessGranted: Bool = false
  @State var eventsAccessGranted: Bool = false
  @State var locationAccessGranted: Bool = false
  @State var reloadDate: Date = Date()
  @State var showSettings: Bool = false
  @AppStorage(Keys.hideIntroduction, store: UserDefaults(suiteName: Keys.suiteName)) private var hideIntroduction = false
  
  private func checkRemindersAccess(interactive: Bool = false) async {
    do {
      remindersAccessGranted = try await eventStore.requestFullAccessToReminders()
      if remindersAccessGranted {
        //        reminders = await fetchReminders()
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
        //        events = await fetchEvents(calendarIDs: [])
      } else if interactive {
        openAppSettings()
      }
    } catch {
      print("Access to events denied: \(String(describing: error.localizedDescription))")
    }
  }
  
  

  
  var body: some View {
    let isCompact = horizontalSizeClass == .compact
    NavigationStack {
      
      VStack {
        if !hideIntroduction {
          VStack(alignment: .leading, spacing:10) {
            Image("Wordmark")
            Text("A simple text-based widget for reminders and calendars. Each widget can customize the visible items and style.\n\nPreview the items that will be displayed below. Add widgets from the home screen.")
              .foregroundStyle(.secondary)
          }
          .padding(.top,40)
          .padding(.leading, 36)
          .padding(.bottom, 10)
          .padding()
        }
        ScrollView {
          let previews = Group {
            VStack {
              if locationAccessGranted || LocationManager().isAuthorized {
                
              } else {
                Button(action: {
                  Task {
                    LocationManager().checkAuthorization()
                    locationAccessGranted = true
                  }
                }) {
                  Label("Enable Weather", systemImage: "lock")
                }
                Divider()
                  .padding(.vertical, 20)
                  .padding(.leading, 36)
              }
            }.frame(maxWidth:400)
            
            VStack {
              if eventsAccessGranted || EKEventStore.authorizationStatus(for: .event) == .fullAccess {
                if (isCompact) {
                  WidgetPreviewView(config: ConfigurationIntent.comboConfig)
                    .frame(minHeight: 1024)
                } else {
                  WidgetPreviewView(config: ConfigurationIntent.bigComboConfig)
                    .frame(minHeight: 1440)
                }
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
            }.frame(maxWidth:isCompact ? 400 : 800)
            
            Divider()
              .padding(.vertical, 20)
              .padding(.leading, 36)
            
            VStack {
              if remindersAccessGranted || EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
                WidgetPreviewView(config: ConfigurationIntent.remindersConfig)
                  .frame(minHeight: 120)
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
            
            
          }
            .background(.background)
          //          .cornerRadius(20)
//          if horizontalSizeClass == .compact {
            VStack(spacing:0) {
              previews
            }.padding()
//          } else {
//            HStack(spacing:0) {
//              previews
//            }.padding()
//          }
          
        }
        
        .frame(maxWidth: .infinity)
        .refreshable {
          print("refresh")
          reloadDate = Date()
        }
        .background(.background)
      }
      .frame(maxWidth: .infinity)
      .background(.regularMaterial)
      .toolbar {
        ToolbarItemGroup(placement: .primaryAction) {
          Button(action: {
            Task {
              showSettings.toggle()
            }
          }) {
            Label("Settings", systemImage: "ellipsis")
          }
          
          #if os(macOS)
          .popover(isPresented: $showSettings) {
            SettingsView().padding()
          }
          #else
          .sheet(isPresented: $showSettings) {
            SettingsView()
              .presentationDetents([.medium, .fraction(0.35)])
          }
          #endif
        }
      }
    }
    
    
  }
}

#Preview {
  ContentView()
}
