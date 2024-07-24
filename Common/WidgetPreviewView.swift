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
          TextWidgetView(entry: entry)
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

#Preview(traits: .fixedLayout(width: 1000, height: 640)) {
  WidgetPreviewView(config: ConfigurationIntent.comboConfig)
    .frame(minWidth:320, maxHeight: .infinity)
    .border(.white)
    .padding()
  WidgetPreviewView(config: ConfigurationIntent.remindersConfig)
    .frame(minWidth:320, maxHeight: .infinity)
    .border(.white)
    .padding()
}
