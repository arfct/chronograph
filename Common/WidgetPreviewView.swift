import SwiftUI
import WidgetKit
import AppIntents
import EventKit
struct WidgetPreviewView: View {
  var config: ConfigurationIntent
  let kind: String = "calendar"
  var eventStore = EKEventStore()
  func reloadTimeline()  {
    Task {
      timeline = await TimelineProvider(kind:kind).timeline(for: config)
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
    .padding(28)
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
  VStack {
    WidgetPreviewView(config: ConfigurationIntent.calendarConfig)
      .frame(minWidth:160, maxHeight: 160)
      .background(.regularMaterial)
      .padding()
    WidgetPreviewView(config: ConfigurationIntent.remindersConfig)
      .frame(minWidth:160, maxHeight: 160)
      .background(.regularMaterial)
      .padding()
    WidgetPreviewView(config: ConfigurationIntent.timezonesConfig)
      .frame(minWidth:160, maxHeight: 160)
      .background(.regularMaterial)
      .padding()
    WidgetPreviewView(config: ConfigurationIntent.weatherConfig)
      .frame(minWidth:160, maxHeight: 160)
      .background(.regularMaterial)
      .padding()
  }.background(.tertiary)
}
