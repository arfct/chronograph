import EventKit

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
