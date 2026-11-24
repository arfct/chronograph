import SwiftUI
import WidgetKit
import AppIntents
import EventKit

struct ContentView: View {
  @AppStorage(Keys.brailleMode, store: UserDefaults(suiteName: Keys.suiteName))
  private var legacyBrailleMode = false
  @AppStorage(Keys.obfuscation, store: UserDefaults(suiteName: Keys.suiteName))
  private var obfuscationRaw = ""

  private var obfuscation: Binding<ObfuscationStyle> {
    Binding(
      get: { ObfuscationStyle.resolve(rawValue: obfuscationRaw, legacyBrailleMode: legacyBrailleMode) },
      set: { obfuscationRaw = $0.rawValue }
    )
  }

  private let eventStore = EKEventStore()
  /// Held for the life of the view: a location prompt is dropped if its
  /// manager is released before the user answers.
  @State private var locationManager = LocationManager()
  /// Bumped after a permission prompt so the body re-reads the status.
  @State private var accessRefresh = 0
  /// The widget kinds pushed onto the stack; DEBUG launch arguments can
  /// start on one.
  @State private var path: [DisplayedContent] = WatchLaunchOptions.initialPath
  /// The visible page: a widget kind's raw value, or `settingsTab`.
  @State private var selectedTab: String = WatchLaunchOptions.initialTab

  private static let settingsTab = "settings"

  private var needsCalendar: Bool { EKEventStore.authorizationStatus(for: .event) != .fullAccess }
  private var needsReminders: Bool { EKEventStore.authorizationStatus(for: .reminder) != .fullAccess }
  private var needsLocation: Bool { !locationManager.isAuthorized }

  var body: some View {
    let _ = accessRefresh

    // One page per widget kind, as the iOS app has one tab per widget, then
    // the app-wide settings. Vertical pages follow the Digital Crown.
    NavigationStack(path: $path) {
      TabView(selection: $selectedTab) {
        ForEach(WidgetDefaultsStore.kinds, id: \.self) { kind in
          widgetPage(kind)
            .tag(kind.rawValue)
        }
        settingsPage
          .tag(Self.settingsTab)
      }
      .tabViewStyle(.verticalPage)
      .navigationDestination(for: DisplayedContent.self) { kind in
        WidgetDefaultsForm(kind: kind,
                           scrollAnchor: WatchLaunchOptions.scrollAnchor,
                           opensSelection: WatchLaunchOptions.opensSelection)
      }
    }
  }

  // MARK: Widget pages

  /// The widget as App Defaults widgets draw it, with its options one tap away.
  private func widgetPage(_ kind: DisplayedContent) -> some View {
    Group {
      if lacksAccess(kind) {
        VStack(spacing: 8) {
          Image(systemName: kind.systemImage)
            .font(.title2)
            .foregroundStyle(.secondary)
          if kind == .calendar { calendarAccessButton } else { remindersAccessButton }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        WidgetPreviewView(config: WidgetConfig(content: kind, useDefaults: true))
          .scrollDisabled(true)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      }
    }
    .navigationTitle(kind.displayName)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(value: kind) {
          Image(systemName: "slider.horizontal.3")
            .accessibilityLabel("\(kind.displayName) Options")
        }
      }
    }
  }

  /// Calendar and Reminders pages show their permission button in place of
  /// an empty preview.
  private func lacksAccess(_ kind: DisplayedContent) -> Bool {
    (kind == .calendar && needsCalendar) || (kind == .reminders && needsReminders)
  }

  private var calendarAccessButton: some View {
    Button {
      Task {
        _ = try? await eventStore.requestFullAccessToEvents()
        accessRefresh += 1
      }
    } label: {
      Label("Enable Calendar Access", systemImage: "lock")
    }
  }

  private var remindersAccessButton: some View {
    Button {
      Task {
        _ = try? await eventStore.requestFullAccessToReminders()
        accessRefresh += 1
      }
    } label: {
      Label("Enable Reminders Access", systemImage: "lock")
    }
  }

  // MARK: Settings page

  private var settingsPage: some View {
    List {
      Section {
        Image("Wordmark")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .padding(.trailing, 50)
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
      } footer: {
        Text("Each page shows a widget as App Defaults widgets draw it. Tap the options button to change its defaults.")
      }

      Section("Display") {
        DefaultFontSizePicker()
          .pickerStyle(.navigationLink)
        // The default wheel has no intrinsic height in a list row and
        // collapsed to a sliver; a navigation-link row sizes itself.
        Picker("Obfuscation", selection: obfuscation) {
          ForEach(ObfuscationStyle.allCases) { style in
            Text(style.displayName).tag(style)
          }
        }
        .pickerStyle(.navigationLink)
      }

      if needsCalendar || needsReminders || needsLocation {
        Section {
          if needsCalendar { calendarAccessButton }
          if needsReminders { remindersAccessButton }
          if needsLocation {
            Button {
              locationManager.onAuthorizationChange = { accessRefresh += 1 }
              locationManager.checkAuthorization()
            } label: {
              Label("Enable Location", systemImage: "location")
            }
          }
        } header: {
          Text("Access")
        } footer: {
          if needsLocation {
            Text("Location is for local weather in the widget")
          }
        }
      }
    }
    .navigationTitle("Settings")
  }
}

