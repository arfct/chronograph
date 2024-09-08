import EventKit
import WeatherKit

struct EventAttachment: Hashable {
  static let typeImageMappings = [
    "paper.dropbox.com": "document",
    "docs.google.com": "document",
    "slack.com": "bubble"
  ]
  var urlString: String
  var type: String?
  var title: String?
  var prefix: String?
  init(url: String, title: String? = nil, prefix: String? = nil) {
    self.urlString = url
    
    self.title = title ?? extractTitleFromURL(from: url)
    if title?.starts(with: "https") ?? false {
      
      self.title = extractTitleFromURL(from: url)
    }
    
    self.prefix = prefix
    self.type = URL(string:url)?.host()
  }
  
  var url: URL? {
    URL(string: urlString)
  }
  
  var displayName: String {
    return title ?? url?.host() ?? urlString
  }
  
  var displayIcon: String {
    return EventAttachment.typeImageMappings[type ?? "link"] ?? "link"
  }
}

class EventEntry: Identifiable, Hashable {
  internal init(id: String = UUID().uuidString, type: String? = nil, title: String? = nil, startDate: Date? = nil, endDate: Date? = nil, url: URL? = nil, suffix: String? = nil, item: EKCalendarItem? = nil, allDayItems: [EventEntry]? = nil, children: [EventEntry]? = nil, duplicates: [EventEntry]? = nil, forecast: HourWeather? = nil, removeIfOrphaned: Bool = false, height: CGFloat = 1, locations: [String]? = nil, meeting: EventAttachment? = nil, notes: AttributedString? = nil, attachments: [EventAttachment]? = nil, currentForecast: CurrentWeather? = nil, dayForecast: DayWeather? = nil, hourForecast: HourWeather? = nil, date: Date? = nil, hasConflict: Bool = false, hasStartConflict: Bool = false, isFirstConflict: Bool = false, timeZone: TimeZone? = nil) {
    self.id = id
    self.type = type
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.url = url
    self.suffix = suffix
    self.item = item
    self.allDayItems = allDayItems
    self.children = children
    self.duplicates = duplicates
    self.forecast = forecast
    self.removeIfOrphaned = removeIfOrphaned
    self.height = height
    self.locations = locations
    self.meeting = meeting
    self.notes = notes
    self.attachments = attachments
    self.currentForecast = currentForecast
    self.dayForecast = dayForecast
    self.hourForecast = hourForecast
    self.date = date
    self.hasConflict = hasConflict
    self.hasStartConflict = hasStartConflict
    self.isFirstConflict = isFirstConflict
    self.timeZone = timeZone
  }
  
 
   
  var id: String = UUID().uuidString
  var type: String?
  var title: String?
  var startDate: Date?
  var endDate: Date?
  var url: URL?
  var suffix: String?
  var item: EKCalendarItem?
  var allDayItems: [EventEntry]?
  var children: [EventEntry]?
  var duplicates: [EventEntry]?
  var forecast: HourWeather?
  var removeIfOrphaned: Bool = false
  var height: CGFloat = 1
  var locations: [String]?
  var meeting: EventAttachment?
  var notes: AttributedString?
  var attachments: [EventAttachment]?
  var currentForecast: CurrentWeather?
  var dayForecast: DayWeather?
  var hourForecast: HourWeather?
  
  var date: Date?
  var hasConflict: Bool = false
  var hasStartConflict: Bool = false
  var isFirstConflict: Bool = false
  var timeZone: TimeZone?
  
  static func == (lhs: EventEntry, rhs: EventEntry) -> Bool {
    return lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  func conflictsWith(_ other: EventEntry) -> Bool {
    guard let end = endDate, item != nil else { return false }
    guard let otherStart = other.startDate, other.item != nil else { return false }
//    print(item?.title ?? title, other.item?.title ?? other.title, otherStart < end, otherStart , end)
    return otherStart < end
  }
  
  func isVisible(_ date: Date = Date()) -> Bool {
    guard let end = endDate else { return true }
    return end.timeIntervalSince(date) > 0
  }
  
  func isVerySoon(_ date: Date = Date()) -> Bool {
    guard let start = startDate else { return false }
    return start.timeIntervalSince(date) < 30 * 60 // 30 min away
  }
  
  func isSoon(_ date: Date = Date()) -> Bool {
    guard let start = startDate else { return false }
    return start.timeIntervalSince(date) < 2 * 60 * 60 // 2 hours away
  }
  
  func hasEnded(_ date: Date = Date()) -> Bool {
    guard let end = endDate else { return false }
    return end.timeIntervalSince(date) < 0
  }
  
  func isHappening(_ date: Date = Date()) -> Bool {
    guard let start = startDate, let end = endDate else { return false }
    return date > start && date < end
  }
  
  var hasLocation: Bool {
    return locations?.count ?? 0 > 0
  }
  
  var hasAttachments: Bool {
    return attachments?.count ?? 0 > 0
  }
}

// Filtered replacements array
let filteredReplacements: [String: String] = [
  "San Francisco": "SF",
  "New York": "NYC",
  "Los Angeles": "LA",
  "Washington": "DC",
  "London": "LON"
]

func clean(location input: String) -> String {
  // Removing parentheticals and brackets
  let pattern = "\\(.*?\\)|\\[.*?\\]"
  let regex = try! NSRegularExpression(pattern: pattern, options: [])
  var modifiedString = regex.stringByReplacingMatches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count), withTemplate: "")
  
  // Removing multiple spaces
  modifiedString = modifiedString.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression, range: nil)
  
  // Applying filtered replacements
  for (key, value) in filteredReplacements {
    modifiedString = modifiedString.replacingOccurrences(of: key, with: value)
  }
  
  // Trimming leading and trailing spaces
  return modifiedString.trimmingCharacters(in: .whitespacesAndNewlines)
}

func fetchReminders(configuration: ConfigurationIntent? = nil) async -> [EventEntry]? {
  return []
}

func fetchEvents(calendarIDs: [String]?, configuration: ConfigurationIntent? = nil) async -> [EventEntry]? {

  
  return []
}
