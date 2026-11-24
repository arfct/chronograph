import Foundation
import WidgetKit

/// The app's default options for one widget kind. A widget whose
/// "Use App Defaults" is on takes every option from here; see
/// docs/plans/2026-11-20-in-app-widget-defaults.md.
///
/// One type serves all four kinds: the appearance fields are common, and a
/// kind ignores the fields it has no control for.
struct WidgetDefaults: Equatable {
  /// Empty means every calendar.
  var calendarIDs: [String] = []
  /// Empty means every reminder list.
  var reminderListIDs: [String] = []
  /// Empty means the built-in cities in `WidgetConfig.timezones`.
  var timezoneIDs: [String] = []
  var features: [WidgetFeatures] = []
  var viewOptions: [WidgetViewOptions] = []
  var weatherStyle: WeatherStyle = .current
  var useCurrentLocation: Bool = true
  var zipCode: String = ""
  var fontStyle: FontStyle = .normal
  /// `.automatic` follows the app-wide Default Size.
  var fontSize: FontSize = .automatic
  /// Hex strings as the widget parameters take them; empty is the system look.
  var backgroundColor: String = ""
  var accentColor: String = ""

  /// What a widget of `kind` shows with nothing stored. These match the
  /// `@Parameter` defaults in WidgetIntents.swift; the DEBUG self-check below
  /// fails if they drift apart.
  static func builtIn(_ kind: DisplayedContent) -> WidgetDefaults {
    var defaults = WidgetDefaults()
    if kind == .calendar {
      defaults.features = [.allDayEvents, .timeBars]
    }
    return defaults
  }
}

// MARK: Codable

extension WidgetDefaults: Codable {
  /// Set in `decoder.userInfo` so fields missing from stored JSON fall back to
  /// the right kind's built-in values.
  static let kindKey = CodingUserInfoKey(rawValue: "widgetDefaultsKind")!

  private enum CodingKeys: String, CodingKey {
    case calendarIDs, reminderListIDs, timezoneIDs, features, viewOptions
    case weatherStyle, useCurrentLocation, zipCode
    case fontStyle, fontSize, backgroundColor, accentColor
  }

  /// Each field is read on its own: one that is missing, of the wrong type or
  /// an unknown case keeps the built-in value instead of failing the decode,
  /// so a later version can add or drop fields without losing what is stored.
  init(from decoder: Decoder) throws {
    let kind = decoder.userInfo[Self.kindKey] as? DisplayedContent ?? .calendar
    self = .builtIn(kind)
    guard let values = try? decoder.container(keyedBy: CodingKeys.self) else { return }

    func read<T: Decodable>(_ key: CodingKeys) -> T? {
      (try? values.decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    if let ids: [String] = read(.calendarIDs) { calendarIDs = ids }
    if let ids: [String] = read(.reminderListIDs) { reminderListIDs = ids }
    if let ids: [String] = read(.timezoneIDs) { timezoneIDs = ids }
    if let raw: [String] = read(.features) { features = raw.compactMap(WidgetFeatures.init(rawValue:)) }
    if let raw: [String] = read(.viewOptions) { viewOptions = raw.compactMap(WidgetViewOptions.init(rawValue:)) }
    if let raw: String = read(.weatherStyle), let style = WeatherStyle(rawValue: raw) { weatherStyle = style }
    if let flag: Bool = read(.useCurrentLocation) { useCurrentLocation = flag }
    if let text: String = read(.zipCode) { zipCode = text }
    if let raw: String = read(.fontStyle), let style = FontStyle(rawValue: raw) { fontStyle = style }
    if let raw: String = read(.fontSize), let size = FontSize(rawValue: raw) { fontSize = size }
    if let text: String = read(.backgroundColor) { backgroundColor = text }
    if let text: String = read(.accentColor) { accentColor = text }
  }

  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(calendarIDs, forKey: .calendarIDs)
    try values.encode(reminderListIDs, forKey: .reminderListIDs)
    try values.encode(timezoneIDs, forKey: .timezoneIDs)
    try values.encode(features.map(\.rawValue), forKey: .features)
    try values.encode(viewOptions.map(\.rawValue), forKey: .viewOptions)
    try values.encode(weatherStyle.rawValue, forKey: .weatherStyle)
    try values.encode(useCurrentLocation, forKey: .useCurrentLocation)
    try values.encode(zipCode, forKey: .zipCode)
    try values.encode(fontStyle.rawValue, forKey: .fontStyle)
    try values.encode(fontSize.rawValue, forKey: .fontSize)
    try values.encode(backgroundColor, forKey: .backgroundColor)
    try values.encode(accentColor, forKey: .accentColor)
  }
}

// MARK: Store

/// Reads and writes the per-kind defaults in the App Group suite, which the
/// app and its widget extension share on one device. iPhone and Watch each
/// have their own.
enum WidgetDefaultsStore {
  /// The kinds that have defaults, in display order. A kind's raw value is
  /// also its WidgetKit kind string.
  static let kinds: [DisplayedContent] = [.calendar, .reminders, .timezones, .weather]

