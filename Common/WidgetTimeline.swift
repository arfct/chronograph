import WidgetKit
import SwiftUI
import EventKit
import Contacts

struct CalendarTimelineEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationIntent
  let state: Bool = false
  var reminders: [EventEntry] = []
  var events: [EventEntry] = []
  var weather: String = ""
}


struct TimelineProvider: AppIntentTimelineProvider {
  
  @AppStorage("state") private var state = false
  
  func placeholder(in context: Context) -> CalendarTimelineEntry {
    
    let config = ConfigurationIntent()
    config.content = .calendar
    config.calendars = []
    
    let item = EKEvent(eventStore: EKEventStore())
    item.title = "Calendar Event"
    item.startDate = Date()
    
    return CalendarTimelineEntry(date: Date(), configuration: ConfigurationIntent(), events: [
      EventEntry(id: "", title: "Today"),
      EventEntry(id: "", item: item),
      EventEntry(id: "", item: item),
      EventEntry(id: "", item: item),
      EventEntry(id: "", title: "Today"),
      EventEntry(id: "", item: item),
      EventEntry(id: "", item: item),
      
    ])
    
  }
  
  func snapshot(for configuration: ConfigurationIntent, in context: Context) async -> CalendarTimelineEntry {
    let timeline = await timeline(for:configuration, in: context)
    return timeline.entries.first!
  }
  
  func timeline(for configuration: ConfigurationIntent, in context: Context) async -> Timeline<CalendarTimelineEntry> {
    await timeline(for: configuration, context: context)
  }
  
  // MARK: Timeline
  
  func timeline(for configuration: ConfigurationIntent, context: Context? = nil) async -> Timeline<CalendarTimelineEntry> {
    
    //
    //    let location = try? await LocationManager().currentLocation
    //    let weatherLocationManager = WeatherLocationManager()
    //      do {
    //        let weather = try await weatherLocationManager.fetchWeather()
    //
    //      } catch {
    //        print("Failed to fetch weather: \(error.localizedDescription)")
    //
    //      }
    //
    
    let content = configuration.content
    let now = Date()
    let calendar = Calendar.current
    
    let defaultCalendar = EKEventStore().defaultCalendarForNewEvents
    let defaultRemindersList = EKEventStore().defaultCalendarForNewReminders()
    
    let startDate = Date()
    let beginningOfDay = calendar.startOfDay(for: startDate)
    let endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!
    
    let reloadDate = calendar.date(byAdding: .minute,
                                   value: 15,
                                   to: now)!
    
    let showAllDay = configuration.showAllDay
    
    let calendarIDs = configuration.calendars.map({$0.id})
    let reminderIDs = configuration.reminders.map({$0.id})
    
    var errors: [String] = []
    
    var calendarItems: [EKCalendarItem] = []
    
    var reminderEntries: [EventEntry] = []
    
    let eventStore = EKEventStore()
    
    let remindersError = (content == .reminders || content == .both) && EKEventStore.authorizationStatus(for: .reminder) != .fullAccess
    let eventsError = (content == .calendar || content == .both) && EKEventStore.authorizationStatus(for: .event) != .fullAccess
    
    if (remindersError) {
      errors.append("Enable access to reminders in settings")
    }
    
    if (eventsError) {
      errors.append("Enable access to calendar in settings")
    }
    
    
    // MARK: Reminders
    if (content == .reminders) {
      let calendars: [EKCalendar] = reminderIDs.compactMap({eventStore.calendar(withIdentifier: $0)})
      let reminderPredicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)
      if let reminders = try? await eventStore.fetchRemindersAsync(predicate:reminderPredicate) {
        let sortedReminders = reminders
          .filter { $0.dueDateComponents?.date ?? .distantPast < endDate }
          .sorted(by: compareReminders)
        if (calendars.count != 0) {
          reminderEntries.append(EventEntry(type:"header", title:calendars.map({$0.title}).joined(separator: ", ")))
        }
        reminderEntries.append(contentsOf: sortedReminders.map { EventEntry(id: $0.calendarItemIdentifier, item: $0) })
      }
    }
    
    func compareCalendarItems(_ a: EKCalendarItem, _ b: EKCalendarItem) -> Bool {
      guard let aStart = a.start else { return false}
      guard let bStart = b.start else { return true}
      
      if aStart != bStart { return aStart < bStart }
      if a.title != b.title { return a.title < b.title }
      
      guard let lend = a.end else { return false}
      guard let rend = b.end else { return true}
      
      if lend != rend { return lend < rend }
      if b.calendar == defaultCalendar { return false }
      return a.calendar.title < b.calendar.title;
    }
    
