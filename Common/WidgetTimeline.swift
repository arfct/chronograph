import WidgetKit
import SwiftUI
import EventKit

struct CalendarTimelineEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationIntent
  let state: Bool = false
  var reminders: [EventEntry] = []
  var events: [EventEntry] = []
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
    
    let content = configuration.content
    let now = Date()
    let calendar = Calendar.current
    
    let startDate = Date()
    let beginningOfDay = calendar.startOfDay(for: startDate)
    let endDate = calendar.date(byAdding: .day, value: 14, to: startDate)!
    
    let reloadDate = calendar.date(byAdding: .minute,
                                   value: 15,
                                   to: now)!
    
    let showAllDay = configuration.showAllDay
    
    let calendarIDs = configuration.calendars.map({$0.id})
    let reminderIDs = configuration.reminders.map({$0.id})
    
    var errors: [String] = []

    var eventItems: [EKCalendarItem] = []
    
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
        
        eventItems.append(contentsOf: scheduledReminders)
      }
      
      let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
      
      let fetchedEvents = eventStore.events(matching: predicate)
      eventItems.append(contentsOf: fetchedEvents)
      let sortedItems = eventItems.sorted { $0.compareDate(with: $1)}
      
      eventItems =  sortedItems//.map { EventEntry(id: $0.calendarItemIdentifier, item: $0) }
    }
    
    
    // MARK: Errors
    if (errors.count > 0 ) {
      return Timeline(entries: [
        CalendarTimelineEntry(date: now, configuration: configuration,
                              events: errors.map({ error in
                                EventEntry(id: error, title: error, url: URL(string: "settings:"))
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
    for minuteOffset in 0 ..< 15 {
      let renderDate = Calendar.current.date(byAdding: .minute, value: debug ? 60 * 18 + minuteOffset * 30 : minuteOffset, to: now)!
      let entryDate = Calendar.current.date(byAdding: debug ? .second : .minute, value: minuteOffset, to: now)!
      
      var calendarEntries: [EventEntry] = []
      
      
      //      calendarEntries.append(EventEntry(id: "DEBUG", title:"Debug \((timeFormatter.string(from:renderDate)))"))
      let distantPastEvent = EKEvent.init(eventStore: eventStore)
      distantPastEvent.startDate = .distantPast
      var previousItem: EKCalendarItem = distantPastEvent
      var headerIndex = 0
      
      var futureEventItems = eventItems.filter { $0.valid(at: renderDate) }
      
      calendarEntries.append(EventEntry(id:"today", title:relativeDateFormatterDay.string(from: renderDate), allDayItems: []))
      for (index, item) in futureEventItems.enumerated() {
        var entry = EventEntry(id: item.calendarItemIdentifier, item: item)
        
        // Insert day names on any change
        let lastDate = renderDate > previousItem.date ? renderDate : previousItem.date
        let thisDate = renderDate > item.date ? renderDate : item.date
        
        // Insert header entries between subsequent days
        if !calendar.isDate(lastDate, inSameDayAs: thisDate) {
          entry.suffix = relativeDateFormatterDay.string(from: item.date)
          
          let header = EventEntry(id: "", title:
                                    calendar.isDateInTomorrow(item.date) ? relativeDateFormatterDay.string(from: item.date) : dateFormatter.string(from: item.date),
                                  date:calendar.startOfDay(for: item.date),
                                  allDayItems: [],
                                  removeIfOrphaned: true
          )
          
          //          items.append(EventEntry( id:"spacer", type:"spacer", removeIfOrphaned: true))
          headerIndex = calendarEntries.count
          calendarEntries.append(header)
          
        }
        
        if let thisDate = entry.date {
          let lastDate = previousItem.date
         
          let components = calendar.dateComponents([.hour, .minute], from: thisDate, to: lastDate)
          if let duration = relativeTimeFormatter.string(from: components) {
            calendarEntries.append(EventEntry(id: "startsIn", title:"in \(duration)"))
          }
        }

        
        if let event = item as? EKEvent {
          
          let isHappening = renderDate >= event.startDate && now <= event.endDate
          let isNext = now >= calendar.date(byAdding: .hour, value: 1, to: event.startDate)!
          
//          if (index == 0) {
//            let components = calendar.dateComponents([.hour, .minute], from: renderDate, to: event.startDate)
//            if let downtime = relativeTimeFormatter.string(from: components) {
//              calendarEntries.append(EventEntry(id: "startsIn", title:"in \(downtime)"))
//            }
//          }
          // Ignore duplicates
          if event.title == previousItem.title &&
              calendar.isDate(event.startDate, equalTo: previousItem.date, toGranularity: .hour) { continue }
          
          if event.calendar != previousItem.calendar {
            entry.suffix = String(event.calendar.title.prefix(1))
          }
          
          if event.isAllDay {
            if calendar.isDateInToday(event.startDate) {
              calendarEntries[headerIndex].allDayItems?.insert(entry, at:0)
              calendarEntries[headerIndex].removeIfOrphaned = false
            }
          } else {
            calendarEntries.append(entry)
            
            if isHappening || isNext, let location = event.location {
              calendarEntries.append(EventEntry(id: "location", title:clean(location:location), date: event.date))
            }
          }
        } else if let reminder = item as? EKReminder {
          
          calendarEntries.append(entry)
        }
        
        previousItem = item
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
  
  
  
  static let sampleEntry: EventEntry = EventEntry(id: "1", type: "", title: "", date: nil, url: nil, suffix: "", item: nil, allDayItems: nil, removeIfOrphaned: false, height: 0)
  
  
}
