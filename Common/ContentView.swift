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
  
  @AppStorage(Keys.selectedTab) private var selectedTab: String = Values.infoTab
  
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
    let eventsAccessible = eventsAccessGranted || EKEventStore.authorizationStatus(for: .event) == .fullAccess
    let remindersAccessible = remindersAccessGranted || EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    let locationAccessible = locationAccessGranted || LocationManager().isAuthorized
    
    let isCompact = horizontalSizeClass == .compact
    NavigationStack {
      TabView(selection:$selectedTab) {
        
        Tab(value:Values.infoTab) {
          VStack {
            if !hideIntroduction {
              VStack(alignment: .leading, spacing:10) {
                Image("Wordmark")
                Text("A simple text-based widget for reminders and calendars. Each widget can customize the visible items and style.\n\nPreview the items that will be displayed below. Add widgets from the home screen.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                
                HStack(alignment: .center) {
                  if !eventsAccessible {
                    Button(action: {
                      Task {
                        await checkEventsAccess(interactive: true)
                        eventsAccessGranted = true
                      }
                    }) {
                      VStack(spacing:10) {
                        Image(systemName: "calendar")
                          .font(.body)
                        Text("Enable\nCalendar")
                          .font(.caption)
                      }.frame(maxWidth: .infinity)
                    }
                  }
                  
                  if !remindersAccessible {
                    Button(action: {
                      Task {
                        await checkRemindersAccess(interactive: true)
                        remindersAccessGranted = true
                      }
                    }) {
                      VStack(spacing:10) {
                        Image(systemName: "checkmark.circle")
                          .font(.body)
                        Text("Enable\nReminders")
                          .font(.caption)
                      }.frame(maxWidth: .infinity)
                    }
                  }
                  
                  if !locationAccessible {
                    Button(action: {
                      Task {
                        LocationManager().checkAuthorization()
                        locationAccessGranted = true
                      }
                    }) {
                      VStack(spacing:10) {
                        Image(systemName: "map")
                          .font(.body)
                        Text("Enable\nWeather")
                          .font(.caption)
                      }.frame(maxWidth: .infinity)
                    }
                  }

                }
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment:.center)
              }
              .padding(.top,40)
              .padding(.horizontal, 36)
              .padding(.bottom, 10)
              .padding()
            }
            ScrollView {
              let previews = Group {
                VStack {

                  if eventsAccessGranted || EKEventStore.authorizationStatus(for: .event) == .fullAccess {
                    if (isCompact) {
                      WidgetPreviewView(config: ConfigurationIntent.appComboConfig)
                        .frame(minHeight: 1024)
                        .padding(.leading, 20)
                    } else {
                      WidgetPreviewView(config: ConfigurationIntent.bigAppComboConfig)
                        .frame(minHeight: 1440)
                      
                    }
                  } else {
                    
                  }
                }.frame(maxWidth:isCompact ? 400 : 800)
              }
              
              VStack(spacing:0) {
                //previews
              }.padding()
              //          } else {
              //            HStack(spacing:0) {
              //              previews
              //            }.padding()
              //          }
              
            }
            
            .frame(maxWidth: .infinity)
            .refreshable {
              reloadDate = Date()
            }
            
          }
          
          .background(.regularMaterial)
          .frame(maxWidth: .infinity)
          
        } label: {
          Image(systemName: "info.circle")
            .environment(\.symbolVariants, selectedTab == Values.infoTab ? .fill : .none)
          
        }
        
        
        
        if (eventsAccessGranted || EKEventStore.authorizationStatus(for: .event) == .fullAccess) {
          Tab(value:Values.calendarTab) {
            VStack {
              WidgetPreviewView(config: ConfigurationIntent.comboConfig)
                .navigationTitle("First Tab Title")
            }
            .background(.regularMaterial)
          } label: {
            
            Image(systemName: "31.square")
              .environment(\.symbolVariants, selectedTab == Values.calendarTab ? .fill : .none)
            
          }
        }
        
        
        
        if (remindersAccessible) {
          Tab(value: Values.reminderTab) {
            WidgetPreviewView(config: ConfigurationIntent.remindersConfig)
              .background(.regularMaterial)
              .environment(\.symbolVariants, .none)
          } label: {
            Image(systemName: "checkmark.circle")
              .environment(\.symbolVariants, selectedTab == Values.reminderTab ? .fill : .none)
          }
        }
        
        if (locationAccessible) {
          Tab(value:Values.timezoneTab) {
            VStack {
              Section(header: Text("Timezones")) {
                WidgetPreviewView(config: ConfigurationIntent.timezonesConfig)
                  .navigationTitle("TITE")
              }
            }
            .background(.regularMaterial)
          } label: {
            Image(systemName: "globe.americas")
              .environment(\.symbolVariants, selectedTab == Values.timezoneTab ? .fill : .none)
          }
          
          Tab(value:Values.weatherTab) {
            VStack {
              Section(header: Text("Today")) {
                WidgetPreviewView(config: ConfigurationIntent.weatherCurrentConfig)
              }
              Section(header: Text("This Week")) {
                WidgetPreviewView(config: ConfigurationIntent.weatherDailyConfig)
              }
            }
            .background(.regularMaterial)
          } label: {
            Image(systemName: "cloud.sun")
              .environment(\.symbolVariants, selectedTab == Values.weatherTab ? .fill : .none)
          }
        }
        
        
        
        
        
        
        
        
      }
      
      
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
