struct Keys {
  #if os(macOS)
  
  static let suiteName = "A7X888RRVJ.chronograph.page"
  #else
  static let suiteName = "group.page.chronograph"
  #endif

  static let tokenizeParens = "tokenizeParens"
  static let compactTime = "compactTime"
  static let hideIntroduction = "hideIntroduction"

  static let fullBleed = "fullBleed"
  
  
  static let selectedTab = "selectedTab"
}

struct Values {
  static let infoTab = "info"
  static let calendarTab = "calendar"
  static let reminderTab = "reminder"
  static let timezoneTab = "timezone"
  static let weatherTab = "weather"
  
}
struct Defaults {
  //  static let serverAddress = ""
}
