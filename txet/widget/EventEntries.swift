import EventKit

struct EventEntry: Identifiable, Hashable {
  var id: String
  var type: String?
  var header: String?
  var date: Date?
  var item: EKCalendarItem?
  var allDayItems: [EventEntry]?
}

func fetchReminders() async -> [EventEntry]? {
  let eventStore = EKEventStore()
  return await withCheckedContinuation { continuation in
    
    let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
    eventStore.fetchReminders(matching: predicate) { fetchedReminders in

      guard let fetchedReminders = fetchedReminders else {
        continuation.resume(returning: nil)
        return
      }

      let sortedReminders = fetchedReminders.sorted { (reminder1, reminder2) -> Bool in
        // Sort by due date, putting those with nil due date at the end
        if let dueDate1 = reminder1.dueDateComponents?.date, let dueDate2 = reminder2.dueDateComponents?.date {
          if dueDate1 != dueDate2 {
            return dueDate1 > dueDate2
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
        // If both dates are nil or equal, consider them equal (or define another rule)
        return false
      }

      let items = sortedReminders.map { EventEntry(id: $0.calendarItemIdentifier, item: $0) }
      continuation.resume(returning: items)
    }
  }
}
func fetchEvents(calendarIDs: [String]?) async -> [EventEntry]? {
  let eventStore = EKEventStore()
  
  return await withCheckedContinuation { continuation in
    let calendar = Calendar.current
    let startDate = Date()
    let endDate = calendar.date(byAdding: .day, value: 4, to: startDate)!
    
    var calendars: [EKCalendar] = []
    
    //var defaultCalendar = eventStore.defaultCalendarForNewEvents
    if let ids = calendarIDs {
      ids.forEach { id in
        if let calendar = eventStore.calendar(withIdentifier: id) {
          calendars.append(calendar)
        }
      }
    }
    print("Fetching events for \(calendars)")
    
    let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
    
    let fetchedEvents = eventStore.events(matching: predicate).sorted { a, b in
      let order = a.compareStartDate(with: b)
      if order == .orderedSame {
        return a.title < b.title
      }
      return order == .orderedAscending
    }
    
    var items: [EventEntry] = []
    var previousItem: EKEvent? = nil
    let now = Date()
    var headerIndex = 0
    items.append(EventEntry(id:"today", header:"NOW", allDayItems: []))
    for event in fetchedEvents {
      let item = EventEntry(id: event.eventIdentifier, item: event)
      
      if let previousItem {
        
        
        // Ignore duplicates
        if event.title == previousItem.title &&
            calendar.isDate(event.startDate, equalTo: previousItem.startDate, toGranularity: .hour) { continue }
        
        // Insert day names on any change
        if let lastDate = now > previousItem.startDate ? now : previousItem.startDate,
           let thisDate = now > event.startDate ? now : event.startDate {
          // Insert header entries between subsequent days
          if !calendar.isDate(lastDate, inSameDayAs: thisDate) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE"
            let header = EventEntry(id: "", header:
//                                      calendar.isDateInTomorrow(event.startDate) ? "Tomorrow" :
                                      dateFormatter.string(from: event.startDate),
                                    date:calendar.startOfDay(for: event.startDate),
                                allDayItems: []
                                   )
            
            items.append(EventEntry(id:"spacer", type:"spacer"))
            headerIndex = items.count
            items.append(header)
          }
        }
      }
      
      if event.isAllDay {
        items[headerIndex].allDayItems?.append(item)
      } else {
        items.append(item)
      }
      previousItem = event
    }
    
    continuation.resume(returning: items)
  }
}
