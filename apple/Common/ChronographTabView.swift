import SwiftUI
import EventKit
import WidgetKit

struct ChronographTabView: View {
  let eventStore = EKEventStore()
  // Held for the life of the view: a location prompt is dropped if the
  // manager that asked for it is deallocated.
  private let locationManager = LocationManager()
  @Environment(\.scenePhase) private var scenePhase
  @State var remindersAccessGranted: Bool = false
  @State var eventsAccessGranted: Bool = false
  @State var reloadDate: Date = Date()
  @AppStorage(Keys.hideIntroduction, store: UserDefaults(suiteName: Keys.suiteName)) private var hideIntroduction = false
  
  @AppStorage(Keys.selectedTab) private var selectedTab: String = Values.calendarTab

  @AppStorage(Keys.weatherUseCurrentLocation, store: UserDefaults(suiteName: Keys.suiteName))
  private var weatherUseCurrentLocation = true
  @AppStorage(Keys.weatherZipCode, store: UserDefaults(suiteName: Keys.suiteName))
  private var weatherZipCode = ""
  @AppStorage(Keys.favoriteTimezones, store: UserDefaults(suiteName: Keys.suiteName))
  private var favoriteTimezones: [String] = []

  private var weatherPreviewConfig: WidgetConfig {
    var config = WidgetConfig.weatherCurrent
    if !weatherUseCurrentLocation {
      config.weatherLocation = weatherZipCode.trimmingCharacters(in: .whitespaces)
    }
    return config
  }

