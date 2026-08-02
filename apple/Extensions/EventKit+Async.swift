import EventKit
import SwiftUI
extension EKEventStore {
    func fetchRemindersAsync(predicate: NSPredicate) async throws -> [EKReminder] {
        return try await withCheckedThrowingContinuation { continuation in
            self.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "EKEventStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]))
                }
            }
        }
    }
}

extension EKReminder {
  var dueDate: Date? {
    guard let components = self.dueDateComponents else { return nil }
    return components.date
  }
  var primaryDate: Date? {
    return dueDate
  }
  
  //  Per RFC 5545, priorities of 1-4 are considered "high," a priority of 5 is "medium," and priorities of 6-9 are "low."
  var priorityPrefix: String {
    if self.priority == 5 { return "!!" }
    if self.priority > 5 { return "!" }
    return "!!!"
  }
}

extension EKEvent {
  var participantStatus: EKParticipantStatus? {
    print ("attendees:", self.attendees)
    return attendees?.filter({$0.isCurrentUser}).first?.participantStatus
  }
}
extension EKCalendarItem {

  
  func valid(at date: Date) -> Bool{
    if let end = end {
      if allDay, let earlyEnd = Calendar.current.date(byAdding: .minute, value: -6, to: end) {
        return earlyEnd > date
      } else {
        return end > date
      }
    }
    return allDay
  }
  
  var allDay: Bool {
    if let reminder = self as? EKReminder,
       let components = reminder.dueDateComponents,
       components.hour == nil {
        return true
    } else if let event = self as? EKEvent {
      return event.isAllDay;
    }
    return false
  }
  
  
  var date: Date {
    if let reminder = self as? EKReminder {
      return reminder.dueDate ?? .distantFuture;
    } else if let event = self as? EKEvent {
      return event.startDate;
    }
    return .distantPast
  }
  
  var start: Date? {
    if let reminder = self as? EKReminder {
      guard let components = reminder.dueDateComponents else { return nil }
      return components.date
    } else if let event = self as? EKEvent {
      return event.startDate;
    }
    return nil
  }
  
  var end: Date? {
    if let reminder = self as? EKReminder {
      guard let components = reminder.dueDateComponents else { return nil }
      if allDay { return components.date}
      if let date = components.date {
        return Calendar.current.date(byAdding: .minute, value: 25, to: date)
      }
    } else if let event = self as? EKEvent {
      return event.endDate;
    }
    return nil
  }
  
  func compareDate(with: EKCalendarItem) -> Bool {
    return self.date < with.date
  }
  
  
  var color: Color? {
    if let cgColor = calendar?.cgColor {
      return Color(cgColor: cgColor)
    }
    return nil
  }
}


func compareCalendarItems(_ item1: EKCalendarItem, _ item2: EKCalendarItem) -> Bool {
  if let start1 = item1.start, let start2 = item2.start {
    if start1 == start2 {
      return item1.title < item2.title
    }
    return start1 < start2
    
    } else if item1.start != nil {
        return true
    } else if item2.start != nil {
        return false
    }
    
    // If due dates are the same or both nil, compare by creation date
    if let creationDate1 = item1.creationDate, let creationDate2 = item2.creationDate {
        return creationDate1 > creationDate2
    }

    return false
}

func compareReminders(_ reminder1: EKReminder, _ reminder2: EKReminder) -> Bool {
    if let dueDate1 = reminder1.dueDateComponents?.date, let dueDate2 = reminder2.dueDateComponents?.date {
      let now = Date()
        if dueDate1 != dueDate2 { // sort by distance from now
          return abs(dueDate1.timeIntervalSince(now)) < abs(dueDate2.timeIntervalSince(now))
        }
    } else if reminder1.dueDateComponents?.date != nil {
        return true
    } else if reminder2.dueDateComponents?.date != nil {
        return false
    }
    
    // If due dates are the same or both nil, compare by creation date
    if let creationDate1 = reminder1.creationDate, let creationDate2 = reminder2.creationDate {
        return creationDate1 > creationDate2
    }

    return false
}


func sanitizeAllDayEvents(_ input: String) -> String {
  return replaceBirthdayString(input)
}

func replaceBirthdayString(_ input: String) -> String {
  // Regular expression pattern to match both straight and curly quotes
  let pattern = #"([\w\s]+)[’']s (\d+th )?Birthday"#
  let regex = try! NSRegularExpression(pattern: pattern, options: [])
  
  let range = NSRange(location: 0, length: input.utf16.count)
  let modifiedString = regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "🎂$1")
  
  return modifiedString
}

let CALENDAR_SEPARATOR = "-::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-"

let ZOOM_SEPARATOR = "──────────"



extension Array {
  mutating func removeAllFromEnd(where predicate: (Element) -> Bool) {
    while let last = self.last, predicate(last) {
      self.removeLast()
    }
  }
}

extension Date {
  func formattedHourAndMinute(timeZone: TimeZone? = nil) -> (hour: String, minute: String, ampm: String) {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.current
    dateFormatter.timeZone = timeZone

    dateFormatter.dateFormat = "h"
    let hourString = dateFormatter.string(from: self)

    dateFormatter.dateFormat = "mm"
    let minuteString = dateFormatter.string(from: self)
    
    dateFormatter.dateFormat = "a"
    let ampmString = dateFormatter.string(from: self)
      //.replacingOccurrences(of: "M", with: "")

    return (hourString, minuteString, ampmString)
  }
}


extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

func openAppSettings() {
#if os(iOS)
  if let appSettings = URL(string: UIApplication.openSettingsURLString) {
//    UIApplication.shared.open(appSettings)
    
    let sharedSelector = NSSelectorFromString("sharedApplication")
    let openSelector = NSSelectorFromString("openURL:")

    if UIApplication.responds(to: sharedSelector),
        let shared = UIApplication.perform(sharedSelector)?.takeRetainedValue() as? UIApplication,
        shared.responds(to: openSelector) {

        shared.perform(openSelector, with: appSettings)

    }
  }
  
  
#elseif os(macOS)
  
#endif
}
