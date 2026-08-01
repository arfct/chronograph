import SwiftUI
import WidgetKit
import AppIntents
import EventKit
struct WidgetPreviewView: View {
  var config: WidgetConfig
  let kind: String = "calendar"
  var eventStore = EKEventStore()
  func reloadTimeline()  {
    Task {
      timeline = await TimelineProvider(kind:kind).timeline(config: config)
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
    .clipped()
    .frame(maxWidth:.infinity)
    
#if !os(watchOS)
    .padding(28)
#endif
    
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
    .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { change in
      reloadTimeline()
      print("Updating due to UserDefaults change \(change.userInfo)")
    }
    .task {
      reloadTimeline()
    }
    
  }
}

#Preview("Calendar") {
  var config = WidgetConfig.combo
  var testConfig: WidgetConfig {
    var c = WidgetConfig.calendar
    c.calendars = []
    c.fontStyle = .normal
    c.fontSize = .tiny
    c.accentColor = "#FF5500"
    c.features = [.allDayEvents, .timeBars, .weather]
    c.viewOptions = [.showColors]
    return c
  }

  WidgetPreviewView(config: testConfig)
    .frame(minWidth:240, maxHeight: 555)
    .padding()

}

#Preview("Reminders", traits: .fixedLayout(width: 160, height: 160)) {
  VStack {
    WidgetPreviewView(config: .calendar)
      .frame(minWidth:160, maxHeight: 160)
      .background(.regularMaterial)
      .padding()
    WidgetPreviewView(config: .reminders)
      .frame(minWidth:160, maxHeight: 160)
      .background(.regularMaterial)
      .padding()
    WidgetPreviewView(config: .timezones)
      .frame(minWidth:160, maxHeight: 160)
      .background(.regularMaterial)
      .padding()
    WidgetPreviewView(config: .weatherCurrent)
      .frame(minWidth:160, maxHeight: 160)
      .background(.regularMaterial)
      .padding()
  }.background(.tertiary)
}
