import WidgetKit
import SwiftUI
import AppIntents
import EventKit
import Contacts
import WeatherKit

struct CalendarTimelineEntry: TimelineEntry {
  let date: Date
  let config: WidgetConfig
  let state: Bool = false
  var reminders: [EventEntry] = []
  var events: [EventEntry] = []
  var weather: Weather?
  var timezones: [EventEntry] = []
  let context: TimelineProviderContext?
}


struct TimelineEngine {

  @AppStorage("state")
  private var state = false

  @AppStorage(Keys.enabledCalendars, store: UserDefaults(suiteName: Keys.suiteName))
  private var selectedCalendarIds: [String] = []

  @AppStorage(Keys.enabledReminders, store: UserDefaults(suiteName: Keys.suiteName))
  private var selectedReminderIds: [String] = []

  var weatherManager = WeatherLocationManager()
  var eventStore = EKEventStore()
  func placeholderEntry(context: TimelineProviderContext?) -> CalendarTimelineEntry {

    let item = EKEvent(eventStore: eventStore)
    item.title = "Calendar Event"
    item.startDate = Date()

    return CalendarTimelineEntry(date: Date(), config: WidgetConfig.calendar, events: [
      EventEntry(id: "", title: "Today"),
      EventEntry(id: "", item: item),
      EventEntry(id: "", item: item),
      EventEntry(id: "", item: item),
      EventEntry(id: "", title: "Today"),
      EventEntry(id: "", item: item),
      EventEntry(id: "", item: item),

    ], context: context)

  }

  // MARK: Timeline

