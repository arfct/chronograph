import WidgetKit
import SwiftUI

import AppIntents


// MARK: Widget

struct ClockWidget: Widget {
  let kind: String = "clock"
  
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: ClockConfigurationIntent.self, provider: Provider()) { entry in
      ClockWidgetView(entry: entry)
//        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    .contentMarginsDisabled()
    .configurationDisplayName("StandBy Clock")
    .description("Minimal Clock that only shows hours overnight")
    .supportedFamilies([
      .systemSmall,
    ])
  }
}

extension ClockConfigurationIntent {
  fileprivate static var smiley: ClockConfigurationIntent {
    let intent = ClockConfigurationIntent()
    return intent
  }
  
}

// MARK: Configuration

enum ClockStyle: String, AppEnum {
  case time, timeAdaptive, hour, minute, second
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Time Style"
  static var caseDisplayRepresentations: [ClockStyle : DisplayRepresentation] = [
    .time: "Time (simple)",
    .timeAdaptive: "Time (hide minutes overnight)",
    .hour: "Hour only",
    .minute: "Minutes only",
    .second: "Seconds only"
  ]
}

struct ClockConfigurationIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource { "Configuration" }
  static var description: IntentDescription { "Vermillion Widget" }
  
  @Parameter(title: "View", default: .timeAdaptive)
  var clockStyle: ClockStyle

  @Parameter(title: "Foreground (Hex)", default: "")
  var accentColor: String
  
  @Parameter(title: "Background (Hex)", default: "")
  var backgroundColor: String

  @Parameter(title: "Font Style", default: .normal)
   var fontStyle: FontStyle
}

// MARK: Timeline

struct Provider: AppIntentTimelineProvider {
  typealias Entry = ClockEntry
  typealias Intent = ClockConfigurationIntent
  
  func recommendations() -> [AppIntentRecommendation<ClockConfigurationIntent>] {
    
    let recommendations: [AppIntentRecommendation<ClockConfigurationIntent>]  = [
      AppIntentRecommendation(intent:ClockConfigurationIntent(), description: "Vermillion"),
      
    ]
    return recommendations
  }
  
  func placeholder(in context: Context) -> ClockEntry {
    ClockEntry(date: Date(), configuration: ClockConfigurationIntent())
  }
  
  func snapshot(for configuration: ClockConfigurationIntent, in context: Context) async -> ClockEntry {
    ClockEntry(date: Date(), configuration: configuration)
  }
  
  func timeline(for configuration: ClockConfigurationIntent, in context: Context) async -> Timeline<ClockEntry> {
    var timelineEntries: [ClockEntry] = []
    let calendar = Calendar.current
    let now = Date()
    
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
    if let fullMinuteDate = calendar.date(from: components) {
      for minuteOffset in 0 ..< 60 {
        
        guard let entryDate = calendar.date(byAdding: .minute,
                                      value: minuteOffset,
                                            to: fullMinuteDate) else { continue }
    
        timelineEntries.append(ClockEntry(date: entryDate, configuration: configuration))
      }
    }
    
    return Timeline(entries: timelineEntries, policy: .atEnd)
  }
}

struct ClockEntry: TimelineEntry {
  let date: Date
  let configuration: ClockConfigurationIntent
}

let hourFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "h"
  return formatter
}()

let minuteFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "mm"
  return formatter
}()

let secondFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "ss"
  return formatter
}()

private func heightForFontSize(size: CGFloat) -> CGFloat {
  let font = UIFont.systemFont(ofSize: size)
  return font.capHeight
}


// MARK: View

struct ClockWidgetView : View {
  var entry: Provider.Entry
  @State private var visibleItemCount: Int = 20
  @State private var extraSpace: CGFloat = 0.0
  @Environment(\.widgetFamily) var widgetFamily
  @Environment(\.showsWidgetContainerBackground) var showsWidgetContainerBackground
  @Environment(\.widgetRenderingMode) var widgetRenderingMode
  
  var body: some View {
    let style = entry.configuration.clockStyle
    let now = entry.date
    let hour = Calendar.current.dateComponents([.hour], from: now)

    let showHour = style == .hour || style == .time || style == .timeAdaptive
    let showMinute = style == .minute || style == .time || style == .timeAdaptive && hour.hour! > 6
    let showBoth = showHour && showMinute
    
    let accentColor = Color.withHex(entry.configuration.accentColor) ?? .primary
    let backgroundColor = Color.withHex(entry.configuration.backgroundColor) ?? .clear
    
    GeometryReader { container in
      let fontSize = container.size.width * 0.85
      let hourFontSize = showBoth ? fontSize * 0.7 : fontSize
      let minuteFontSize = showBoth ? hourFontSize * 0.5 : fontSize
      
      
       if (style == .second) {
         HStack(alignment: .center) {
           
           Text(now, style: .timer)
             .contentTransition(.numericText())
             .font(.system(size: minuteFontSize, design:.rounded).monospacedDigit().weight(.thin))
             .foregroundStyle(accentColor)
             .frame(maxWidth:container.size.width * 2, maxHeight: heightForFontSize(size: minuteFontSize), alignment: .leading)
             .multilineTextAlignment(.trailing)
             .fixedSize()

         }
         .frame(maxWidth:container.size.width, maxHeight: .infinity, alignment: .trailing)
         .clipped()
       }
      
      HStack(alignment: .center) {
        HStack(alignment: .top, spacing:0 ) {
          
          if (showHour) {
            Text(now, formatter: hourFormatter)
              .contentTransition(.numericText())
              .font(.system(size: hourFontSize, design:.rounded).weight(.thin))
              .foregroundStyle(accentColor)
              .frame(height: heightForFontSize(size: hourFontSize))
          }
          
          if (showMinute) {
            Text(now, formatter: style == .second ? secondFormatter : minuteFormatter)
              .contentTransition(.numericText())
              .font(.system(size: minuteFontSize, design:.rounded).weight(showBoth ? .regular  : .thin))
              .frame(height: heightForFontSize(size: minuteFontSize))
              .foregroundStyle(showBoth ? .secondary : accentColor)
              .widgetAccentable(showBoth)
          }
        }
      }
//      .background(widgetRenderingMode == .accented ? .clear : backgroundColor)
      .frame(maxWidth: container.size.width, maxHeight: container.size.height, alignment: .center)

      
    }
    
    
    .containerBackground(widgetRenderingMode == .accented ? .clear : backgroundColor, for: .widget)
      .padding(showsWidgetContainerBackground ? 10 : 0)
//      .background(ContainerRelativeShape().inset(by:8)
//                  
//        .fill(Gradient(stops: [
//          .init(color: .white.opacity(0.2), location: 0.0),
//          .init(color: .white.opacity(0.0), location: 0.5)
//          ,
//          .init(color: .white.opacity(0.2), location: 0.5),
//          .init(color: .white.opacity(0.05), location: 1.0)
//        ])))
  }
}



// MARK: Preview

#Preview(as: .systemSmall) {
  ClockWidget()
} timeline: {
  ClockEntry(date: .now, configuration: ClockConfigurationIntent())
}
