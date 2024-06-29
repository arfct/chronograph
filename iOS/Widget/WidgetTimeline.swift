import WidgetKit
import SwiftUI
import EventKit

struct TXTimelineProvider: AppIntentTimelineProvider {

  @AppStorage("state") private var state = false
  
  
  func placeholder(in context: Context) -> CalendarTimelineEntry {
    
    let config = ConfigurationIntent()
    config.content = .calendar
    config.calendars = []

//    let timeline =  timeline(for:config)
    let item = EKEvent()
    item.title = "Calendar Event"
    item.startDate = Date()
    
    return CalendarTimelineEntry(date: Date(), configuration: ConfigurationIntent(), items: [
      
      EventEntry(id: "", header: "Today"),
      
      EventEntry(id: "", item: item)
    ])
  }
  
  func snapshot(for configuration: ConfigurationIntent, in context: Context) async -> CalendarTimelineEntry {
    let timeline = await timeline(for:configuration)
    return timeline.entries[0]
  }
  
  func timeline(for configuration: ConfigurationIntent, in context: Context) async -> Timeline<CalendarTimelineEntry> {
    return await timeline(for:configuration)
  }
  
  func timeline(for configuration: ConfigurationIntent) async -> Timeline<CalendarTimelineEntry> {
    
    var error: String?
    let content = configuration.content
    let now = Date()
    let reloadDate = Calendar.current.date(byAdding: .minute,
                                           value: 15,
                                           to: now)!
    
    let ids = configuration.calendars.map({ $0.id })
    var items: [EventEntry] = []
    
    if (content == .reminders || content == .both) {
      if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
        items.append(contentsOf: await fetchReminders(configuration:configuration)!)
      } else {
        error = "Reminders access denied"
      }
    }
    
    if (content == .calendar || content == .both) {
      if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
        items.append(contentsOf: await fetchEvents(calendarIDs: ids, configuration: configuration)!)
      } else {
        error = "Calendar access denied"
      }
    }
    
    if (error != nil) {
      return Timeline(entries: [
        CalendarTimelineEntry(date: now, configuration: configuration, items: [EventEntry(id: "error", header: "Enable access in settings", url: URL(string: "settings:"))])
      ], policy: .after(reloadDate))
    }
    
    let entry = CalendarTimelineEntry(date: now,
                                      configuration: configuration,
                                      items: items)
    let entries = [entry]
    return Timeline(entries: entries, policy: .after(reloadDate))
    
    
    }
    
  
  
  func recommendations() -> [AppIntentRecommendation<ConfigurationIntent>] {
    
    var recommendations: [AppIntentRecommendation<ConfigurationIntent>]  = []
    
    let calendar = ConfigurationIntent()
    calendar.showColors = true
    calendar.content = .calendar
    recommendations.append(AppIntentRecommendation(intent:calendar, description: "Events"))
    
    let calendar2 = ConfigurationIntent()
    calendar2.showColors = true
    calendar2.content = .reminders
    calendar2.pageOffset = 1
    recommendations.append(AppIntentRecommendation(intent:calendar2, description: "Events page 2"))

    let reminders = ConfigurationIntent()
    reminders.showColors = true
    reminders.pageOffset = 1
    recommendations.append(AppIntentRecommendation(intent:reminders, description: "Reminders"))

    
    return recommendations
  }
  

//    func relevances() async -> WidgetRelevances<ConfigurationIntent> {
//      // Generate a list containing the contexts this widget is relevant in.
//      WidgetRelevances([
//        WidgetRelevance(context: ., weight: 1),
//      ])
//    }
//
}

struct CalendarTimelineEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationIntent
  let state: Bool = false
  let items: [EventEntry]
}
