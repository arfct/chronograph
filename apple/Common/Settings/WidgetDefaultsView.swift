import SwiftUI
import EventKit

// The editor for the app's per-kind widget defaults. Shared by every app
// target: the Watch app uses it today, and the iOS and Mac apps can push the
// same form. Platform checks are limited to what the watch cannot draw or
// needs styled differently.

extension DisplayedContent {
  var displayName: String {
    switch self {
    case .calendar: return "Calendar"
    case .reminders: return "Reminders"
    case .timezones: return "Time Zones"
    case .weather: return "Weather"
    }
  }

  var systemImage: String {
    switch self {
    // The same symbols as the iOS app's tabs.
    case .calendar: return "31.square"
    case .reminders: return "checkmark.circle"
    case .timezones: return "globe.americas"
    case .weather: return "cloud.sun"
    }
  }
}

/// A row naming a widget kind, for the list that leads to its form.
struct WidgetKindLabel: View {
  let kind: DisplayedContent

  var body: some View {
    Label(kind.displayName, systemImage: kind.systemImage)
  }
}

/// The default options for one widget kind, saved as they change.
struct WidgetDefaultsForm: View {
  let kind: DisplayedContent
  /// DEBUG screenshots: a section to scroll to, and whether to open the
  /// kind's selection list. Unused in normal runs.
  var scrollAnchor: String? = nil
  var opensSelection: Bool = false

  @State private var defaults: WidgetDefaults
  @State private var zipCodeDraft: String
  @State private var selectionVisible = false

  init(kind: DisplayedContent, scrollAnchor: String? = nil, opensSelection: Bool = false) {
    self.kind = kind
    self.scrollAnchor = scrollAnchor
    self.opensSelection = opensSelection
    let stored = WidgetDefaultsStore.load(kind)
    _defaults = State(initialValue: stored)
    _zipCodeDraft = State(initialValue: stored.zipCode)
  }

  var body: some View {
    ScrollViewReader { proxy in
      Form {
        Section {
          preview
        } footer: {
          Text("How App Defaults widgets look")
        }

        switch kind {
        case .calendar: calendarSections
        case .reminders: remindersSections
        case .timezones: timezonesSections
        case .weather: weatherSections
        }

        appearanceSection

        Section {
          Button("Reset to Built-in", role: .destructive) {
            defaults = .builtIn(kind)
            zipCodeDraft = ""
          }
          .disabled(defaults == .builtIn(kind))
        }
      }
      .task {
        guard let scrollAnchor else { return }
        try? await Task.sleep(nanoseconds: 400_000_000)
        proxy.scrollTo(scrollAnchor, anchor: .top)
      }
    }
    .navigationTitle(kind.displayName)
    .navigationDestination(isPresented: $selectionVisible) { selectionList }
    .onAppear {
      if opensSelection { selectionVisible = true }
    }
    .onChange(of: defaults) {
      WidgetDefaultsStore.save(defaults, for: kind)
    }
  }

  // MARK: Preview

  private var preview: some View {
    // The preview resolves the same way a widget on app defaults does, and
    // reloads when the stored defaults change.
    WidgetPreviewView(config: WidgetConfig(content: kind, useDefaults: true))
      .scrollDisabled(true)
      .frame(height: Self.previewHeight)
      .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
  }

#if os(watchOS)
  // About the height of the rectangular widget on a watch face.
  private static let previewHeight: CGFloat = 84
#else
  private static let previewHeight: CGFloat = 220
#endif

  // MARK: Kind sections

  @ViewBuilder private var calendarSections: some View {
    Section {
      selectionRow("Calendars", summary: countSummary(defaults.calendarIDs, all: "All"))
    }
    Section("Show") {
      Toggle("All-day", isOn: feature(.allDayEvents))
        .id("show")
      Toggle("Multi-day", isOn: feature(.multiDayEvents))
      Toggle("Weather", isOn: feature(.weather))
#if !os(watchOS)
      // Never drawn at watch width.
      Toggle("Time Bars", isOn: feature(.timeBars))
#endif
      Toggle("Free Time", isOn: feature(.freeTime))
    }
    Section("View Options") {
      Toggle("Show Colors", isOn: viewOption(.showColors))
      paddingToggle
    }
  }

  @ViewBuilder private var remindersSections: some View {
    Section {
      selectionRow("Lists", summary: countSummary(defaults.reminderListIDs, all: "All"))
      paddingToggle
    }
  }

  @ViewBuilder private var timezonesSections: some View {
    Section {
      selectionRow("Time Zones", summary: countSummary(defaults.timezoneIDs, all: "Built-in"))
      paddingToggle
    }
  }

