//
//  widget.swift
//  widget
//
//  Created by Nicholas Jitkoff on 6/13/24.
//

import WidgetKit
import SwiftUI
import EventKit



struct Provider: AppIntentTimelineProvider {
  let kind: String
  @AppStorage("state") private var state = false
  
  
  func placeholder(in context: Context) -> CalendarTimelineEntry {
    CalendarTimelineEntry(date: Date(), configuration: ConfigurationIntent(), items: [])
  }
  
  func snapshot(for configuration: ConfigurationIntent, in context: Context) async -> CalendarTimelineEntry {
    CalendarTimelineEntry(date: Date(), configuration: configuration, items: [])
  }
  
  func timeline(for configuration: ConfigurationIntent, in context: Context) async -> Timeline<CalendarTimelineEntry> {
    
    let ids = configuration.calendars.map({ $0.id })
    
    let items = kind == "reminders" ? await fetchReminders()! : await fetchEvents(calendarIDs: ids)!
    
    let now = Date()
    let entry = CalendarTimelineEntry(date: now,
                                      configuration: configuration,
                                      items: items)
    
    let entries = [entry]
    
    let reloadDate = Calendar.current.date(byAdding: .minute,
                                           value: 15,
                                           to: now)!
    
    return Timeline(entries: entries, policy: .after(reloadDate))
    
  }
  
  func recommendations() -> [AppIntentRecommendation<ConfigurationIntent>] {
    // Create an array with all the preconfigured widgets to show.
    [
      AppIntentRecommendation(intent: ConfigurationIntent(), description: kind)
    ]
  }
  
  //    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
  //        // Generate a list containing the contexts this widget is relevant in.
  //    }
}

struct CalendarTimelineEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationIntent
  let state: Bool = false
  let items: [EventEntry]
}