  static var suite: UserDefaults? { UserDefaults(suiteName: Keys.suiteName) }

  static func key(_ kind: DisplayedContent) -> String {
    Keys.widgetDefaultsPrefix + kind.rawValue
  }

  static func decode(_ json: String, kind: DisplayedContent) -> WidgetDefaults {
    let decoder = JSONDecoder()
    decoder.userInfo[WidgetDefaults.kindKey] = kind
    guard let data = json.data(using: .utf8),
          let defaults = try? decoder.decode(WidgetDefaults.self, from: data)
    else { return .builtIn(kind) }
    return defaults
  }

  static func encode(_ defaults: WidgetDefaults) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(defaults),
          let json = String(data: data, encoding: .utf8)
    else { return "{}" }
    return json
  }

  static func load(_ kind: DisplayedContent, from store: UserDefaults? = suite) -> WidgetDefaults {
    guard let json = store?.string(forKey: key(kind)) else { return .builtIn(kind) }
    return decode(json, kind: kind)
  }

  /// Stores `defaults` and asks WidgetKit to rebuild that kind's widgets.
  static func save(_ defaults: WidgetDefaults, for kind: DisplayedContent, to store: UserDefaults? = suite) {
    store?.set(encode(defaults), forKey: key(kind))
    WidgetCenter.shared.reloadTimelines(ofKind: kind.rawValue)
  }

  /// Back to the built-in values.
  static func reset(_ kind: DisplayedContent, in store: UserDefaults? = suite) {
    store?.removeObject(forKey: key(kind))
    WidgetCenter.shared.reloadTimelines(ofKind: kind.rawValue)
  }
}

// MARK: Resolver

extension WidgetConfig {
  /// This config with `useDefaults` applied: unchanged when it is off;
  /// otherwise every option taken from `defaults`.
  func resolved(with defaults: WidgetDefaults) -> WidgetConfig {
    guard useDefaults else { return self }

    // Start from an empty config so nothing of the widget's own leaks
    // through. Skip Pages is per widget by nature and goes back to 0.
    var config = WidgetConfig(content: content)

    switch content {
    case .calendar:
      config.features = defaults.features
      config.viewOptions = defaults.viewOptions
      config.calendars = defaults.calendarIDs.map {
        CalendarSelectionEntity(id: $0, title: "", subtitle: nil, color: nil)
      }
    case .reminders:
      config.reminderLists = defaults.reminderListIDs.map {
        ReminderSelectionEntity(id: $0, title: "")
      }
    case .timezones:
      let zones = defaults.timezoneIDs.compactMap { TimeZone(identifier: $0) }
      config.timezones = zones.isEmpty
        ? WidgetConfig.timezones.timezones
        : zones.map { TimeZoneSelectionEntity.with(timeZone: $0) }
    case .weather:
      config.features = [.weather]
      config.weatherStyle = defaults.weatherStyle
      config.weatherLocation = defaults.useCurrentLocation
        ? "" : defaults.zipCode.trimmingCharacters(in: .whitespaces)
    }

    // Only Calendar has a View Options list; the others have Remove Padding.
    if content != .calendar {
      config.viewOptions = defaults.viewOptions.filter { $0 == .fullBleed }
    }
    config.fontStyle = defaults.fontStyle
    config.fontSize = defaults.fontSize
    config.backgroundColor = defaults.backgroundColor
    config.accentColor = defaults.accentColor
    return config
  }

