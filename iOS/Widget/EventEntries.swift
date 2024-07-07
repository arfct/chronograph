import EventKit

struct EventEntry: Identifiable, Hashable {
  var id: String
  var type: String?
  var title: String?
  var date: Date?
  var url: URL?
  var suffix: String?
  var item: EKCalendarItem?
  var allDayItems: [EventEntry]?
  var removeIfOrphaned: Bool = false
}

func clean(location input: String) -> String {
  // Removing parentheticals and brackets
  let pattern = "\\(.*?\\)|\\[.*?\\]"
  let regex = try! NSRegularExpression(pattern: pattern, options: [])
  var modifiedString = regex.stringByReplacingMatches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count), withTemplate: "")
  
  // Removing multiple spaces
  modifiedString = modifiedString.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression, range: nil)
  
  // Trimming leading and trailing spaces
  return modifiedString.trimmingCharacters(in: .whitespacesAndNewlines)
}

func fetchReminders(configuration: ConfigurationIntent? = nil) async -> [EventEntry]? {
  return []
}

func fetchEvents(calendarIDs: [String]?, configuration: ConfigurationIntent? = nil) async -> [EventEntry]? {

  
  return []
}
