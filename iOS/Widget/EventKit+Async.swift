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
      return Calendar.current.date(from: components)
  }
  var primaryDate: Date? {
    return dueDate
  }
}

extension EKCalendarItem {
//  var identifier: String? {
//    if let reminder = self as? EKReminder {
//      return reminder.dueDate;
//    } else if let event = self as? EKEvent {
//      return event.eventIdentifier;
//    }
//    return nil
//  }
//  
  
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
      
      guard let components = reminder.startDateComponents else { return nil }
      return Calendar.current.date(from: components)
    } else if let event = self as? EKEvent {
      return event.startDate;
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
