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

extension Bool {
  var inverted: Self {
    get { !self }
    set { self = !newValue }
  }
}

struct ChronographTabView: View {
  @Environment(\.horizontalSizeClass) var horizontalSizeClass
  
  let eventStore = EKEventStore()
  @State var remindersAccessGranted: Bool = false
  @State var eventsAccessGranted: Bool = false
  @State var locationAccessGranted: Bool = false
  @State var reloadDate: Date = Date()
  @AppStorage(Keys.hideIntroduction, store: UserDefaults(suiteName: Keys.suiteName)) private var hideIntroduction = false
  
  @AppStorage(Keys.selectedTab) private var selectedTab: String = Values.calendarTab
  
  @State var calendarSettingsVisible: Bool = false
  @State var reminderSettingsVisible: Bool = false
  @State var timezoneSettingsVisible: Bool = false
  @State var weatherSettingsVisible: Bool = false
  
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
  
  private var enableCalendarButton: some View {
    Button {
      Task {
        await checkEventsAccess(interactive: true)
        eventsAccessGranted = true
      }
    } label: {
      Label("Enable Calendar", systemImage: "calendar")
        .font(.title2)
    }
    .buttonBorderShape(.capsule)
    .buttonStyle(.borderedProminent)
    .frame(maxWidth: .infinity)
  }
  
  private var enableRemindersButton: some View {
    Button {
      Task {
        await checkRemindersAccess(interactive: true)
        remindersAccessGranted = true
      }
    } label: {
      Label("Enable Reminders", systemImage: "checkmark.circle")
        .font(.title2)
    }
    .buttonBorderShape(.capsule)
    .buttonStyle(.borderedProminent)
    .frame(maxWidth: .infinity)
  }
  
  private var enableLocationButton: some View {
    Button {
      Task {
        LocationManager().checkAuthorization()
        locationAccessGranted = true
      }
    } label: {
      Label("Enable Location", systemImage: "map")
        .font(.title2)
    }
    .buttonBorderShape(.capsule)
    .buttonStyle(.borderedProminent)
    .frame(maxWidth: .infinity)
  }
  
  var body: some View {
    let eventsAccessible = eventsAccessGranted || EKEventStore.authorizationStatus(for: .event) == .fullAccess
    let remindersAccessible = remindersAccessGranted || EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    let locationAccessible = locationAccessGranted || LocationManager().isAuthorized
    
    let isCompact = horizontalSizeClass == .compact
    
    TabView(selection:$selectedTab) {
      
      Tab(value:Values.infoTab) {
        VStack {
          
          VStack(alignment: .leading, spacing:10) {
            Image("Wordmark")
            Text("A simple text-based widget for reminders and calendars. Each widget can customize the visible items and style.\n\nPreview the items that will be displayed using the tabs below. Add widgets from the home screen.")
              .font(.body)
              .foregroundStyle(.secondary)
            
            VStack(alignment: .center) {
              
              if !eventsAccessible {
                enableCalendarButton
              }
              
              if !remindersAccessible {
                enableRemindersButton
              }
              
              if !locationAccessible {
                enableLocationButton
              }
            }
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment:.center)
          }
          .padding(.top,32)
          .padding(.bottom, 10)
          .padding()
          
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment:.top)
          .refreshable {
            reloadDate = Date()
          }
          
        }
        .padding()
        .background(.regularMaterial)
        .frame(maxWidth: .infinity)
      } label: {
        Image(systemName: "info.circle")
          .environment(\.symbolVariants, selectedTab == Values.infoTab ? .fill : .none)
        
      }
      
      Tab(value:Values.calendarTab) {
        if (eventsAccessGranted || EKEventStore.authorizationStatus(for: .event) == .fullAccess) {
          NavigationStack {
            WidgetPreviewView(config: ConfigurationIntent.appComboConfig)
              .background(.regularMaterial)
              .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                  Button(action: {
                    calendarSettingsVisible.toggle()
                  }) {
                    Label("Settings", systemImage: "ellipsis")
                  }
                }
              }
              .sheet(isPresented: $calendarSettingsVisible) {
                CalendarSettingsView()
                  .presentationDetents([.medium, .large])
              }
          }
        } else {
          enableCalendarButton
        }
      } label: {
        Image(systemName: "31.square")
          .environment(\.symbolVariants, selectedTab == Values.calendarTab ? .fill : .none)
      }
      
      Tab(value: Values.reminderTab) {
        if (remindersAccessGranted || EKEventStore.authorizationStatus(for: .reminder) == .fullAccess) {
          NavigationStack {
            WidgetPreviewView(config: ConfigurationIntent.remindersConfig)
              .background(.regularMaterial)
              .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                  Button(action: {
                    reminderSettingsVisible.toggle()
                  }) {
                    Label("Settings", systemImage: "ellipsis")
                  }
                }
              }
              .sheet(isPresented: $reminderSettingsVisible) {
                RemindersSettingsView()
                  .presentationDetents([.medium, .large])
              }
          }
        } else {
          enableRemindersButton
        }
      } label: {
        Image(systemName: "checkmark.circle")
          .environment(\.symbolVariants, selectedTab == Values.reminderTab ? .fill : .none)
      }
      
      Tab(value:Values.timezoneTab) {
          NavigationStack {
            WidgetPreviewView(config: ConfigurationIntent.timezonesConfig)
              .background(.regularMaterial)
              .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                  Button(action: {
                    timezoneSettingsVisible.toggle()
                  }) {
                    Label("Settings", systemImage: "ellipsis")
                  }
                }
              }
              .sheet(isPresented: $timezoneSettingsVisible) {
                TimezonesSettingsView()
                  .presentationDetents([.medium, .fraction(0.35), .large])
              }
          }
      } label: {
        Image(systemName: "globe.americas")
          .environment(\.symbolVariants, selectedTab == Values.timezoneTab ? .fill : .none)
      }
      
      Tab(value:Values.weatherTab) {
        if locationAccessGranted || LocationManager().isAuthorized {
          NavigationStack {
            WidgetPreviewView(config: ConfigurationIntent.weatherCurrentConfig)
              .background(.regularMaterial)
              .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                  Button(action: {
                    weatherSettingsVisible.toggle()
                  }) {
                    Label("Settings", systemImage: "ellipsis")
                  }
                }
              }
              .sheet(isPresented: $weatherSettingsVisible) {
                WeatherSettingsView()
                  .presentationDetents([.medium, .fraction(0.35), .large])
              }
          }
        } else {
          enableLocationButton
        }
      } label: {
        Image(systemName: "cloud.sun")
          .environment(\.symbolVariants, selectedTab == Values.weatherTab ? .fill : .none)
      }
    }
    
//    .tabViewStyle(.page)
//    .indexViewStyle(.page)
//    .onAppear {
//      UIPageControl.appearance().currentPageIndicatorTintColor = UIColor.black
//      UIPageControl.appearance().pageIndicatorTintColor = UIColor.black
//    }
 
  }
  
}


#Preview {
  ChronographTabView()
}