/// DEBUG-only launch arguments that put the app on a given screen, since
/// `simctl` cannot tap:
///
///     -watchTab calendar|reminders|timezones|weather|settings   start page
///     -openWidgetDefaults calendar|reminders|timezones|weather
///     -widgetDefaultsAnchor appearance    scroll the form to that section
///                                         (or the home list to a kind's row)
///     -widgetDefaultsSelection YES        open the kind's selection list
///     -widgetDefaultsPatch '{"fontStyle":"serif"}'   merge into that kind's
///                                         stored defaults before showing it
///     -checkWidgetDefaults YES            run the resolver self-check and log it
///
/// Launch arguments land in UserDefaults' argument domain.
enum WatchLaunchOptions {
#if DEBUG
  private static var arguments: UserDefaults { .standard }

  static var openKind: DisplayedContent? {
    arguments.string(forKey: "openWidgetDefaults").flatMap(DisplayedContent.init(rawValue:))
  }
  static var initialPath: [DisplayedContent] { openKind.map { [$0] } ?? [] }
  static var initialTab: String {
    arguments.string(forKey: "watchTab") ?? openKind?.rawValue ?? DisplayedContent.calendar.rawValue
  }
  static var scrollAnchor: String? { arguments.string(forKey: "widgetDefaultsAnchor") }
  static var opensSelection: Bool { arguments.bool(forKey: "widgetDefaultsSelection") }

  /// Runs before the first view is built.
  static func applyAtLaunch() {
    // Read from the raw arguments: the argument domain parses a value that
    // starts with "{" as a property list, not a string.
    let raw = ProcessInfo.processInfo.arguments
    if let kind = openKind,
       let flag = raw.firstIndex(of: "-widgetDefaultsPatch"), raw.indices.contains(flag + 1) {
      WidgetDefaultsSelfCheck.patch(kind, json: raw[flag + 1])
    }
    if arguments.bool(forKey: "checkWidgetDefaults") {
      let results = WidgetDefaultsSelfCheck.run()
      for result in results {
        widgetLog.notice("widget-defaults check \(result.passed ? "PASS" : "FAIL", privacy: .public): \(result.name, privacy: .public)")
      }
      let failed = results.filter { !$0.passed }.count
      widgetLog.notice("widget-defaults check total: \(results.count - failed, privacy: .public) passed, \(failed, privacy: .public) failed")
    }
  }
#else
  static let initialPath: [DisplayedContent] = []
  static let initialTab: String = DisplayedContent.calendar.rawValue
  static let scrollAnchor: String? = nil
  static let opensSelection = false
  static func applyAtLaunch() {}
#endif
}

#Preview {
  ContentView()
}