  /// `resolved(with:)` against what the app has stored for this kind.
  func resolved() -> WidgetConfig {
    useDefaults ? resolved(with: WidgetDefaultsStore.load(content)) : self
  }
}

// MARK: Colour presets

/// A named colour for pickers where typing a hex value is impractical.
struct WidgetColorPreset: Identifiable, Hashable {
  let name: String
  let hex: String
  var id: String { hex }

  static let backgrounds: [WidgetColorPreset] = [
    .init(name: "System", hex: ""),
    .init(name: "Black", hex: "#000000"),
    .init(name: "Graphite", hex: "#1C1C1E"),
    .init(name: "Navy", hex: "#112233"),
    .init(name: "Forest", hex: "#12261C"),
    .init(name: "Plum", hex: "#2A1830"),
    .init(name: "Paper", hex: "#F4F1EA"),
    .init(name: "White", hex: "#FFFFFF"),
  ]

  static let accents: [WidgetColorPreset] = [
    .init(name: "Default", hex: ""),
    .init(name: "Red", hex: "#DB4437"),
    .init(name: "Orange", hex: "#FF9500"),
    .init(name: "Yellow", hex: "#FFCC00"),
    .init(name: "Green", hex: "#34C759"),
    .init(name: "Teal", hex: "#30B0C7"),
    .init(name: "Blue", hex: "#0A84FF"),
    .init(name: "Purple", hex: "#BF5AF2"),
    .init(name: "Pink", hex: "#FF2D55"),
  ]

  /// `presets`, plus a "Custom" entry when `current` is not one of them, so a
  /// value set elsewhere is shown and kept rather than replaced.
  static func options(_ presets: [WidgetColorPreset], including current: String) -> [WidgetColorPreset] {
    presets.contains { $0.hex == current }
      ? presets
      : presets + [WidgetColorPreset(name: "Custom", hex: current)]
  }
}

// MARK: Self-check

#if DEBUG
/// The project has no test target, so the resolver's rules are checked here.
/// Run it with the `-checkWidgetDefaults YES` launch argument; see
/// ChronographWatchApp.
enum WidgetDefaultsSelfCheck {
  /// Every option a view or the engine reads, as one comparable line.
  static func signature(_ config: WidgetConfig) -> String {
    [
      "content=\(config.content.rawValue)",
      "features=\(config.features.map(\.rawValue).joined(separator: ","))",
      "calendars=\(config.calendars.map(\.id).joined(separator: ","))",
      "lists=\(config.reminderLists.map(\.id).joined(separator: ","))",
      "zones=\(config.timezones.map(\.id).joined(separator: ","))",
      "weather=\(config.weatherStyle.rawValue)@\(config.weatherLocation)",
      "view=\(config.viewOptions.map(\.rawValue).joined(separator: ","))",
      "font=\(config.fontStyle.rawValue)/\(config.fontSize.rawValue)",
      "bg=\(config.backgroundColor) accent=\(config.accentColor)",
      "page=\(config.pageOffset)",
    ].joined(separator: " ")
  }

