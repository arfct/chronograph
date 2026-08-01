import Foundation

/// Plain, intent-free description of what a widget instance displays.
/// Every widget intent resolves to one of these; the timeline engine and
/// all views consume only this type.
struct WidgetConfig {
  var content: DisplayedContent = .calendar
  var features: [WidgetFeatures] = []
  var calendars: [CalendarSelectionEntity] = []
  var reminderLists: [ReminderSelectionEntity] = []
  var timezones: [TimeZoneSelectionEntity] = []
  var weatherStyle: WeatherStyle = .current
  var viewOptions: [WidgetViewOptions] = []
  var fontStyle: FontStyle = .normal
  var fontSize: FontSize = .medium
  var backgroundColor: String = ""
  var accentColor: String = ""
  var pageOffset: Int = 0
}

// Presets — replaces the static configs on ConfigurationIntent.
extension WidgetConfig {
  static let calendar = WidgetConfig(content: .calendar,
                                     features: [.allDayEvents, .timeBars, .multiDayEvents])
  static let simpleCalendar = WidgetConfig(content: .calendar, features: [.allDayEvents])
  static let combo = WidgetConfig(content: .calendar,
                                  features: [.allDayEvents, .timeBars, .multiDayEvents, .weather])
  static var appCombo: WidgetConfig {
    var config = combo
    config.accentColor = "#db4437"
    config.viewOptions = [.showColors]
    return config
  }
  static let reminders = WidgetConfig(content: .reminders)
  static let timezones = WidgetConfig(content: .timezones, timezones: [
    TimeZoneSelectionEntity(id: "America/Los_Angeles", title: "Los Angeles", subtitle: nil, color: nil),
    TimeZoneSelectionEntity(id: "America/New_York", title: "New York City", subtitle: nil, color: nil),
    TimeZoneSelectionEntity(id: "Europe/London", title: "London", subtitle: nil, color: nil),
    TimeZoneSelectionEntity(id: "Asia/Tokyo", title: "Tokyo", subtitle: nil, color: nil),
  ])
  static let weatherCurrent = WidgetConfig(content: .weather, weatherStyle: .current)
  static let weatherDaily = WidgetConfig(content: .weather, weatherStyle: .daily)
}
