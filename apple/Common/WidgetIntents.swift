import WidgetKit
import AppIntents

struct CalendarWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Calendar"
  static var description = IntentDescription("Upcoming events as text")

  @Parameter(title: "Use App Defaults", description: "Use the options set for this widget type in the Chronograph app. Turn off to set this widget's own options.", default: false)
  var useDefaults: Bool

  @Parameter(title: "Calendars", default: [])
  var calendars: [CalendarSelectionEntity]

  @Parameter(title: "Show", default: [.allDayEvents, .timeBars])
  var features: [WidgetFeatures]

  @Parameter(title: "View Options", default: [])
  var viewOptions: [WidgetViewOptions]

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .automatic)
  var fontSize: FontSize

  @Parameter(title: "Background Color (Hex)", description: "A color like #112233, or #11223380 to make it translucent. Leave empty for the system glass background.", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent Color (Hex)", description: "A color like #DB4437, or #DB443780 to make it translucent. Leave empty for the default accent.", default: "")
  var accentColor: String

  @Parameter(title: "Skip Pages", description: "Pages of items to skip. Lets side-by-side widgets continue where the previous one left off.", default: 0)
  var pageOffset: Int

  // The toggle comes first; a widget's own options appear only when it is off.
  static var parameterSummary: some ParameterSummary {
    When(\.$useDefaults, .equalTo, false) {
      Summary {
        \.$useDefaults
        \.$calendars
        \.$features
        \.$viewOptions
        \.$fontStyle
        \.$fontSize
        \.$backgroundColor
        \.$accentColor
        \.$pageOffset
      }
    } otherwise: {
      Summary {
        \.$useDefaults
      }
    }
  }

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .calendar)
    config.calendars = calendars
    config.features = features
    config.viewOptions = viewOptions
    config.useDefaults = useDefaults
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
    let defaults = CalendarWidgetIntent()
    defaults.useDefaults = true
    return [(combo, "Events - Combined"), (simple, "Events - Simple"),
            (defaults, "Events - App Defaults")]
  }
}

struct RemindersWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Reminders"
  static var description = IntentDescription("Incomplete reminders as text")

  @Parameter(title: "Use App Defaults", description: "Use the options set for this widget type in the Chronograph app. Turn off to set this widget's own options.", default: false)
  var useDefaults: Bool

  @Parameter(title: "Lists", default: [])
  var reminderLists: [ReminderSelectionEntity]

  @Parameter(title: "Remove Padding", default: false)
  var fullBleed: Bool

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .automatic)
  var fontSize: FontSize

  @Parameter(title: "Background Color (Hex)", description: "A color like #112233, or #11223380 to make it translucent. Leave empty for the system glass background.", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent Color (Hex)", description: "A color like #DB4437, or #DB443780 to make it translucent. Leave empty for the default accent.", default: "")
  var accentColor: String

  @Parameter(title: "Skip Pages", description: "Pages of items to skip. Lets side-by-side widgets continue where the previous one left off.", default: 0)
  var pageOffset: Int

  // The toggle comes first; a widget's own options appear only when it is off.
  static var parameterSummary: some ParameterSummary {
    When(\.$useDefaults, .equalTo, false) {
      Summary {
        \.$useDefaults
        \.$reminderLists
        \.$fontStyle
        \.$fontSize
        \.$backgroundColor
        \.$accentColor
        \.$fullBleed
        \.$pageOffset
      }
    } otherwise: {
      Summary {
        \.$useDefaults
      }
    }
  }

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .reminders)
    config.reminderLists = reminderLists
    config.viewOptions = fullBleed ? [.fullBleed] : []
    config.useDefaults = useDefaults
    config.fontStyle = fontStyle
    config.fontSize = fontSize
    config.backgroundColor = backgroundColor
    config.accentColor = accentColor
    config.pageOffset = pageOffset
    return config
  }

  static var recommendedIntents: [(intent: RemindersWidgetIntent, description: String)] {
    let defaults = RemindersWidgetIntent()
    defaults.useDefaults = true
    return [(RemindersWidgetIntent(), "Reminders"), (defaults, "Reminders - App Defaults")]
  }
}

struct TimezonesWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Time Zones"
  static var description = IntentDescription("Times across time zones")

  @Parameter(title: "Use App Defaults", description: "Use the options set for this widget type in the Chronograph app. Turn off to set this widget's own options.", default: false)
  var useDefaults: Bool

  @Parameter(title: "Time Zones", default: [])
  var timezones: [TimeZoneSelectionEntity]

  @Parameter(title: "Remove Padding", default: false)
  var fullBleed: Bool

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .automatic)
  var fontSize: FontSize

  @Parameter(title: "Background Color (Hex)", description: "A color like #112233, or #11223380 to make it translucent. Leave empty for the system glass background.", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent Color (Hex)", description: "A color like #DB4437, or #DB443780 to make it translucent. Leave empty for the default accent.", default: "")
  var accentColor: String

  // The toggle comes first; a widget's own options appear only when it is off.
  static var parameterSummary: some ParameterSummary {
    When(\.$useDefaults, .equalTo, false) {
      Summary {
        \.$useDefaults
        \.$timezones
        \.$fontStyle
        \.$fontSize
        \.$backgroundColor
        \.$accentColor
        \.$fullBleed
      }
    } otherwise: {
      Summary {
        \.$useDefaults
      }
    }
  }

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .timezones)
    config.timezones = timezones.isEmpty ? WidgetConfig.timezones.timezones : timezones
    config.viewOptions = fullBleed ? [.fullBleed] : []
    config.useDefaults = useDefaults
    config.fontStyle = fontStyle
    config.fontSize = fontSize
    config.backgroundColor = backgroundColor
    config.accentColor = accentColor
    return config
  }

  static var recommendedIntents: [(intent: TimezonesWidgetIntent, description: String)] {
    let defaults = TimezonesWidgetIntent()
    defaults.useDefaults = true
    return [(TimezonesWidgetIntent(), "Time Zones"), (defaults, "Time Zones - App Defaults")]
  }
}

struct WeatherWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Weather"
  static var description = IntentDescription("Forecast as text")

  @Parameter(title: "Use App Defaults", description: "Use the options set for this widget type in the Chronograph app. Turn off to set this widget's own options.", default: false)
  var useDefaults: Bool

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

  @Parameter(title: "Font Size", default: .automatic)
  var fontSize: FontSize

  @Parameter(title: "Background Color (Hex)", description: "A color like #112233, or #11223380 to make it translucent. Leave empty for the system glass background.", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent Color (Hex)", description: "A color like #DB4437, or #DB443780 to make it translucent. Leave empty for the default accent.", default: "")
  var accentColor: String

  // The toggle comes first; a widget's own options appear only when it is off.
  static var parameterSummary: some ParameterSummary {
    When(\.$useDefaults, .equalTo, false) {
      When(\.$useCurrentLocation, .equalTo, true) {
        Summary {
          \.$useDefaults
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
          \.$useDefaults
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
    } otherwise: {
      Summary {
        \.$useDefaults
      }
    }
  }

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .weather)
    config.weatherStyle = weatherStyle
    config.weatherLocation = useCurrentLocation ? "" : zipCode.trimmingCharacters(in: .whitespaces)
    config.features = [.weather]
    config.viewOptions = fullBleed ? [.fullBleed] : []
    config.useDefaults = useDefaults
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
    let defaults = WeatherWidgetIntent()
    defaults.useDefaults = true
    return [(current, "Weather - Today"), (daily, "Weather - This Week"),
            (defaults, "Weather - App Defaults")]
  }
}
