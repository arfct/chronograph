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
      ScrollView {
        if let entry = timeline?.entries.first {
          ChronographWidgetView(entry: entry)
        } else {
          Text("Loading...")
        }
      }
      .frame(maxWidth:.infinity)
//      .padding(28)
//      .background(.background)
//      .clipShape(RoundedRectangle(cornerRadius: 28))
//      .overlay(RoundedRectangle(cornerRadius: 28).stroke(.tertiary.opacity(0.8), lineWidth: 1))
//      .shadow(color: .black.opacity(0.05), radius: 10.0, x: 0.0, y:10.0)
//      .shadow(color: .black.opacity(0.05), radius: 10.0, x: 0.0, y:10.0)
//      .padding()
      .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: eventStore)) {
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
    config.content = .calendar
    config.calendars = []
    config.fontStyle = .normal
    config.fontSize = .tiny
    config.accentColor = "#FF5500"
    config.features = [.allDayEvents, .timeBars, .weather]
    config.viewOptions = [.showColors]
    return config
  }
 
  WidgetPreviewView(config: testConfig)
    .frame(minWidth:240, maxHeight: 555)
    .padding()

}

#Preview("Reminders", traits: .fixedLayout(width: 160, height: 160)) {
  WidgetPreviewView(config: ConfigurationIntent.remindersConfig)
    .frame(minWidth:160, maxHeight: 160)
    .border(.white)
    .padding()
}