    // MARK: Events
    if (content == .calendar || content == .both) {
      let calendars: [EKCalendar] = calendarIDs.compactMap({eventStore.calendar(withIdentifier: $0)})
      
      if content == .both, let scheduledReminders =
          try? await eventStore.fetchRemindersAsync(predicate: eventStore.predicateForIncompleteReminders(
            withDueDateStarting: beginningOfDay,
            ending: endDate, calendars: nil)) {
        
        calendarItems.append(contentsOf: scheduledReminders)
      }
      
      let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
      
      let fetchedEvents = eventStore.events(matching: predicate)
      calendarItems.append(contentsOf: fetchedEvents)
      let sortedItems = calendarItems.sorted (by:compareCalendarItems)
      calendarItems =  sortedItems//.map { EventEntry(id: $0.calendarItemIdentifier, item: $0) }
    }
    
    
    // MARK: Errors
    if (errors.count > 0) {
      return Timeline(entries: [
        CalendarTimelineEntry(date: now, configuration: configuration,
                              events: errors.map({ error in
                                EventEntry(type: error, title: error, url: URL(string: "settings:"))
                              }))
      ], policy: .after(reloadDate))
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEEE"
    
    
    let timeFormatter = DateFormatter()
    timeFormatter.timeStyle = .short
    timeFormatter.dateStyle = .short
    // MARK: Creating timeline entries
    
    let debug = false
    var timelineEntries: [CalendarTimelineEntry] = []
    
    
    var calendarEntries: [EventEntry] = []
    
    
    let distantPastEvent = EKEvent.init(eventStore: eventStore)
    distantPastEvent.startDate = .distantPast
    var previousItem: EKCalendarItem = distantPastEvent
    var headerIndex = 0
    
    let renderDate = now
    
    if (content != .reminders) {
      calendarEntries.append(EventEntry(type:"header", title:relativeDateFormatterDay.string(from: renderDate), allDayItems: [],  children: []))
    }
    
    for (i, item) in calendarItems.enumerated() {
      
      let lastDate = renderDate > previousItem.date ? renderDate : previousItem.date
      let thisDate = renderDate > item.date ? renderDate : item.date
      let dateHasChanged = !calendar.isDate(lastDate, inSameDayAs: thisDate)
      
      // Insert header row on day changes
      if (dateHasChanged) {
        let priorHeader =  calendarEntries[headerIndex]
        if (priorHeader.children?.count ?? 0) == 0 {
          calendarEntries.remove(at: headerIndex)
        }
        
        let title = calendar.isDateInTomorrow(item.date) ? relativeDateFormatterDay.string(from: item.date) : dateFormatter.string(from: item.date)
        let header = EventEntry(type: "header", title: title,
                                startDate:calendar.startOfDay(for: item.date), endDate:calendar.startOfDay(for: item.date).advanced(by: 24 * 60 * 60), allDayItems: [], children: [],
                                removeIfOrphaned: true)
        headerIndex = calendarEntries.count
        calendarEntries.append(header)
      } else {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.allowsFractionalUnits = true
        formatter.includesApproximationPhrase = false
        
        if let thisStart = item.start {
          let priorEnd = previousItem.end ?? renderDate
          let original = thisStart.timeIntervalSince(priorEnd)
          let rounded = TimeInterval((original / 900.0).rounded(.toNearestOrEven) * 900.0)
          
          if let duration = formatter.string(from: rounded) {
            
            // TODO: Hash the strategy off the timestamp
            if rounded >= 30 * 60 {
              let strategy = obliqueStrategies[Int(priorEnd.timeIntervalSince1970) % obliqueStrategies.count]
              let free = EventEntry(type: "free", title: "\(duration) free - \(strategy)",
                                    startDate:priorEnd, endDate:thisDate)
              calendarEntries.append(free)
            }
          }
        }
      }
      
      

      
      
      var eventEntry = EventEntry(id: item.calendarItemIdentifier, startDate:item.start, endDate:item.end, item: item)
      if let event = item as? EKEvent {
        
        // Ignore duplicates
        if event.title == previousItem.title &&
            calendar.isDate(event.startDate, equalTo: previousItem.date, toGranularity: .hour) {
//          previousItem.duplicates = [eventEntry]
          continue
        }
        
        if event.calendar != previousItem.calendar {
          eventEntry.suffix = String(event.calendar.title.prefix(1))
        }
        
        if event.isAllDay {
          if calendar.isDateInToday(event.startDate) && renderDate.advanced(by: 60 * 60 * 6) > endDate {
            calendarEntries[headerIndex].allDayItems?.insert(eventEntry, at:0)
            calendarEntries[headerIndex].children?.insert(eventEntry, at:0)
            calendarEntries[headerIndex].removeIfOrphaned = false
          }
        } else {
          calendarEntries[headerIndex].children?.insert(eventEntry, at:0)
          let fetchDetails = event.startDate < calendar.date(byAdding: .hour, value: 4, to: renderDate)!
          if (fetchDetails) {
            if let location = event.location, location.count > 0 {
              let locations = splitAndTrim(location)
              let urls = locations.filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
              let remainder = locations.filter { !urls.contains($0) }.map({clean(location:$0)})
              
              
              if let string = urls.first, let url = URL(string:string) {
                eventEntry.meeting =  EventAttachment(url: url.absoluteString, title: "Zoom")
              }
              eventEntry.locations = remainder
            }
            
            let contactStore = CNContactStore()
            if event.hasAttendees, let attendees = event.attendees {
              //              attendees.forEach { person in
              //                let matches = try? contactStore.unifiedContacts(matching: person.contactPredicate, keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor])
              //              }
              //              print("attendees", attendees.compactMap({ person in
              //                if person.isCurrentUser { return nil }
              //              }))
            }
            
            if event.hasNotes, let notes = event.notes,
               let firstNote = notes.split(separator: CALENDAR_SEPARATOR).first
            {
              
              if eventEntry.meeting == nil {
                eventEntry.meeting = extractMeetingUrls(from: notes).first
              }
              
              
              
              let note = removeMeetingMetadata(from: String(firstNote))
              
              
              var (docs, noteWithoutDocs) = extractAttachments(from: note)
              
              docs = docs.filter({ !$0.urlString.contains("zoom.us")})
              
              if (eventEntry.meeting == nil) {
                if let meeting = docs.filter({ $0.urlString.contains("meet.google.com")}).first {
                  eventEntry.meeting = meeting
                }
              }
              
              noteWithoutDocs = noteWithoutDocs.trimmingCharacters(in: .whitespacesAndNewlines)
              
              
              
              eventEntry.attachments = docs
              
              if (firstNote.contains("</")) {
                eventEntry.notes = attributedString(from:noteWithoutDocs)
              } else {
                eventEntry.notes = AttributedString(noteWithoutDocs.trimmingCharacters(in: .whitespacesAndNewlines))
              }
              
              print("\n===\(event.title ?? "UNTITLED") ===")
              if (docs.count > 0) { print("Docs \(docs.map({ "\($0.title) <\($0.urlString)>"}))")}
              if (noteWithoutDocs.count > 0) { print("Note:[\(noteWithoutDocs.trimmingCharacters(in: .whitespacesAndNewlines))]\n \(note)")}
              
            }
            
            
            if let url = event.url {
              if eventEntry.attachments == nil {
                eventEntry.attachments = []
              }
              eventEntry.attachments?.append(EventAttachment(url: url.absoluteString))
            }
            
          }
          calendarEntries.append(eventEntry)
          
        }
      } else if let reminder = item as? EKReminder {
        
        calendarEntries.append(eventEntry)
      }
      
      previousItem = item
    }
    
    
#if os(iOS) || os(watchOS)
    if context?.family == .accessoryRectangular
        && calendarEntries.first?.allDayItems?.count == 0 {
      calendarEntries.removeFirst()
    }
#endif
    
    
    // TODO: Sort these so that longer items are sorted after shorter items to correctly catch conflicts. Also sort by name to de-dup items on multiple calendars
    
    for (i, entry) in (calendarEntries.enumerated()) {
      if (i + 1 == calendarEntries.count) { break }
      // TODO: Handle conflicts
      let next = calendarEntries[i + 1]
      if entry.conflictsWith(next) {
        if (!entry.hasConflict) {
          calendarEntries[i].isFirstConflict = true
        }
        calendarEntries[i].hasConflict = true
        calendarEntries[i + 1].hasConflict = true
        if entry.startDate == next.startDate {
          calendarEntries[i + 1].hasStartConflict = true
        }
      }
    }
    
    
    
    for minuteOffset in 0 ..< 15 {
      let renderDate = Calendar.current.date(byAdding: .minute, value: debug ? 60 * 18 + minuteOffset * 30 : minuteOffset, to: now)!
      let entryDate = Calendar.current.date(byAdding: debug ? .second : .minute, value: minuteOffset, to: now)!
      
      
      let timelineEntry = CalendarTimelineEntry(date: entryDate,
                                                configuration: configuration,
                                                reminders: reminderEntries,
                                                events: calendarEntries)
      timelineEntries.append(timelineEntry)
      
    }
    
    return Timeline(entries: timelineEntries, policy: .atEnd)
    
  }
  
  func recommendations() -> [AppIntentRecommendation<ConfigurationIntent>] {
    
    var recommendations: [AppIntentRecommendation<ConfigurationIntent>]  = [
      AppIntentRecommendation(intent:ConfigurationIntent.calendarConfig, description: "Events"),
      AppIntentRecommendation(intent:ConfigurationIntent.remindersConfig, description: "Reminders"),
      AppIntentRecommendation(intent:ConfigurationIntent.comboConfig, description: "Combination"),
      AppIntentRecommendation(intent:ConfigurationIntent.combo2Config, description: "Combination (cont'd)"),
    ]
    return recommendations
  }
  
#if os(watchOS)
  @available(watchOS 11.0, *)
  func relevances() async -> WidgetRelevances<ConfigurationIntent> {
    // Generate a list containing the contexts this widget is relevant in.
    return WidgetRelevances([
      //        WidgetRelevance(context: .someContext, weight: 1),
    ])
  }
#endif
  
  
  
  static let sampleEntry: EventEntry = EventEntry(id: "1", type: "", title: "",  url: nil, suffix: "", item: nil)
  
  
}
