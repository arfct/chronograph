import WidgetKit
import SwiftUI
import EventKit
import Contacts
import WeatherKit

struct CalendarTimelineEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationIntent
  let state: Bool = false
  var reminders: [EventEntry] = []
  var events: [EventEntry] = []
  var weather: Weather?
  var timezones: [EventEntry] = []
  let context: TimelineProviderContext?
}


struct TimelineProvider: AppIntentTimelineProvider {
  
  @AppStorage("state") private var state = false
  
  var weatherManager = WeatherLocationManager()
  var eventStore = EKEventStore()
  func placeholder(in context: Context) -> CalendarTimelineEntry {
    
    let config = ConfigurationIntent()
    config.content = .calendar
    config.calendars = []
    
    let item = EKEvent(eventStore: eventStore)
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
      
    ], context: context)
    
  }
  
  func snapshot(for configuration: ConfigurationIntent, in context: Context) async -> CalendarTimelineEntry {
    let timeline = await timeline(for:configuration, in: context)
    return timeline.entries.first!
  }
  
  func timeline(for configuration: ConfigurationIntent, in context: Context) async -> Timeline<CalendarTimelineEntry> {
    await timeline(for: configuration, context: context)
  }
  
  // MARK: Timeline
  
  private func getTimezoneEntries(configuration: ConfigurationIntent) -> [EventEntry] {
    var timezoneEntries: [EventEntry] = []
    
    if configuration.content == .timezones {
      let calendar = Calendar.current
      let now = Date()
      
      var timezones = configuration.timezones.compactMap({TimeZone(identifier: $0.id)})
      
      for timeZone in timezones {
        
        let offset = timeZone.secondsFromGMT(for: now)
        let offsetHours = offset / 3600
        let offsetMinutes = abs((offset % 3600) / 60)
        
        var offsetString = ""
        if offsetHours >= 0 {
          offsetString += "+"
        } else {
          offsetString += "-"
        }
        
        offsetString += String(format: "%02d:%02d", abs(offsetHours), offsetMinutes)
        
        let timezoneEntry = EventEntry(type: "timezone", title: timeZone.description.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " "), timeZone: timeZone)
        timezoneEntries.append(timezoneEntry)
        
      }
    }
    
    return timezoneEntries
  }
  
  static var cachedTimelines: [String: (timeline: Timeline<CalendarTimelineEntry>, timestamp: Date)] = [:]
  
  func timeline(for configuration: ConfigurationIntent, context: Context? = nil) async -> Timeline<CalendarTimelineEntry> {
    
    let identifier = "\(context?.family.description ?? "none").\(configuration.content)"
    
    let now = Date()
    
    //    WidgetCenter.shared.getCurrentConfigurations { widgets in
    //      print("widgets", widgets.map({ $0}))
    //    }
    
    
    // Check if the cached timeline exists and if it's within the last minute
    if let cachedData = TimelineProvider.cachedTimelines[identifier],
       cachedData.timestamp > now.addingTimeInterval(-60) {
      print("Returning cached timeline for \(identifier)" )
      return(cachedData.timeline)
    }
    
   print("\nMaking timeline for \(identifier)" )
    
    let calendar = Calendar.current
    let startDate = Date()
    let endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!
    
    let showAllDay = configuration.features.contains(.allDayEvents)
    let showMultiDay = configuration.features.contains(.multiDayEvents)
    let showWeather = configuration.features.contains(.weather) || configuration.content == .weather
    
    let timezoneEntries = getTimezoneEntries(configuration:configuration)
    
    
    let weather = showWeather ? await fetchWeather() : nil
    
    let reminderEntries = await fetchReminders(configuration: configuration, startDate: startDate, endDate: endDate)
    let scheduledReminders = await fetchScheduledReminders(configuration: configuration, startDate: startDate, endDate: endDate)
    let events = await fetchEvents(configuration: configuration, startDate: startDate, endDate: endDate)
    
    var calendarItems: [EKCalendarItem] = []
    calendarItems.append(contentsOf: scheduledReminders)
    calendarItems.append(contentsOf: events)
    
    
    
    calendarItems = calendarItems.sorted(by: compareCalendarItems)
    
    //    events.forEach { (item) in
    //      print("Event:\n\(item.title ?? "?")\n\(item.eventIdentifier ?? "?")")
    //    }
    
    let reloadDate = calendar.date(byAdding: .minute,
                                   value: 15,
                                   to: now)!
    
    
    var errors: [String] = []
    
    let remindersError = (configuration.content == .reminders || configuration.content == .calendar) && EKEventStore.authorizationStatus(for: .reminder) != .fullAccess
    let eventsError = (configuration.content == .calendar) && EKEventStore.authorizationStatus(for: .event) != .fullAccess
    
    if (remindersError) {
      errors.append("Enable access to reminders in settings")
    }
    
    if (eventsError) {
      errors.append("Enable access to calendar in settings")
    }
    
    // MARK: Errors
    if (errors.count > 0) {
      return Timeline(entries: [
        CalendarTimelineEntry(date: now, configuration: configuration,
                              events: errors.map({ error in
                                EventEntry(type: error, title: error, url: URL(string: "settings:"))
                              }), context: context)
      ], policy: .after(reloadDate))
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEEE"
    
    // MARK: Creating timeline entries
    
    let debug = false
    var timelineEntries: [CalendarTimelineEntry] = []
    
    
    var calendarEntries: [EventEntry] = []
    
    
    let distantPastEvent = EKEvent.init(eventStore: eventStore)
    distantPastEvent.startDate = .distantPast
    var previousItem: EKCalendarItem?
    var headerIndex = -1
    
    let renderDate = now
    
    //    if (content != .reminders) {
    //      calendarEntries.append(EventEntry(type:"header", title:relativeDateFormatterDay.string(from: renderDate), allDayItems: [],  children: []))
    //    }
    //
    
    for (i, item) in calendarItems.enumerated() {
      
      var lastDate: Date = .distantPast
      if let previousItem = previousItem {
        lastDate = renderDate > previousItem.date ? renderDate : previousItem.date
      }
      
      let thisDate = renderDate > item.date ? renderDate : item.date
      let dateHasChanged = !calendar.isDate(lastDate, inSameDayAs: thisDate)
      
      if (item.allDay) {
        if (!showAllDay) { continue }
        if !showMultiDay && !calendar.isDate(item.start ?? .distantPast, inSameDayAs: item.end ?? .distantFuture) { continue }
      }
      
      // Insert header row on day changes
      if (dateHasChanged) {
        if (headerIndex >= 0) {
          let priorHeader = calendarEntries[headerIndex]
          if (priorHeader.children?.count ?? 0) == 0 {
            calendarEntries.remove(at: headerIndex)
          }
        }
        
        let title = calendar.isDateInToday(thisDate) || calendar.isDateInTomorrow(thisDate) ? relativeDateFormatterDay.string(from: thisDate) : dateFormatter.string(from: thisDate)
        
        let startOfDay = calendar.startOfDay(for: item.date)
        let days = max(0, calendar.dateComponents([.day],
                                                  from: calendar.startOfDay(for: renderDate),
                                                  to: calendar.startOfDay(for:item.date)).day!)
        
        let forecast = weather?.dailyForecast[safe: days]
        
        let header = EventEntry(type: "header", title: title,
                                startDate:calendar.startOfDay(for: thisDate), endDate:calendar.startOfDay(for: item.date).advanced(by: 24 * 60 * 60), allDayItems: [], children: [],
                                removeIfOrphaned: true, dayForecast:forecast)
        
        headerIndex = calendarEntries.count
        calendarEntries.append(header)
      } else if (configuration.features.contains(.freeTime)){
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.allowsFractionalUnits = true
        formatter.includesApproximationPhrase = false
        
        if let thisStart = item.start {
          let priorEnd = previousItem?.end ?? renderDate
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
        if let previousItem = previousItem, event.title == previousItem.title &&
            calendar.isDate(event.startDate, equalTo: previousItem.date, toGranularity: .hour) {
          //          previousItem.duplicates = [eventEntry]
          continue
        }
        
        if event.calendar != previousItem?.calendar {
          eventEntry.suffix = String(event.calendar.title.prefix(1))
        }
        
        
        if event.isAllDay {
          if true || calendar.isDateInToday(event.startDate)
              && (renderDate.advanced(by: 60 * 60 * 3) < event.endDate) // remove all day events after 9
          {
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
            
            //            let contactStore = CNContactStore()
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
              
              //print("\n===\(event.title ?? "UNTITLED") ===")
              if (docs.count > 0) { print("Docs \(docs.map({ "\($0.title) <\($0.urlString)>"}))")}
              //              if (noteWithoutDocs.count > 0) { print("Note:[\(noteWithoutDocs.trimmingCharacters(in: .whitespacesAndNewlines))]\n \(note)")}
              
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
    
    //#if os(iOS) || os(watchOS)
    //    if context?.family == .accessoryRectangular
    //        && calendarEntries.first?.allDayItems?.count == 0 {
    //      calendarEntries.removeFirst()
    //    }
    //#endif
    
    
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
    
    
    if let weather = weather, configuration.content == .weather {
      
      let hourlyForecast = weather.hourlyForecast
      
      for forecast in hourlyForecast.forecast.prefix(24) {
        let eventEntry = EventEntry(type: "weather",
                                    title:"Weather",
                                    startDate: forecast.date,
                                    endDate: forecast.date.addingTimeInterval(3600),
                                    forecast: forecast
        )
        calendarEntries.append(eventEntry)
      }
    }
    
    
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
    
    let fullMinuteDate = calendar.date(from: components)!
    print("timezon \(timezoneEntries)")
    for minuteOffset in 0 ..< 15 {
      let renderDate = calendar.date(byAdding: .minute,
                                     value: debug ? 60 * 18 + minuteOffset * 30 : minuteOffset, to: fullMinuteDate)!
      let entryDate = calendar.date(byAdding: debug ? .second : .minute,
                                    value: minuteOffset,
                                    to: fullMinuteDate)!
      
      let timelineEntry = CalendarTimelineEntry(date: entryDate,
                                                configuration: configuration,
                                                reminders: reminderEntries,
                                                events: calendarEntries,
                                                weather: weather,
                                                timezones: timezoneEntries,
                                                context: context)
      timelineEntries.append(timelineEntry)
      
    }
    print ("Returning timeline in \(round(-now.timeIntervalSinceNow * 1000))ms\nTimes: [\(timelineEntries.map({ shortTimeFormatter.string(from:$0.date)}).joined(separator:", "))]")
    
    let timeline = Timeline(entries: timelineEntries, policy: .atEnd)
    
    TimelineProvider.cachedTimelines[identifier] = (timeline: timeline, timestamp: now)
    
    return timeline
    
  }
  
  private func fetchWeather() async -> Weather? {
    do {
      return try await weatherManager.fetchWeather()
    } catch {
      print("Weather Error: \(error.localizedDescription)")
    }
    return nil
  }
  
  private func fetchReminders(configuration: ConfigurationIntent, startDate: Date, endDate: Date) async -> [EventEntry] {
    guard configuration.content == .reminders else { return [] }
    
    let reminderIDs = configuration.reminders.map({$0.id})
    let calendars: [EKCalendar] = reminderIDs.compactMap({eventStore.calendar(withIdentifier: $0)})
    let reminderPredicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)
    
    print("Fetching Reminders")
    if let reminders = try? await eventStore.fetchRemindersAsync(predicate:reminderPredicate) {
      let sortedReminders = reminders
        .filter { $0.dueDateComponents?.date ?? .distantPast < endDate }
        .sorted(by: compareReminders)
      var reminderEntries: [EventEntry] = []
      if (calendars.count != 0) {
        reminderEntries.append(EventEntry(type:"header", title:calendars.map({$0.title}).joined(separator: ", ")))
      }
      reminderEntries.append(contentsOf: sortedReminders.map { EventEntry(id: $0.calendarItemIdentifier, item: $0) })
      return reminderEntries
    }
    return []
  }
  
  private func fetchScheduledReminders(configuration: ConfigurationIntent, startDate: Date, endDate: Date) async -> [EKReminder] {
    guard configuration.content == .reminders || configuration.content == .calendar else { return [] }

    print("Fetching Scheduled Reminders")
    do {
      return try await eventStore.fetchRemindersAsync(predicate: eventStore.predicateForIncompleteReminders(
        withDueDateStarting: Calendar.current.startOfDay(for: startDate),
        ending: endDate, calendars: nil))
    } catch {
      print("Reminder Error: \(error)")
      return []
    }
  }
  
  private func fetchEvents(configuration: ConfigurationIntent, startDate: Date, endDate: Date) async -> [EKEvent] {
    guard configuration.content == .calendar else { return [] }
    
    let calendarIDs = configuration.calendars.map({$0.id})
    let calendars: [EKCalendar] = calendarIDs.compactMap({eventStore.calendar(withIdentifier: $0)})
    let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
    
    print("Fetching Events")
    return eventStore.events(matching: predicate)
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
  
  //#if os(watchOS)
  //  @available(watchOS 11.0, *)
  //  func relevances() async -> WidgetRelevances<ConfigurationIntent> {
  //    // Generate a list containing the contexts this widget is relevant in.
  //    return WidgetRelevances([
  //      //        WidgetRelevance(context: .someContext, weight: 1),
  //    ])
  //  }
  //#endif
  
  
  
  static let sampleEntry: EventEntry = EventEntry(id: "1", type: "", title: "",  url: nil, suffix: "", item: nil)
  
  
}