struct TextWidgetView : View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.widgetContentMargins) var margins
  @Environment(\.widgetRenderingMode) var widgetRenderingMode
  @Environment(\.showsWidgetContainerBackground) var showsWidgetContainerBackground
  @Environment(\.widgetFamily) var widgetFamily
  @AppStorage("state") private var state = false
  
  
  var entry: Provider.Entry
  
  init(entry: Provider.Entry) {
    self.entry = entry
  }
  
  private var timeFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "H:mm"
    return formatter
  }
  
  
  private var relativeDateFormatter: RelativeDateTimeFormatter {
    let formatter = RelativeDateTimeFormatter()
    formatter.dateTimeStyle = .named
    formatter.unitsStyle = .abbreviated
    return formatter
  }
  
  private func convertToSuperscript(time: String) -> String {
    let superscriptDigits = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
    let regex = try! NSRegularExpression(pattern: "([0-9]+):([0-9]{2})")
    let range = NSRange(location: 0, length: time.utf16.count)
    
    let matches = regex.matches(in: time, options: [], range: range)
    guard let match = matches.first else { return time }
    
    let hourRange = Range(match.range(at: 1), in: time)!
    let minuteRange = Range(match.range(at: 2), in: time)!
    
    let hour = String(time[hourRange])
    let minute = String(time[minuteRange]).compactMap { superscriptDigits[String($0)] }.joined()
    
    return hour + minute
  }
  
  private func getComponents(_ date: Date) -> (hour: String, minute: String) {
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.current
    
    // Format hour
    dateFormatter.dateFormat = "h"
    let hourString = dateFormatter.string(from: date)
    
    // Format minute with leading zero
    dateFormatter.dateFormat = "mm"
    let minuteString = dateFormatter.string(from: date)
    
    return (hourString, minuteString)
  }
  
  func designForFontStyle(_ style: FontStyle) -> Font.Design {
    switch style {
    case .rounded: return .rounded
    case .monospace: return .monospaced
    case .serif: return  .serif
    default: return .default
    }
  }
  
  var body: some View {
    
    let backgroundColor = entry.configuration.backgroundColor.count > 0 ?
    Color.withHex(entry.configuration.backgroundColor) : .clear;
    
#if os(watchOS)
    let accessory = true
    let heightIsLimited = true
    let widthIsLimited = true
    let isHuge = false
#else
    let accessory = (widgetFamily == .accessoryRectangular) || (widgetFamily == .systemSmall && !showsWidgetContainerBackground)
    let heightIsLimited = accessory
    let widthIsLimited = accessory || (widgetFamily == .systemSmall)
    let isHuge = widgetFamily == .systemExtraLarge
#endif
    
    let isDark = backgroundColor == .clear ? colorScheme == .dark : backgroundColor.isDark()
    
    GeometryReader { frame in
      let fullBleed = widgetFamily == .accessoryRectangular  || !showsWidgetContainerBackground ? true : entry.configuration.fullBleed
      
      //      let isStandBy = !showsWidgetContainerBackground && (widgetFamily != .accessoryRectangular)
      let hPadding = fullBleed ? margins.top / 3 : margins.leading
      let vPadding = accessory ? margins.top / 3 : margins.top / 2
      let height = frame.size.height - vPadding * 2
      
      let minLineHeight = accessory ? 18.0 : isHuge ? 48.0 : 24.0
      let lineHeight = height / ceil(height / minLineHeight)
      
      let fontSize = accessory ? 12.0 : (isHuge ? 32.0 : 16.0)
      let keyline = widthIsLimited ? 0 : fontSize * 2
      

      let design = designForFontStyle(entry.configuration.fontStyle)
      var font = Font.system(size: fontSize, design: design).width(.standard)
      var smallFont = Font.system(size: fontSize * 0.66, design: design).weight(.semibold)

      

      switch entry.configuration.fontStyle {
      case .compressed:
        let _ = font = font.width(.compressed)
        let _ = smallFont = smallFont.width(.compressed)
      case .condensed:
        let _ = font = font.width(.compressed)
        let _ = smallFont = smallFont.width(.compressed)
      default:
        let _ = font = font.width(.standard)
      }
    
      let visibleItemCount = frame.size.height > 0 ? Int((frame.size.height - vPadding) / lineHeight) : 4
      
      let realLineHeight = lineHeight //(frame.size.height - verticalPadding) / CGFloat(visibleItemCount)
      
      let removeSpacers = heightIsLimited
      let items = entry.items.filter { item in
        removeSpacers ? item.type != "spacer" : true
      }
      
      VStack(spacing: 0) {
        
        //#if os(iOS)
        //                if #available(iOSApplicationExtension 17.0, *) {
        //                  if widgetFamily == .systemMedium {
        //                    Button(intent: StartRecording()) {
        //                      Text(state ? "Start" : "Stop")
        //                        .lineLimit(1)
        //                    }
        //                  }
        //                }
        //#endif
        
        
        ForEach(items.prefix(visibleItemCount), id: \.self) { row in
          
          let item = row.item
          if let event = item as? EKEvent {
            
            
            // MARK: Events
            HStack {
              if event.isAllDay {
                if !widthIsLimited {
                  Text("")
                    .font(.system(size: fontSize))
                    .frame(minWidth:keyline)
                }
              } else {
                
                let (hour, minute) = getComponents(event.startDate)
                
                HStack(alignment:.lastTextBaseline, spacing:1) {
                  Text(hour).font(font)
                  Text(minute).font(smallFont.monospacedDigit())
                    .baselineOffset(fontSize * 0.2)
                  //                    .foregroundColor(minute == "00" ? .secondary : .primary)
                }
                //                Text(convertToSuperscript(time: timeString))
                //                  .font(font.monospacedDigit())
                //
                .widgetAccentable(true)
                .frame(minWidth:keyline, alignment: .trailing)
              }
              
              let eventid = "x-apple-calevent://\(row.id.replacingOccurrences(of: ":", with: "/"))"
              
              Link(destination: item?.url ??
                   URL(string:eventid)!) {
                
                Text(event.title)
                
                  .font(font)
                  .lineLimit(1)
                  .foregroundColor(event.isAllDay ? .secondary : .primary)
                  .italic(event.isAllDay)
                //                    .frame(maxWidth:.infinity)
                
              }
              if (!event.isAllDay && !widthIsLimited) {
                let duration = event.endDate.timeIntervalSince(event.startDate)
                let durationString = duration >= 3600
                ? String(format: "%.0fh", duration / 3600)
                : String(format: "%.0fm", duration / 60)
                Text(durationString)
                  .foregroundColor(.secondary)
                  .font(font)
              }
              
            }
            //            .mask(LinearGradient(gradient: Gradient(colors: [.black, .black, .black, .clear]), startPoint:.leading, endPoint: .trailing))
            .frame(maxWidth:.infinity, alignment: .leading)
            .frame(height: realLineHeight)
            
          } else if let reminder = item as? EKReminder { // MARK: Reminders
            
            HStack(alignment:.center) {
              HStack(spacing:0) {
                if (reminder.priority > 0) {
                  Text(reminder.priority > 0 ? "\(String(repeating:"!", count:4 - reminder.priority))" : "")
                  
                    .font(font)
                    .foregroundColor(.secondary)
                    .widgetAccentable()
                }
                Image(systemName: "circle")
                  .imageScale(.small)
                  .font(font)
                  .foregroundColor(.secondary)
                  .widgetAccentable()
              }.frame(minWidth:keyline, alignment: .trailing)
              Link(destination: reminder.url ?? URL(string:"x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)")!) {
                
                Text(reminder.title ?? "No Title")
                  .font(font)
                  .lineLimit(1)
                  .multilineTextAlignment(.leading)
                  .frame(maxWidth: .infinity, alignment: .leading)
                
              }
              
              if let dueDate = reminder.dueDateComponents?.date {
                
                Text(relativeDateFormatter.string(for: dueDate) ?? "due")
                  .foregroundColor(.secondary)
                  .font(font)
              }
              
            }.frame(maxWidth:.infinity, alignment: .leading)
              .frame(height: realLineHeight)
          } else {
            
            
            HStack {
              
              Text(row.header ?? "———")
                .font(font)
                .textCase(.uppercase)
                .monospaced()
                .foregroundColor(.secondary)
                .widgetAccentable()
              
                .frame(minWidth:keyline, alignment:.trailing)
              
              ForEach(row.allDayItems ?? []) { item in
                if let title = item.item?.title {
                  Text(title)
                    .font(font)
                    .foregroundColor(Color.secondary)
                }
              }
              
              
            }.frame(maxWidth:.infinity, alignment: .leading)
              .frame(height: realLineHeight)
            
            
          }
        }
      }//.border(.gray)
      .frame(maxHeight: .infinity, alignment: .top)
      .frame(maxWidth: .infinity, alignment: .top)
      .padding(.vertical, vPadding)
      .padding(.horizontal, hPadding)
      
    }//.border(.red)
    .environment(\.colorScheme, isDark ?  .dark : .light)
    .background(widgetRenderingMode == .accented ? .clear : backgroundColor)//Color("WidgetBackground"))
  }
}