  @ViewBuilder private var weatherSections: some View {
    Section {
      Picker("Forecast", selection: $defaults.weatherStyle) {
        ForEach([WeatherStyle.current, .hourly, .daily], id: \.self) { style in
          Text(WeatherStyle.caseDisplayRepresentations[style]?.title ?? "\(style.rawValue)").tag(style)
        }
      }
      .navigationLinkPickerOnWatch()
      paddingToggle
    }
    Section("Location") {
      Toggle("Use Current Location", isOn: $defaults.useCurrentLocation)
        .id("location")
      if !defaults.useCurrentLocation {
        // Draft and commit on submit, so each keystroke does not start a
        // geocode and forecast fetch.
        TextField("Zip Code", text: $zipCodeDraft)
          .onSubmit { commitZipCode() }
          .onDisappear { commitZipCode() }
#if os(iOS)
          .keyboardType(.numbersAndPunctuation)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
          .submitLabel(.done)
#endif
      }
    }
  }

  /// The watch's widget family is always edge to edge, so the option is
  /// offered only where it does something.
  @ViewBuilder private var paddingToggle: some View {
#if !os(watchOS)
    Toggle("Remove Padding", isOn: viewOption(.fullBleed))
#endif
  }

  private var appearanceSection: some View {
    Section("Appearance") {
      Picker("Font Style", selection: $defaults.fontStyle) {
        ForEach(Self.fontStyles, id: \.self) { style in
          Text(FontStyle.caseDisplayRepresentations[style]?.title ?? "\(style.rawValue)").tag(style)
        }
      }
      .navigationLinkPickerOnWatch()
      .id("appearance")

      Picker("Font Size", selection: $defaults.fontSize) {
        ForEach([FontSize.automatic] + FontSize.sizes, id: \.self) { size in
          Text(FontSize.caseDisplayRepresentations[size]?.title ?? "\(size.rawValue)").tag(size)
        }
      }
      .navigationLinkPickerOnWatch()

      colorPicker("Background", selection: $defaults.backgroundColor, presets: WidgetColorPreset.backgrounds)
      colorPicker("Accent", selection: $defaults.accentColor, presets: WidgetColorPreset.accents)
    }
  }

  private static let fontStyles: [FontStyle] = [.normal, .rounded, .serif, .monospace, .condensed, .compressed]

  // MARK: Pieces

  /// Preset swatches rather than a hex field: the value stays a hex string,
  /// so a platform with a keyboard can offer free entry over the same field.
  private func colorPicker(_ title: String, selection: Binding<String>,
                           presets: [WidgetColorPreset]) -> some View {
    Picker(title, selection: selection) {
      ForEach(WidgetColorPreset.options(presets, including: selection.wrappedValue)) { preset in
        HStack {
          Circle()
            .fill(Color.withHex(preset.hex) ?? .clear)
            .overlay(Circle().strokeBorder(.secondary, lineWidth: 1))
            .frame(width: 14, height: 14)
          Text(preset.name)
        }
        .tag(preset.hex)
      }
    }
    .navigationLinkPickerOnWatch()
  }

  private func selectionRow(_ title: String, summary: String) -> some View {
    Button {
      selectionVisible = true
    } label: {
      LabeledContent(title, value: summary)
    }
    .foregroundStyle(.primary)
  }

  @ViewBuilder private var selectionList: some View {
    switch kind {
    case .calendar:
      CalendarSelectionList(entityType: .event, selection: $defaults.calendarIDs)
        .navigationTitle("Calendars")
    case .reminders:
      CalendarSelectionList(entityType: .reminder, selection: $defaults.reminderListIDs)
        .navigationTitle("Lists")
    case .timezones:
      TimeZoneSelectionList(selection: $defaults.timezoneIDs)
        .navigationTitle("Time Zones")
    case .weather:
      EmptyView()
    }
  }

  private func countSummary(_ ids: [String], all: String) -> String {
    ids.isEmpty ? all : "\(ids.count)"
  }

  private func commitZipCode() {
    defaults.zipCode = zipCodeDraft.trimmingCharacters(in: .whitespaces)
  }

  /// Members are kept in declaration order so the stored list does not depend
  /// on the order toggles were flipped in.
  private func feature(_ member: WidgetFeatures) -> Binding<Bool> {
    let order: [WidgetFeatures] = [.allDayEvents, .multiDayEvents, .weather, .timeBars, .freeTime]
    return Binding(
      get: { defaults.features.contains(member) },
      set: { isOn in
        let members = defaults.features.filter { $0 != member } + (isOn ? [member] : [])
        defaults.features = order.filter(members.contains)
      })
  }

