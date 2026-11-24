import Foundation
#if os(macOS)
import Security
#endif

struct Keys {
  #if os(macOS)
  /// macOS app groups are prefixed with the signing team, so ask the running
  /// binary which group it was actually signed into rather than repeating a
  /// team ID here. The literal only covers unsigned builds (previews, CI).
  static let suiteName: String = {
    let fallback = "TVA9Z8LD95.com.artifact.chronograph"
    guard let task = SecTaskCreateFromSelf(nil),
          let value = SecTaskCopyValueForEntitlement(
            task, "com.apple.security.application-groups" as CFString, nil),
          let groups = value as? [String],
          let group = groups.first(where: { $0.hasSuffix(".com.artifact.chronograph") })
    else { return fallback }
    return group
  }()
  #else
  static let suiteName = "group.com.artifact.chronograph"
  #endif

  static let tokenizeParens = "tokenizeParens"
  static let compactTime = "compactTime"
  static let brailleMode = "brailleMode"  // legacy toggle; migrated to obfuscation
  static let obfuscation = "obfuscation"
  static let hideIntroduction = "hideIntroduction"
  static let defaultFontSize = "defaultFontSize"
  /// Prefix for the per-kind widget defaults, e.g. `widgetDefaults.calendar`.
  static let widgetDefaultsPrefix = "widgetDefaults."

  static let fullBleed = "fullBleed"
  static let selectedTab = "selectedTab"
  /// The Watch app's last visible page, kept in the app's own defaults.
  static let watchSelectedPage = "watchSelectedPage"
  
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

/// `chronograph://page/<kind>`: the Watch app page a widget tap opens.
enum WatchPageLink {
  static let scheme = "chronograph"

  static func url(for kind: DisplayedContent) -> URL? {
    URL(string: "\(scheme)://page/\(kind.rawValue)")
  }

  static func kind(from url: URL) -> DisplayedContent? {
    guard url.scheme == scheme, url.host() == "page" else { return nil }
    return DisplayedContent(rawValue: url.lastPathComponent)
  }
}
