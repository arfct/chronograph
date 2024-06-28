import EventKit

struct EventEntry: Identifiable, Hashable {
  var id: String
  var type: String?
  var header: String?
  var date: Date?
  var url: URL?
  var suffix: String?
  var item: EKCalendarItem?
  var allDayItems: [EventEntry]?
  var canBeWidowed: Bool = false
  
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
func fetchEvents(calendarIDs: [String]?, configuration: ConfigurationIntent? = nil) async -> [EventEntry]? {
  let eventStore = EKEventStore()
  
  return await withCheckedContinuation { continuation in
    let calendar = Calendar.current
    let startDate = Date()
    let endDate = calendar.date(byAdding: .day, value: 14, to: startDate)!
    
    let showAllDay = configuration?.showAllDay ?? false
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
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEE"
    
    var items: [EventEntry] = []
    var previousItem: EKEvent = EKEvent.init(eventStore: eventStore)
    previousItem.startDate = .distantPast
    let now = Date()
    var headerIndex = 0
    items.append(EventEntry(id:"today", header:dateFormatter.string(from: now), allDayItems: []))
    for event in fetchedEvents {
      var item = EventEntry(id: event.eventIdentifier, item: event)
      
      let isHappening = now >= event.startDate && now <= event.endDate
      let isNext = now >= calendar.date(byAdding: .hour, value: 1, to: event.startDate)!
      
      
      // Ignore duplicates
      if event.title == previousItem.title &&
          calendar.isDate(event.startDate, equalTo: previousItem.startDate, toGranularity: .hour) { continue }
      
      if event.calendar != previousItem.calendar {
        item.suffix = String(event.calendar.title.prefix(1))
        
      }
      // Insert day names on any change
      if let lastDate = now > previousItem.startDate ? now : previousItem.startDate,
         let thisDate = now > event.startDate ? now : event.startDate {
        
        // Insert header entries between subsequent days
        if !calendar.isDate(lastDate, inSameDayAs: thisDate) {
          item.suffix = dateFormatter.string(from: event.startDate)
          
          let header = EventEntry(id: "", header:
                                    dateFormatter.string(from: event.startDate),
                                  date:calendar.startOfDay(for: event.startDate),
                                  allDayItems: [],
                                  canBeWidowed: true
          )
          
//          items.append(EventEntry( id:"spacer", type:"spacer", canBeWidowed: true))
          headerIndex = items.count
          items.append(header)
        }
      }
      
      
      if event.isAllDay {
        if calendar.isDateInToday(event.startDate) {
          items[headerIndex].allDayItems?.insert(item, at:0)
          items[headerIndex].canBeWidowed = false
        }
      } else {
        items.append(item)
        
        if isHappening || isNext, let location = event.location {
          items.append(EventEntry(id: "location", header:clean(location:location)))
        }
      }
      previousItem = event
    }
    
    if items.first?.allDayItems?.count == 0 {
      items.removeFirst()
    }
    continuation.resume(returning: items)
  }
}
