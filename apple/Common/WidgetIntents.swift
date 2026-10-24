import WidgetKit
import AppIntents

struct CalendarWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Calendar"
  static var description = IntentDescription("Upcoming events as text")

  @Parameter(title: "Calendars", default: [])
  var calendars: [CalendarSelectionEntity]

  @Parameter(title: "Show", default: [.allDayEvents, .timeBars])
  var features: [WidgetFeatures]

  @Parameter(title: "View Options", default: [])
  var viewOptions: [WidgetViewOptions]

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .medium)
  var fontSize: FontSize

  @Parameter(title: "Background Color (Hex)", description: "A color like #112233. Leave empty for no background.", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent Color (Hex)", description: "A color like #DB4437. Leave empty for the default accent.", default: "")
  var accentColor: String

  @Parameter(title: "Skip Pages", description: "Pages of items to skip. Lets side-by-side widgets continue where the previous one left off.", default: 0)
  var pageOffset: Int

  static var parameterSummary: some ParameterSummary {
    Summary {
      \.$calendars
      \.$features
      \.$viewOptions
      \.$fontStyle
      \.$fontSize
      \.$backgroundColor
      \.$accentColor
      \.$pageOffset
    }
  }

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .calendar)
    config.calendars = calendars
    config.features = features
    config.viewOptions = viewOptions
    config.fontStyle = fontStyle
    config.fontSize = fontSize
    config.backgroundColor = backgroundColor
    config.accentColor = accentColor
    config.pageOffset = pageOffset
    return config
  }

  static var recommendedIntents: [(intent: CalendarWidgetIntent, description: String)] {
    let combo = CalendarWidgetIntent()
    combo.features = [.allDayEvents, .timeBars, .multiDayEvents, .weather]
    let simple = CalendarWidgetIntent()
    simple.features = [.allDayEvents]
    return [(combo, "Events - Combined"), (simple, "Events - Simple")]
  }
}

struct RemindersWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Reminders"
  static var description = IntentDescription("Incomplete reminders as text")

  @Parameter(title: "Lists", default: [])
  var reminderLists: [ReminderSelectionEntity]

  @Parameter(title: "Remove Padding", default: false)
  var fullBleed: Bool

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .medium)
  var fontSize: FontSize

  @Parameter(title: "Background Color (Hex)", description: "A color like #112233. Leave empty for no background.", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent Color (Hex)", description: "A color like #DB4437. Leave empty for the default accent.", default: "")
  var accentColor: String

  @Parameter(title: "Skip Pages", description: "Pages of items to skip. Lets side-by-side widgets continue where the previous one left off.", default: 0)
  var pageOffset: Int

  static var parameterSummary: some ParameterSummary {
    Summary {
      \.$reminderLists
      \.$fontStyle
      \.$fontSize
      \.$backgroundColor
      \.$accentColor
      \.$fullBleed
      \.$pageOffset
    }
  }

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .reminders)
    config.reminderLists = reminderLists
    config.viewOptions = fullBleed ? [.fullBleed] : []
    config.fontStyle = fontStyle
    config.fontSize = fontSize
    config.backgroundColor = backgroundColor
    config.accentColor = accentColor
    config.pageOffset = pageOffset
    return config
  }

  static var recommendedIntents: [(intent: RemindersWidgetIntent, description: String)] {
    [(RemindersWidgetIntent(), "Reminders")]
  }
}

struct TimezonesWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Time Zones"
  static var description = IntentDescription("Times across time zones")

  @Parameter(title: "Time Zones", default: [])
  var timezones: [TimeZoneSelectionEntity]

  @Parameter(title: "Remove Padding", default: false)
  var fullBleed: Bool

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .medium)
  var fontSize: FontSize

  @Parameter(title: "Background Color (Hex)", description: "A color like #112233. Leave empty for no background.", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent Color (Hex)", description: "A color like #DB4437. Leave empty for the default accent.", default: "")
  var accentColor: String

  static var parameterSummary: some ParameterSummary {
    Summary {
      \.$timezones
      \.$fontStyle
      \.$fontSize
      \.$backgroundColor
      \.$accentColor
      \.$fullBleed
    }
  }

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .timezones)
    config.timezones = timezones.isEmpty ? WidgetConfig.timezones.timezones : timezones
    config.viewOptions = fullBleed ? [.fullBleed] : []
    config.fontStyle = fontStyle
    config.fontSize = fontSize
    config.backgroundColor = backgroundColor
    config.accentColor = accentColor
    return config
  }

  static var recommendedIntents: [(intent: TimezonesWidgetIntent, description: String)] {
    [(TimezonesWidgetIntent(), "Time Zones")]
  }
}

struct WeatherWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Weather"
  static var description = IntentDescription("Forecast as text")

  @Parameter(title: "Forecast", default: .current)
  var weatherStyle: WeatherStyle

  @Parameter(title: "Use Current Location", default: true)
  var useCurrentLocation: Bool

  @Parameter(title: "Zip Code", description: "Zip or postal code to show weather for.", default: "")
  var zipCode: String

  @Parameter(title: "Remove Padding", default: false)
  var fullBleed: Bool

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .medium)
  var fontSize: FontSize

  @Parameter(title: "Background Color (Hex)", description: "A color like #112233. Leave empty for no background.", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent Color (Hex)", description: "A color like #DB4437. Leave empty for the default accent.", default: "")
  var accentColor: String

  static var parameterSummary: some ParameterSummary {
    When(\.$useCurrentLocation, .equalTo, true) {
      Summary {
        \.$weatherStyle
        \.$useCurrentLocation
        \.$fontStyle
        \.$fontSize
        \.$backgroundColor
        \.$accentColor
        \.$fullBleed
      }
    } otherwise: {
      Summary {
        \.$weatherStyle
        \.$useCurrentLocation
        \.$zipCode
        \.$fontStyle
        \.$fontSize
        \.$backgroundColor
        \.$accentColor
        \.$fullBleed
      }
    }
  }

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .weather)
    config.weatherStyle = weatherStyle
    config.weatherLocation = useCurrentLocation ? "" : zipCode.trimmingCharacters(in: .whitespaces)
    config.features = [.weather]
    config.viewOptions = fullBleed ? [.fullBleed] : []
    config.fontStyle = fontStyle
    config.fontSize = fontSize
    config.backgroundColor = backgroundColor
    config.accentColor = accentColor
    return config
  }

  static var recommendedIntents: [(intent: WeatherWidgetIntent, description: String)] {
    let current = WeatherWidgetIntent()
    let daily = WeatherWidgetIntent()
    daily.weatherStyle = .daily
    return [(current, "Weather - Today"), (daily, "Weather - This Week")]
  }
}
