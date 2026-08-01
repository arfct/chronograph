struct Keys {
  #if os(macOS)
  
  static let suiteName = "TVA9Z8LD95.com.artifact.chronograph"
  #else
  static let suiteName = "group.com.artifact.chronograph"
  #endif

  static let tokenizeParens = "tokenizeParens"
  static let compactTime = "compactTime"
  static let brailleMode = "brailleMode"
  static let hideIntroduction = "hideIntroduction"

  static let fullBleed = "fullBleed"
  static let selectedTab = "selectedTab"
  
  static let enabledCalendars = "enabledCalendars"
  static let enabledReminders = "enabledReminders"
  static let favoriteTimezones = "favoriteTimezones"

  // Weather
  static let weatherUseCurrentLocation = "weatherUseCurrentLocation"
  static let weatherZipCode = "weatherZipCode"
  static let cachedWeatherPrefix = "cachedWeather."
  static let geocodedZipPrefix = "geocodedZip."
  static let lastKnownLocation = "lastKnownLocation"
  
}

struct Values {
  static let infoTab = "info"
  static let settingsTab = "settings"
  static let calendarTab = "calendar"
  static let reminderTab = "reminder"
  static let timezoneTab = "timezone"
  static let weatherTab = "weather"
  
}
struct Defaults {
  //  static let serverAddress = ""
}