struct widgetReminders: Widget {
  let kind: String = "reminders"
  
  var body: some WidgetConfiguration {
    
    AppIntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider(kind: kind)) { entry in
      TextWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .contentMarginsDisabled()
    .configurationDisplayName("Reminders")
    .description("A text listing of your reminders")
    
#if os(watchOS)
    .supportedFamilies([.accessoryRectangular, .accessoryInline])
#else
    .supportedFamilies([.accessoryRectangular, .accessoryInline,
                        .systemSmall, .systemMedium, .systemLarge])
#endif
    
    
  }
}
struct widgetCalendar: Widget {
  let kind: String = "calendar"
  
  var body: some WidgetConfiguration {
    
    AppIntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider(kind:kind)) { entry in
      TextWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .contentMarginsDisabled()
    .configurationDisplayName("Calendar")
    .description("A text listing of your calendar")
    
#if os(watchOS)
    .supportedFamilies([.accessoryRectangular, .accessoryInline])
#else
    .supportedFamilies([.accessoryRectangular, .accessoryInline,
                        .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
#endif
    
  }
}

extension ConfigurationIntent {
  fileprivate static var smiley: ConfigurationIntent {
    let intent = ConfigurationIntent()
    intent.fullBleed = false
    return intent
  }
  
  fileprivate static var starEyes: ConfigurationIntent {
    let intent = ConfigurationIntent()
    intent.fullBleed = true
    return intent
  }
}

#Preview(as: .accessoryRectangular) {
  widgetReminders()
} timeline: {
  CalendarTimelineEntry(date: .now, configuration: .smiley, items:[])
  CalendarTimelineEntry(date: .now, configuration: .starEyes, items:[])
}
