//
//  WidgetPreviewView.swift
//  txet
//
//  Created by Nicholas Jitkoff on 6/20/24.
//

import SwiftUI
import WidgetKit
import AppIntents

struct WidgetPreviewView: View {
  var kind: String?
  @State private var timeline: Timeline<CalendarTimelineEntry>?
    var body: some View {
      VStack {
        if let entry = timeline?.entries.first {
          TextWidgetView(entry: entry)
        } else {
          Text("Loading...")
        }
      }
      .padding(.vertical, 10)
      .task {
        let config = ConfigurationIntent()
        config.content = .both
        config.calendars = []
        config.fontStyle = .normal
        config.backgroundColor = ""
        config.fullBleed = false

        // let context = TimelineProviderContext()
        timeline = await TXTimelineProvider(kind: kind ?? "calendar").timeline(for: config)
      }
     
    }
}

#Preview {
    WidgetPreviewView()
}