  private func buildTimezoneEntries(config: WidgetConfig) -> [EventEntry] {
    var timezoneEntries: [EventEntry] = []

    if config.content == .timezones {
      let calendar = Calendar.current
      let now = Date()

      var timezones = config.timezones.compactMap({TimeZone(identifier: $0.id)})
      timezones.sort { a, b in
        a.secondsFromGMT() < b.secondsFromGMT()
      }
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

  /// The big `if configuration.content == .calendar` loop: headers, dedup, conflicts, free
  /// time, note/URL/meeting extraction. Also consumes `weather` for day-header forecasts —
  /// this cross-content dependency is why there is one engine and one provider.
  private func buildCalendarEntries(config: WidgetConfig,
                                    items: [EKCalendarItem],
                                    weather: Weather?,
                                    renderDate: Date,
                                    context: TimelineProviderContext?) -> [EventEntry] {
    let calendar = Calendar.current
    let showAllDay = config.features.contains(.allDayEvents)
    let showMultiDay = config.features.contains(.multiDayEvents)

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEEE"

    var calendarEntries: [EventEntry] = []

    let distantPastEvent = EKEvent.init(eventStore: eventStore)
    distantPastEvent.startDate = .distantPast
    var previousItem: EKCalendarItem?
    var headerIndex = -1

    for (i, item) in items.enumerated() {

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
      } else if (config.features.contains(.freeTime)){
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

    #if os(iOS) || os(watchOS)
        if context?.family == .accessoryRectangular
            && calendarEntries.first?.allDayItems?.count == 0 {
          calendarEntries.removeFirst()
        }
    #endif

    return calendarEntries
  }

  /// Current `fetchReminders` result shaping (header row + sorted rows).
  private func buildReminderEntries(config: WidgetConfig, reminders: [EKReminder]) -> [EventEntry] {
    guard config.content == .reminders else { return [] }

    var reminderIDs = config.reminderLists.map({$0.id})
    if (reminderIDs.count == 0) {
      reminderIDs = selectedReminderIds
    }
    let calendars: [EKCalendar] = reminderIDs.compactMap({eventStore.calendar(withIdentifier: $0)})

    let sortedReminders = reminders.sorted(by: compareReminders)
    var reminderEntries: [EventEntry] = []
    if (calendars.count != 0) {
      reminderEntries.append(EventEntry(type:"header", title:calendars.map({$0.title}).joined(separator: ", ")))
    }
    reminderEntries.append(contentsOf: sortedReminders.map { EventEntry(id: $0.calendarItemIdentifier, item: $0) })
    return reminderEntries
  }

  private func upcomingWeatherEntries(weather: Weather, location: String?) -> [EventEntry] {
    var entries: [EventEntry] = []

    let now = Date()
    let in24Hr = Date().addingTimeInterval(24 * 60 * 60)
    let forecast = weather.currentWeather

    let eventEntry = EventEntry(type: "weather",
                                title:"Weather",
                                startDate: weather.currentWeather.date,
                                endDate: weather.currentWeather.date.addingTimeInterval(3600),
                                weather: weather
    )
    entries.append(eventEntry)

    if let location = location {
      entries.append(EventEntry(type:"header", title:location))
    }

//      UpcomingWeatherRow(date: Date(), temp: forecast.apparentTemperature, image: Image(systemName:forecast.symbolName), description: forecast.condition.description, config: config)

    let todayForecast = weather.dailyForecast.first
    let tommorowForecast = weather.dailyForecast.first { $0.date > Date()}

    let _ = print (weather.hourlyForecast.map({$0.date}))
    let rainForecast = weather.hourlyForecast.first { hour in
      hour.precipitationChance > 0.5 && hour.date > Date()
      // TODO: Also check minute forecasts.
    }

    let sunrise = weather.dailyForecast.first?.sun.sunrise
    let sunriseForecast = weather.hourlyForecast.first { hour in
      hour.isDaylight
    }

    if let forecast = sunriseForecast {
      EventEntry(type: "weather",
                 title:"Sunrise",
                 startDate: forecast.date,
                 endDate: forecast.date.addingTimeInterval(3600),
                 hourForecast: forecast
                )
    }



    if let highTempTime = todayForecast?.highTemperatureTime,
       let highTemp = todayForecast?.highTemperature {
      let hourForecast = weather.hourlyForecast.last(where: {$0.date < highTempTime})
      entries.append(
        EventEntry(type: "weather",
                   title:"High",
                   startDate: highTempTime,
                   endDate: highTempTime.addingTimeInterval(3600),
                   hourForecast: hourForecast
                  )
      )



    }

    if let lowTempTime = todayForecast?.lowTemperatureTime,
       let lowTemp = todayForecast?.lowTemperature {
      let hourForecast = weather.hourlyForecast.last(where: {$0.date < lowTempTime})
      entries.append(
        EventEntry(type: "weather",
                   title:"Low",
                   startDate: lowTempTime,
                   endDate: lowTempTime.addingTimeInterval(3600),
                   hourForecast: hourForecast
                  )
      )

    }

    if let sunset = weather.dailyForecast.first(where: { $0.sun.sunset ?? .distantPast > Date() })?.sun.sunset,
       let sunsetForecast = weather.hourlyForecast.last(where: { $0.date < sunset }) {
      entries.append(
        EventEntry(type: "weather",
                   title:"Sunset",
                   startDate: sunset,
                   endDate: sunset.addingTimeInterval(3600),
                   hourForecast: sunsetForecast
                  )
      )
    }

    if let sunrise = weather.dailyForecast.first(where: { $0.sun.sunrise ?? .distantPast > Date() })?.sun.sunrise,
       let sunsetForecast = weather.hourlyForecast.last(where: { $0.date < sunrise }) {
      entries.append(
        EventEntry(type: "weather",
                   title:"Sunrise",
                   startDate: sunrise,
                   endDate: sunrise.addingTimeInterval(3600),
                   hourForecast: sunsetForecast
                  )
      )
    }

    if let night = weather.dailyForecast.first?.sun.astronomicalDusk,
       let nightForecast = weather.hourlyForecast.last(where: { $0.date < night }) {
      entries.append(
        EventEntry(type: "weather",
                   title:"Night",
                   startDate: night,
                   endDate: night.addingTimeInterval(3600),
                   hourForecast: nightForecast
                  )
      )
    }

    if let forecast = rainForecast {
      entries.append(
        EventEntry(type: "weather",
                   title:"Rain",
                   startDate: forecast.date,
                   endDate: forecast.date.addingTimeInterval(3600),
                   hourForecast: forecast
                  )
      )
    } else {

    }


    entries.sort(by: { $0.startDate ?? .distantPast < $1.startDate ?? .distantPast })
    print("entries", entries.map({$0.title}))
    return entries
  }

  /// Current weather-style switch plus `upcomingWeatherEntries`.
  private func buildWeatherEntries(config: WidgetConfig,
                                   weather: Weather,
                                   location: String?) -> [EventEntry] {
    var calendarEntries: [EventEntry] = []

    if config.weatherStyle == .current {
      calendarEntries.append(contentsOf:upcomingWeatherEntries(weather: weather, location:location))

    } else if config.weatherStyle == .daily {
      let dailyForecast = weather.dailyForecast

      for forecast in dailyForecast.forecast.prefix(10) {
        let eventEntry = EventEntry(type: "weather",
                                    title:"Weather",
                                    startDate: forecast.date,
                                    endDate: forecast.date.addingTimeInterval(3600),
                                    dayForecast: forecast
        )
        calendarEntries.append(eventEntry)
      }
    } else if config.weatherStyle == .hourly {

        let currentWeather = weather.currentWeather
      let hourlyForecast = weather.hourlyForecast

      for forecast in hourlyForecast.forecast.filter({$0.date >= Date()}).prefix(24) {
        let eventEntry = EventEntry(type: "weather",
                                    title:nil,
                                    startDate: forecast.date,
                                    endDate: forecast.date.addingTimeInterval(3600),
                                    hourForecast: forecast

        )
        calendarEntries.append(eventEntry)
      }
    }

    return calendarEntries
  }

  func timeline(config: WidgetConfig, context: TimelineProviderContext? = nil) async -> Timeline<CalendarTimelineEntry> {

    let identifier = "\(context?.family.description ?? "none").\(config.content).\(String(reflecting: config))"

    let now = Date()

   print("\nMaking timeline for \(identifier)" )

    let calendar = Calendar.current
    let startDate: Date
      startDate = Date()
    let endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!

    let showWeather = config.features.contains(.weather) || config.content == .weather

    let timezoneEntries = buildTimezoneEntries(config: config)


    let (weather, location) = (showWeather ? await fetchWeather() : nil) ?? (nil, nil)

    let fetchedReminders = await fetchReminders(config: config, startDate: startDate, endDate: endDate)
    var reminderEntries = buildReminderEntries(config: config, reminders: fetchedReminders)
    let scheduledReminders = await fetchScheduledReminders(config: config, startDate: startDate, endDate: endDate)

    reminderEntries.removeAll(where: { item in
        if let reminder = item.item as? EKReminder {
            return scheduledReminders.firstIndex(of: reminder) != nil
        }
        return false
    })

    let events = await fetchEvents(config: config, startDate: startDate, endDate: endDate)

    var calendarItems: [EKCalendarItem] = []
    calendarItems.append(contentsOf: scheduledReminders)
    calendarItems.append(contentsOf: events)

    calendarItems = calendarItems.sorted(by: compareCalendarItems)

    let reloadDate = calendar.date(byAdding: .minute,
                                   value: 15,
                                   to: now)!


    var errors: [String] = []

    let remindersError = (config.content == .reminders || config.content == .calendar) && EKEventStore.authorizationStatus(for: .reminder) != .fullAccess
    let eventsError = (config.content == .calendar) && EKEventStore.authorizationStatus(for: .event) != .fullAccess

    if (remindersError) {
      errors.append("Enable access to reminders in settings")
    }

    if (eventsError) {
      errors.append("Enable access to calendar in settings")
    }

    // MARK: Errors
    if (errors.count > 0) {
      return Timeline(entries: [
        CalendarTimelineEntry(date: now, config: config,
                              events: errors.map({ error in
                                EventEntry(type: error, title: error, url: URL(string: "settings:"))
                              }), context: context)
      ], policy: .after(reloadDate))
    }

    // MARK: Creating timeline entries

    let debug = false
    var timelineEntries: [CalendarTimelineEntry] = []
    var calendarEntries: [EventEntry] = []

    let renderDate = now

    if (config.content == .calendar) {
      calendarEntries = buildCalendarEntries(config: config, items: calendarItems, weather: weather, renderDate: renderDate, context: context)
    }

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

    if let weather = weather, config.content == .weather {
      calendarEntries.append(contentsOf: buildWeatherEntries(config: config, weather: weather, location: location))
    }


    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)

    let fullMinuteDate = calendar.date(from: components)!

    for minuteOffset in 0 ..< 15 {
      let renderDate = calendar.date(byAdding: .minute,
                                     value: debug ? 60 * 18 + minuteOffset * 30 : minuteOffset, to: fullMinuteDate)!
      let entryDate = calendar.date(byAdding: debug ? .second : .minute,
                                    value: minuteOffset,
                                    to: fullMinuteDate)!

      let timelineEntry = CalendarTimelineEntry(date: entryDate,
                                                config: config,
                                                reminders: reminderEntries,
                                                events: calendarEntries,
                                                weather: weather,
                                                timezones: timezoneEntries,
                                                context: context)
      timelineEntries.append(timelineEntry)

    }
    print ("Returning timeline in \(round(-now.timeIntervalSinceNow * 1000))ms\nTimes: [\(timelineEntries.map({ shortTimeFormatter.string(from:$0.date)}).joined(separator:", "))]")

    let timeline = Timeline(entries: timelineEntries, policy: .atEnd)

    TimelineEngine.cachedTimelines[identifier] = (timeline: timeline, timestamp: now)

    return timeline

  }

  private func fetchWeather() async -> (Weather, String?)? {
    do {
      return try await weatherManager.fetchWeather()
    } catch {
      print("Weather Error: \(error.localizedDescription)")
    }
    return nil
  }

  private func fetchReminders(config: WidgetConfig, startDate: Date, endDate: Date) async -> [EKReminder] {
    guard config.content == .reminders else { return [] }

    var reminderIDs = config.reminderLists.map({$0.id})
    if (reminderIDs.count == 0) {
      reminderIDs = selectedReminderIds
      print("REMINDERS \(reminderIDs)")
    }
    let calendars: [EKCalendar] = reminderIDs.compactMap({eventStore.calendar(withIdentifier: $0)})
    let reminderPredicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)

    print("Fetching Reminders")
    if let reminders = try? await eventStore.fetchRemindersAsync(predicate:reminderPredicate) {
      return reminders.filter { $0.dueDateComponents?.date ?? .distantPast < endDate }
    }
    return []
  }

  private func fetchScheduledReminders(config: WidgetConfig, startDate: Date, endDate: Date) async -> [EKReminder] {
    guard config.content == .reminders || config.content == .calendar else { return [] }

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

  private func fetchEvents(config: WidgetConfig, startDate: Date, endDate: Date) async -> [EKEvent] {
    guard config.content == .calendar else { return [] }

    var calendarIDs = config.calendars.map({$0.id})
    if (calendarIDs.count == 0) {
      calendarIDs = selectedCalendarIds
    }

    let calendars: [EKCalendar] = calendarIDs.compactMap({eventStore.calendar(withIdentifier: $0)})

    print("Getting Calendars: \(calendars.map(\.title))")

    let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)

    let events = eventStore.events(matching: predicate)
    print("Fetching Events", events)
    return events
  }

}

protocol ChronographWidgetIntent: WidgetConfigurationIntent {
  var widgetConfig: WidgetConfig { get }
  static var recommendedIntents: [(intent: Self, description: String)] { get }
}

struct ChronographTimelineProvider<Intent: ChronographWidgetIntent>: AppIntentTimelineProvider {
  let engine = TimelineEngine()

  func placeholder(in context: Context) -> CalendarTimelineEntry {
    engine.placeholderEntry(context: context)
  }

  func snapshot(for configuration: Intent, in context: Context) async -> CalendarTimelineEntry {
    let timeline = await engine.timeline(config: configuration.widgetConfig, context: context)
    return timeline.entries.first!
  }

  func timeline(for configuration: Intent, in context: Context) async -> Timeline<CalendarTimelineEntry> {
    await engine.timeline(config: configuration.widgetConfig, context: context)
  }

  func recommendations() -> [AppIntentRecommendation<Intent>] {
    Intent.recommendedIntents.map { AppIntentRecommendation(intent: $0.intent, description: $0.description) }
  }
}