  private func viewOption(_ member: WidgetViewOptions) -> Binding<Bool> {
    let order: [WidgetViewOptions] = [.showColors, .fullBleed]
    return Binding(
      get: { defaults.viewOptions.contains(member) },
      set: { isOn in
        let members = defaults.viewOptions.filter { $0 != member } + (isOn ? [member] : [])
        defaults.viewOptions = order.filter(members.contains)
      })
  }
}

private extension View {
  /// A wheel picker has no height inside a watch form; a row that pushes its
  /// options sizes itself. Other platforms keep their default style.
  @ViewBuilder func navigationLinkPickerOnWatch() -> some View {
#if os(watchOS)
    pickerStyle(.navigationLink)
#else
    self
#endif
  }
}

// MARK: Calendars and reminder lists

/// Calendars or reminder lists grouped by account, in a selection where empty
/// means all (the timeline engine's rule).
struct CalendarSelectionList: View {
  let entityType: EKEntityType
  @Binding var selection: [String]
  @State private var calendars: [EKCalendar] = []
  @State private var loaded = false

  private var sources: [(title: String, calendars: [EKCalendar])] {
    Dictionary(grouping: calendars, by: { $0.source.title })
      .sorted { $0.key < $1.key }
      .map { (title: $0.key, calendars: $0.value.sorted { $0.title < $1.title }) }
  }

  var body: some View {
    List {
      if loaded && calendars.isEmpty {
        Text(entityType == .event ? "No calendars. Check calendar access." : "No lists. Check reminders access.")
          .foregroundStyle(.secondary)
      }
      ForEach(sources, id: \.title) { source in
        Section(source.title) {
          ForEach(source.calendars, id: \.calendarIdentifier) { calendar in
            Button {
              selection = toggledSelection(selection,
                                           id: calendar.calendarIdentifier,
                                           allIds: calendars.map(\.calendarIdentifier))
            } label: {
              HStack {
                Circle()
                  .fill(Color(cgColor: calendar.cgColor))
                  .frame(width: 12, height: 12)
                Text(calendar.title)
                Spacer()
                if selection.isEmpty || selection.contains(calendar.calendarIdentifier) {
                  Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                }
              }
            }
            .foregroundStyle(.primary)
          }
        }
      }
    }
    .onAppear {
      calendars = EKEventStore().calendars(for: entityType)
      loaded = true
    }
  }
}

// MARK: Time zones

/// Chosen zones first, then every known zone by region. A flat list of some
/// 400 zones is too long to scroll on a watch, so regions push their cities.
struct TimeZoneSelectionList: View {
  @Binding var selection: [String]

  static let regions: [String: [String]] = Dictionary(
    grouping: TimeZone.knownTimeZoneIdentifiers.filter { $0.contains("/") },
    by: { $0.components(separatedBy: "/").first ?? "" })

  static func cityName(_ identifier: String) -> String {
    let name = identifier.components(separatedBy: "/").dropFirst()
      .joined(separator: "/").replacingOccurrences(of: "_", with: " ")
    return name.isEmpty ? identifier : name
  }

  var body: some View {
    List {
      Section {
        if selection.isEmpty {
          Text(WidgetConfig.timezones.timezones.map(\.title).joined(separator: ", "))
            .foregroundStyle(.secondary)
        } else {
          ForEach(selection, id: \.self) { identifier in
            Button {
              selection.removeAll { $0 == identifier }
            } label: {
              HStack {
                Text(Self.cityName(identifier))
                Spacer()
                Image(systemName: "checkmark").foregroundStyle(.tint)
              }
            }
            .foregroundStyle(.primary)
          }
          Button("Use Built-in", role: .destructive) { selection = [] }
        }
      } header: {
        Text(selection.isEmpty ? "Built-in" : "Selected")
      }

      Section("Regions") {
        ForEach(Self.regions.keys.sorted(), id: \.self) { region in
          NavigationLink(region) {
            TimeZoneRegionList(identifiers: Self.regions[region] ?? [], selection: $selection)
              .navigationTitle(region)
          }
        }
      }
    }
  }
}

private struct TimeZoneRegionList: View {
  let identifiers: [String]
  @Binding var selection: [String]

  var body: some View {
    List(identifiers, id: \.self) { identifier in
      Button {
        if selection.contains(identifier) {
          selection.removeAll { $0 == identifier }
        } else {
          selection.append(identifier)
        }
      } label: {
        HStack {
          Text(TimeZoneSelectionList.cityName(identifier))
          Spacer()
          if selection.contains(identifier) {
            Image(systemName: "checkmark").foregroundStyle(.tint)
          }
        }
      }
      .foregroundStyle(.primary)
    }
  }
}
