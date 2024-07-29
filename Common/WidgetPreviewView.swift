import SwiftUI
import WidgetKit
import AppIntents
import EventKit
struct WidgetPreviewView: View {
  var config: ConfigurationIntent
  var eventStore = EKEventStore()
  func reloadTimeline()  {
    Task {
      timeline = await TimelineProvider().timeline(for: config)
    }
  }
  @State private var timeline: Timeline<CalendarTimelineEntry>?
    var body: some View {
      VStack {
        if let entry = timeline?.entries.first {
          ChronographWidgetView(entry: entry)
        } else {
          Text("Loading...")
        }
      }.onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: eventStore)) {
        (output) in
        
        if output.userInfo?["EKEventStoreCalendarDataChangedUserInfoKey"] as? Int == 1  &&  config.content != .reminders {
          reloadTimeline()
          print("Updating Calendar")
        }
        if output.userInfo?["EKEventStoreRemindersDataChangedUserInfoKey"] as? Int == 1 && config.content != .calendar {
          reloadTimeline()
          print("Updating Reminders")
        }
        
        WidgetCenter.shared.reloadAllTimelines()
      }
      .task {
        reloadTimeline() 
      }
     
    }
}


#Preview("Calendar") {
  var config = ConfigurationIntent.comboConfig
  var testConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .both
    config.calendars = []
    config.fontStyle = .normal
    config.fontSize = .tiny
    config.accentColor = "#FF5500"
    config.features = [.allDayEvents, .calendarColors]
    return config
  }
 
  WidgetPreviewView(config: testConfig)
    .frame(minWidth:240, maxHeight: 555)
    .border(.black)
    .padding()

}

#Preview("Reminders", traits: .fixedLayout(width: 160, height: 160)) {
  WidgetPreviewView(config: ConfigurationIntent.remindersConfig)
    .frame(minWidth:160, maxHeight: 160)
    .border(.white)
    .padding()
}
