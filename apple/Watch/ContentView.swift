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

  var body: some View {
    let _ = accessRefresh
    let needsCalendar = EKEventStore.authorizationStatus(for: .event) != .fullAccess
    let needsReminders = EKEventStore.authorizationStatus(for: .reminder) != .fullAccess
    let needsLocation = !locationManager.isAuthorized

    NavigationStack(path: $path) {
      ScrollViewReader { proxy in
      List {
        Section {
          Image("Wordmark")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.trailing, 50)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
        }

        // Each kind opens the defaults that widgets set to "App Defaults" use.
        Section {
          ForEach(WidgetDefaultsStore.kinds, id: \.self) { kind in
            NavigationLink(value: kind) {
              WidgetKindLabel(kind: kind)
            }
            .id(kind.rawValue)
          }
        } header: {
          Text("Widget Defaults")
        } footer: {
          Text("Used by widgets added as App Defaults")
        }

        Section("Display") {
          DefaultFontSizePicker()
            .pickerStyle(.navigationLink)
            .id("display")
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
            if needsCalendar {
              Button {
                Task {
                  _ = try? await eventStore.requestFullAccessToEvents()
                  accessRefresh += 1
                }
              } label: {
                Label("Enable Calendar Access", systemImage: "lock")
              }
            }
            if needsReminders {
              Button {
                Task {
                  _ = try? await eventStore.requestFullAccessToReminders()
                  accessRefresh += 1
                }
              } label: {
                Label("Enable Reminders Access", systemImage: "lock")
              }
            }
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

        Section {
        } footer: {
          Text("A large widget for the modular watch face")
        }
      }
      .task {
        // DEBUG screenshots only: scroll the home list to a row.
        guard path.isEmpty, let anchor = WatchLaunchOptions.scrollAnchor else { return }
        try? await Task.sleep(nanoseconds: 400_000_000)
        proxy.scrollTo(anchor, anchor: .bottom)
      }
      }
      .navigationDestination(for: DisplayedContent.self) { kind in
        WidgetDefaultsForm(kind: kind,
                           scrollAnchor: WatchLaunchOptions.scrollAnchor,
                           opensSelection: WatchLaunchOptions.opensSelection)
      }
    }
  }
}

/// DEBUG-only launch arguments that put the app on a given screen, since
/// `simctl` cannot tap:
///
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
  static let scrollAnchor: String? = nil
  static let opensSelection = false
  static func applyAtLaunch() {}
#endif
}

#Preview {
  ContentView()
}
