import WidgetKit
import SwiftUI
import EventKit

struct TXTimelineProvider: AppIntentTimelineProvider {
  let kind: String
  @AppStorage("state") private var state = false
  
  
  func placeholder(in context: Context) -> CalendarTimelineEntry {
    CalendarTimelineEntry(date: Date(), configuration: ConfigurationIntent(), items: [])
  }
  
  func snapshot(for configuration: ConfigurationIntent, in context: Context) async -> CalendarTimelineEntry {
    CalendarTimelineEntry(date: Date(), configuration: configuration, items: [])
  }
  
  func timeline(for configuration: ConfigurationIntent, in context: Context) async -> Timeline<CalendarTimelineEntry> {
    return await timeline(for: configuration)
  }
  
  func timeline(for configuration: ConfigurationIntent) async -> Timeline<CalendarTimelineEntry> {
    let getReminders = kind == "reminders"
    let authorized = EKEventStore.authorizationStatus(for: getReminders ? .reminder : .event) == .fullAccess
    
    let now = Date()
    let reloadDate = Calendar.current.date(byAdding: .minute,
                                           value: 15,
                                           to: now)!
    if (authorized) {
      let ids = configuration.calendars.map({ $0.id })
      
      let items = getReminders
      ? await fetchReminders()!
      : await fetchEvents(calendarIDs: ids)!
      
      let entry = CalendarTimelineEntry(date: now,
                                        configuration: configuration,
                                        items: items)
      
      let entries = [entry]
      
      return Timeline(entries: entries, policy: .after(reloadDate))
    } else {
      return Timeline(entries: [
        CalendarTimelineEntry(date: now, configuration: configuration, items: [EventEntry(id: "error", header: "Enable \(kind) access in settings", url: URL(string: "settings:"))])
        
      ], policy: .after(reloadDate))
    }
    
  }
  
  func recommendations() -> [AppIntentRecommendation<ConfigurationIntent>] {
    
    let standard = ConfigurationIntent()
    standard.showColors = true
    
    let page2 = ConfigurationIntent()
    page2.showColors = true
    page2.pageOffset = 1
    
    return [
      AppIntentRecommendation(intent:standard, description: kind),
      AppIntentRecommendation(intent: page2, description: kind + " 2")
    ]
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