  static func run() -> [(name: String, passed: Bool)] {
    var results: [(name: String, passed: Bool)] = []
    func check(_ name: String, _ passed: Bool) { results.append((name, passed)) }

    var stored = WidgetDefaults.builtIn(.calendar)
    stored.calendarIDs = ["cal-1"]
    stored.reminderListIDs = ["list-1"]
    stored.timezoneIDs = ["Europe/Paris", "not/a-zone"]
    stored.features = [.allDayEvents, .freeTime]
    stored.viewOptions = [.showColors, .fullBleed]
    stored.weatherStyle = .daily
    stored.useCurrentLocation = false
    stored.zipCode = " 94110 "
    stored.fontStyle = .serif
    stored.fontSize = .large
    stored.backgroundColor = "#112233"
    stored.accentColor = "#FF9500"

    // Toggle off: the widget's own values, whatever the app has stored.
    var own = WidgetConfig.appCombo
    own.fontStyle = .rounded
    own.pageOffset = 2
    check("off: config is untouched", signature(own.resolved(with: stored)) == signature(own))

    // Toggle on, nothing stored: the same as a freshly added widget, per kind.
    let fresh: [(DisplayedContent, WidgetConfig)] = [
      (.calendar, CalendarWidgetIntent().widgetConfig),
      (.reminders, RemindersWidgetIntent().widgetConfig),
      (.timezones, TimezonesWidgetIntent().widgetConfig),
      (.weather, WeatherWidgetIntent().widgetConfig),
    ]
    for (kind, intentConfig) in fresh {
      let resolved = WidgetConfig(content: kind, useDefaults: true).resolved(with: .builtIn(kind))
      check("on, nothing stored: \(kind.rawValue) equals the intent's built-in defaults",
            signature(resolved) == signature(intentConfig))
      check("on: \(kind.rawValue) leaves the toggle resolved", !resolved.useDefaults)
    }

    // Toggle on: every stored field is used, and the widget's own are dropped.
    var customized = WidgetConfig(content: .calendar, useDefaults: true)
    customized.features = [.timeBars]
    customized.fontStyle = .monospace
    customized.accentColor = "#000000"
    customized.pageOffset = 3
    let calendar = customized.resolved(with: stored)
    check("on: calendar takes stored Show", calendar.features == [.allDayEvents, .freeTime])
    check("on: calendar takes stored View Options", calendar.viewOptions == [.showColors, .fullBleed])
    check("on: calendar takes stored calendars", calendar.calendars.map(\.id) == ["cal-1"])
    check("on: takes stored font style and size", calendar.fontStyle == .serif && calendar.fontSize == .large)
    check("on: takes stored colours",
          calendar.backgroundColor == "#112233" && calendar.accentColor == "#FF9500")
    check("on: Skip Pages goes back to 0", calendar.pageOffset == 0)

    let reminders = WidgetConfig(content: .reminders, useDefaults: true).resolved(with: stored)
    check("on: reminders takes stored lists", reminders.reminderLists.map(\.id) == ["list-1"])
    check("on: reminders keeps only Remove Padding from View Options", reminders.viewOptions == [.fullBleed])
    check("on: reminders has no calendar features", reminders.features.isEmpty)

    let zones = WidgetConfig(content: .timezones, useDefaults: true).resolved(with: stored)
    check("on: time zones takes stored zones, skipping unknown ids", zones.timezones.map(\.id) == ["Europe/Paris"])

    let weather = WidgetConfig(content: .weather, useDefaults: true).resolved(with: stored)
    check("on: weather takes stored forecast", weather.weatherStyle == .daily)
    check("on: weather takes the trimmed zip code", weather.weatherLocation == "94110")
    check("on: weather keeps its weather feature", weather.features == [.weather])
    var here = stored
    here.useCurrentLocation = true
    check("on: current location ignores a stored zip code",
          WidgetConfig(content: .weather, useDefaults: true).resolved(with: here).weatherLocation.isEmpty)

    // Font Size "Default" is not resolved here; the view maps it to the
    // app-wide Default Size.
    check("on: Font Size Default passes through",
          WidgetConfig(content: .reminders, useDefaults: true)
            .resolved(with: .builtIn(.reminders)).fontSize == .automatic)

    // Storage.
    check("json: round trip", WidgetDefaultsStore.decode(WidgetDefaultsStore.encode(stored), kind: .calendar) == stored)
    let partial = WidgetDefaultsStore.decode(
      #"{"fontStyle":"serif","someFutureField":1,"fontSize":"enormous","zipCode":7}"#, kind: .calendar)
    var expected = WidgetDefaults.builtIn(.calendar)
    expected.fontStyle = .serif
    check("json: missing, unknown and invalid fields keep built-in values", partial == expected)
    check("json: garbage is the built-in defaults",
          WidgetDefaultsStore.decode("not json", kind: .weather) == .builtIn(.weather))

    return results
  }

  /// Merges a JSON object into what is stored for `kind`, through the same
  /// `save` the editor uses. For screenshots (`-widgetDefaultsPatch`).
  static func patch(_ kind: DisplayedContent, json: String) {
    let current = WidgetDefaultsStore.encode(WidgetDefaultsStore.load(kind))
    guard let base = try? JSONSerialization.jsonObject(with: Data(current.utf8)) as? [String: Any],
          let changes = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
          let merged = try? JSONSerialization.data(withJSONObject: base.merging(changes) { $1 }),
          let text = String(data: merged, encoding: .utf8)
    else { return }
    WidgetDefaultsStore.save(WidgetDefaultsStore.decode(text, kind: kind), for: kind)
  }
}
#endif
