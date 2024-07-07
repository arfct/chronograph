import SwiftUI
import WidgetKit
import AppIntents

struct WidgetPreviewView: View {
  var config: ConfigurationIntent
  
  @State private var timeline: Timeline<CalendarTimelineEntry>?
    var body: some View {
      VStack {
        if let entry = timeline?.entries.first {
          TextWidgetView(entry: entry)
        } else {
          Text("Loading...")
        }
      }
      .task {
        timeline = await TimelineProvider().timeline(for: config)
      }
     
    }
}

#Preview {
  let config = ConfigurationIntent()
  let _ = {
    config.content = .both
    config.calendars = []
    config.fontStyle = .normal
    config.backgroundColor = ""
    config.fullBleed = true
  }
  
  WidgetPreviewView(config: config)
}