  private var timezonesPreviewConfig: WidgetConfig {
    var config = WidgetConfig.timezones
    let favorites = favoriteTimezones.compactMap { TimeZone(identifier: $0) }
    if !favorites.isEmpty {
      config.timezones = favorites.map { TimeZoneSelectionEntity.with(timeZone: $0) }
    }
    return config
  }

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
      remindersAccessGranted = false
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
      eventsAccessGranted = false
    }
  }
  
  private var enableCalendarButton: some View {
    Button {
      Task {
        await checkEventsAccess(interactive: true)
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
      // Prompts (or opens Settings when already denied). The system alert
      // takes the scene inactive, so the body re-reads the real status once
      // the user has answered. macOS shows the prompt without changing the
      // scene phase, so the delegate callback triggers the re-read there.
      locationManager.onAuthorizationChange = { reloadDate = Date() }
      locationManager.checkAuthorization()
    } label: {
      Label("Enable Location", systemImage: "map")
        .font(.title2)
    }
    .buttonBorderShape(.capsule)
    .buttonStyle(.borderedProminent)
    .frame(maxWidth: .infinity)
  }
  
#if DEBUG && !os(watchOS)
  /// Seeds through EventKit and nudges WidgetKit so the home-screen widget
  /// re-renders without waiting for its normal refresh.
  private func seedSampleEvents() {
    Task {
      do {
        let count = try await SampleCalendar.seed()
        widgetLog.debug("Seeded \(count) sample events")
        WidgetCenter.shared.reloadAllTimelines()
      } catch {
        widgetLog.error("Seeding sample events failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
#endif

  /// A widget preview with a settings button that opens `settings` in a sheet.
  /// `sampleData` adds the DEBUG-only seeding menu; see SampleCalendar.
  private func previewTab<Settings: View>(config: WidgetConfig,
                                          settingsVisible: Binding<Bool>,
                                          sampleData: Bool = false,
                                          @ViewBuilder settings: @escaping () -> Settings) -> some View {
    NavigationStack {
      WidgetPreviewView(config: config)
        .background(.regularMaterial)
        .toolbar {
          ToolbarItemGroup(placement: .primaryAction) {
            #if DEBUG && !os(watchOS)
            // Widget layout can only be judged against real rows, and there
            // is no supported way to put them in a simulator from outside.
            // See SampleCalendar.
            if sampleData {
              Menu {
                Button("Seed sample events") { seedSampleEvents() }
                Button("Clear sample events", role: .destructive) {
                  SampleCalendar.clear()
                  WidgetCenter.shared.reloadAllTimelines()
                }
              } label: {
                Label("Sample data", systemImage: "calendar.badge.plus")
              }
            }
            #endif
            Button(action: {
              settingsVisible.wrappedValue.toggle()
            }) {
              Label("Settings", systemImage: "ellipsis")
            }
          }
        }
        .sheet(isPresented: settingsVisible, content: settings)
    }
  }
  
  var body: some View {
    let eventsAccessible = eventsAccessGranted || EKEventStore.authorizationStatus(for: .event) == .fullAccess
    let remindersAccessible = remindersAccessGranted || EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    let _ = scenePhase
    let _ = reloadDate
    let locationAccessible = locationManager.isAuthorized
    
    TabView(selection:$selectedTab) {
      
      Tab(value:Values.infoTab) {
        VStack {
          
          VStack(alignment: .leading, spacing:10) {
            Image("Wordmark")
            Text("A simple text-based widget for reminders and calendars. Each widget can customize the visible items and style.\n\nPreview the items that will be displayed using the tabs. Add widgets from the home screen.")
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
          previewTab(config: .appCombo, settingsVisible: $calendarSettingsVisible,
                     sampleData: true) {
            CalendarSettingsView()
              .settingsSheetChrome("Calendar")
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
          previewTab(config: .reminders, settingsVisible: $reminderSettingsVisible) {
            RemindersSettingsView()
              .settingsSheetChrome("Reminders")
          }
        } else {
          enableRemindersButton
        }
      } label: {
        Image(systemName: "checkmark.circle")
          .environment(\.symbolVariants, selectedTab == Values.reminderTab ? .fill : .none)
      }
      
      Tab(value:Values.timezoneTab) {
        previewTab(config: timezonesPreviewConfig, settingsVisible: $timezoneSettingsVisible) {
          TimezonesSettingsView()
            .settingsSheetChrome("Time Zones")
        }
      } label: {
        Image(systemName: "globe.americas")
          .environment(\.symbolVariants, selectedTab == Values.timezoneTab ? .fill : .none)
      }
      
      Tab(value:Values.weatherTab) {
        let hasFixedLocation = !weatherUseCurrentLocation && !weatherZipCode.isEmpty
        if locationAccessible || hasFixedLocation {
          previewTab(config: weatherPreviewConfig, settingsVisible: $weatherSettingsVisible) {
            WeatherSettingsView()
              .settingsSheetChrome("Weather")
          }
        } else {
          VStack(spacing: 16) {
            enableLocationButton
            Button("Use a Zip Code Instead") {
              // Open straight to the zip field rather than a toggle the user
              // has to find first.
              weatherUseCurrentLocation = false
              weatherSettingsVisible = true
            }
          }
          .sheet(isPresented: $weatherSettingsVisible) {
            WeatherSettingsView()
              .settingsSheetChrome("Weather")
          }
        }
      } label: {
        Image(systemName: "cloud.sun")
          .environment(\.symbolVariants, selectedTab == Values.weatherTab ? .fill : .none)
      }
    }
#if DEBUG && !os(watchOS)
    // `-seedSampleEvents YES` seeds on launch, for headless simulator checks
    // where the toolbar menu cannot be tapped.
    .task {
      if UserDefaults.standard.bool(forKey: "seedSampleEvents") {
        seedSampleEvents()
      }
    }
#endif
    
//    .tabViewStyle(.page)
//    .indexViewStyle(.page)
//    .onAppear {
//      UIPageControl.appearance().currentPageIndicatorTintColor = UIColor.black
//      UIPageControl.appearance().pageIndicatorTintColor = UIColor.black
//    }
 
  }
  
}


extension View {
  /// Title, Done button, and detents shared by every settings sheet. The
  /// settings views stay chrome-free so they can be hosted anywhere.
  func settingsSheetChrome(_ title: String) -> some View {
    modifier(SettingsSheetChrome(title: title))
  }
}

private struct SettingsSheetChrome: ViewModifier {
  let title: String
  @Environment(\.dismiss) private var dismiss

  func body(content: Content) -> some View {
    NavigationStack {
      content
        .navigationTitle(title)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
          }
        }
    }
    // Medium keeps the preview visible behind the sheet on phones and the
    // folded iPhone Duo; regular-width screens present a form sheet instead.
    .presentationDetents([.medium, .large])
  }
}

#Preview {
  ChronographTabView()
}
