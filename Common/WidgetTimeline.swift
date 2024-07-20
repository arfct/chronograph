import WidgetKit
import SwiftUI
import EventKit

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
      let reminderPredicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
      if let reminders = try? await eventStore.fetchRemindersAsync(predicate:reminderPredicate) {
        let sortedReminders = reminders
          .filter { $0.dueDateComponents?.date ?? .distantPast < endDate }
          .sorted(by: compareReminders)
        reminderEntries = sortedReminders.map { EventEntry(id: $0.calendarItemIdentifier, item: $0) }
      }
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
      let sortedItems = calendarItems.sorted { $0.compareDate(with: $1)}
      
      calendarItems =  sortedItems//.map { EventEntry(id: $0.calendarItemIdentifier, item: $0) }
    }
    
    
    // MARK: Errors
    if (errors.count > 0 ) {
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
    calendarEntries.append(EventEntry(type:"today", title:relativeDateFormatterDay.string(from: renderDate), allDayItems: []))
    
    for (_, item) in calendarItems.enumerated() {
      
      let lastDate = renderDate > previousItem.date ? renderDate : previousItem.date
      let thisDate = renderDate > item.date ? renderDate : item.date
      
      // Insert header row on day changes
      if !calendar.isDate(lastDate, inSameDayAs: thisDate) {
        let title = calendar.isDateInTomorrow(item.date) ? relativeDateFormatterDay.string(from: item.date) : dateFormatter.string(from: item.date)
        let header = EventEntry(type: "header", title: title,
                                startDate:calendar.startOfDay(for: item.date), endDate:calendar.startOfDay(for: item.date).advanced(by: 24 * 60 * 60), allDayItems: [],
                                removeIfOrphaned: true)
        headerIndex = calendarEntries.count
        calendarEntries.append(header)
      }
      
      var eventEntry = EventEntry(id: item.calendarItemIdentifier, startDate:item.start, endDate:item.end, item: item)
      if let event = item as? EKEvent {
        
        // Ignore duplicates
        if event.title == previousItem.title &&
            calendar.isDate(event.startDate, equalTo: previousItem.date, toGranularity: .hour) { continue }
        
        if event.calendar != previousItem.calendar {
          eventEntry.suffix = String(event.calendar.title.prefix(1))
        }
        
        if event.isAllDay {
          if calendar.isDateInToday(event.startDate) {
            calendarEntries[headerIndex].allDayItems?.insert(eventEntry, at:0)
            calendarEntries[headerIndex].removeIfOrphaned = false
          }
        } else {
          let fetchDetails = event.startDate < calendar.date(byAdding: .hour, value: 4, to: renderDate)!
          if (fetchDetails) {
            if let location = event.location {
              let locations = splitAndTrim(location)
              let urls = locations.filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
              let remainder = locations.filter { !urls.contains($0) }.map({clean(location:$0)})
              
              print("Meeting", locations, urls, remainder)
              if let string = urls.first, let url = URL(string:string) {
                eventEntry.meetingURL = url
              }
              eventEntry.locations = remainder
            }
            print("Event Notes", event.notes)
            if let notes = event.notes,
               let firstNote = notes.split(separator: CALENDAR_SEPARATOR).first
            {
              

              let note = removeMeetingMetadata(from: String(firstNote))
              
              
              var (docs, noteWithoutDocs) = extractDocumentURLs(from: note)
              
              docs = docs.filter({ !$0.urlString.contains("zoom.us")})
              
              if (eventEntry.meetingURL == nil) {
                if let meeting = docs.filter({ $0.urlString.contains("meet.google.com")}).first {
                  eventEntry.meetingURL = meeting.url
                }
              }
              
              noteWithoutDocs = noteWithoutDocs.trimmingCharacters(in: .whitespacesAndNewlines)
              eventEntry.documents = docs
              
              if (firstNote.contains("</")) {
                eventEntry.notes = attributedString(from:noteWithoutDocs)
              } else {
                eventEntry.notes = AttributedString(noteWithoutDocs)
              }
              
              print("\n===\(event.title ?? "UNTITLED") ===")
              if (docs.count > 0) { print("Docs \(docs.map({ "\($0.title) <\($0.urlString)>"}))")}
              if (noteWithoutDocs.count > 0) { print("Note:[\(noteWithoutDocs.trimmingCharacters(in: .whitespacesAndNewlines))]\n \(note)")}
              
            }
            
          }
          calendarEntries.append(eventEntry)
          
        }
      } else if let reminder = item as? EKReminder {
        
        calendarEntries.append(eventEntry)
      }
      
      previousItem = item
    }
    
    
    
    for minuteOffset in 0 ..< 15 {
      let renderDate = Calendar.current.date(byAdding: .minute, value: debug ? 60 * 18 + minuteOffset * 30 : minuteOffset, to: now)!
      let entryDate = Calendar.current.date(byAdding: debug ? .second : .minute, value: minuteOffset, to: now)!
      
      var filteredCalendarEntries: [EventEntry] = []
      
      calendarEntries.forEach { eventEntry in
        var newEntry = eventEntry
        if let event = eventEntry.item {
          if event.valid(at: renderDate) {
            
//            newEntry.isHappening = renderDate >= event.start ?? .distantFuture && now <= event.end ?? .distantFuture
//            newEntry.isNext = renderDate >= calendar.date(byAdding: .hour, value: -1, to: event.start ?? .distantFuture)!
          }
          filteredCalendarEntries.append(eventEntry)
        }
        
      }
      
      if calendarEntries.first?.allDayItems?.count == 0 {
        calendarEntries.removeFirst()
      }
      
      
      
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
  
  
  
  static let sampleEntry: EventEntry = EventEntry(id: "1", type: "", title: "",  url: nil, suffix: "", item: nil, allDayItems: nil, removeIfOrphaned: false, height: 0)
  
  
}
