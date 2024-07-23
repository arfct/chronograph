import EventKit

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
    
    print("ATTACHMENT, \(url), \(title)")
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

struct EventEntry: Identifiable, Hashable {
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
  var removeIfOrphaned: Bool = false
  var height: CGFloat = 1
  var locations: [String]?
  var meeting: EventAttachment?
  var notes: AttributedString?
  var attachments: [EventAttachment]?
  
  var date: Date?


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
