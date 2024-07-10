import WidgetKit
import SwiftUI
import EventKit


extension Array {
  mutating func removeAllFromEnd(where predicate: (Element) -> Bool) {
    while let last = self.last, predicate(last) {
      self.removeLast()
    }
  }
}

struct TextWidgetView : View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.widgetContentMargins) var margins
  @Environment(\.widgetRenderingMode) var widgetRenderingMode
  @Environment(\.showsWidgetContainerBackground) var showsWidgetContainerBackground
  @Environment(\.widgetFamily) var widgetFamily
  @AppStorage("state") private var state = false
  
  var entry: TimelineProvider.Entry = CalendarTimelineEntry(date: Date(), configuration: ConfigurationIntent(), reminders:[], events:[])
  
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
  
  init(entry: TimelineProvider.Entry) {
    self.entry = entry
  }
  
  var body: some View {
    
    let backgroundColor = entry.configuration.backgroundColor.count > 0 ?
    Color.withHex(entry.configuration.backgroundColor) : .clear;
    
    let accentColor = entry.configuration.accentColor.count > 0 ?
    Color.withHex(entry.configuration.accentColor) : .secondary;
    
#if os(watchOS)
    let accessory = true
    let heightIsLimited = true
    let widthIsLimited = true
    let isHuge = false
#else
    let accessory =
    (widgetFamily == .accessoryRectangular) ||
    (widgetFamily == .systemSmall && !showsWidgetContainerBackground)
    let heightIsLimited = accessory
    let widthIsLimited = accessory || (widgetFamily == .systemSmall)
    let isHuge = widgetFamily == .systemExtraLarge
#endif
    
    let isDark = backgroundColor == .clear ? colorScheme == .dark : backgroundColor.isDark()
    let defaultCalendar = EKEventStore().defaultCalendarForNewEvents
    let defaultRemindersList = EKEventStore().defaultCalendarForNewReminders()
    let content = entry.configuration.content
    
    GeometryReader { frame in
      let fullBleed =
      widgetFamily == .accessoryRectangular  ||
      !showsWidgetContainerBackground ? true : entry.configuration.fullBleed
      
      //      let isStandBy = !showsWidgetContainerBackground && (widgetFamily != .accessoryRectangular)
      let hPadding = fullBleed ? margins.top / 3 : margins.leading
      let vPadding = accessory ? margins.top / 3 : margins.top / 2
      let height = frame.size.height - vPadding * 2
      
      let minLineHeight = widthIsLimited ? 18.0 : isHuge ? 48.0 : 24.0
      let lineHeight = height / ceil(height / minLineHeight)
      
      let fontSize = widthIsLimited ? 12.0 : (isHuge ? 32.0 : 16.0)
      let keyline = fontSize * 2.25
      
      let design = designForFontStyle(entry.configuration.fontStyle)
      var font = Font.system(size: fontSize, design: design).width(.standard)
      var smallFont = Font.system(size: fontSize * 0.66, design: design).weight(.semibold)
      
      let insets = EdgeInsets(top: vPadding,
                              leading: min(hPadding, fontSize / 2),
                              bottom: vPadding,
                              trailing: hPadding)
      
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
      let reminders = entry.reminders.prefix(entry.configuration.content == .both ? (visibleItemCount / 2) : visibleItemCount)
      let events = entry.events
      var items: [EventEntry] = []
      
      let _ = items.append(contentsOf: events)
      let _ = items.append(contentsOf: reminders)
      let filteredItems = items.filter { item in
        removeSpacers ? item.type != "spacer" : true
      }
      
      let offsetCount = entry.configuration.pageOffset * visibleItemCount
      
      let clippedItems: [EventEntry] = Array(items[min(filteredItems.count, offsetCount) ..< min(filteredItems.count, offsetCount + visibleItemCount)])
      let index = clippedItems.lastIndex { $0.removeIfOrphaned != true}
      
      let visibleItems =  index != nil ?  Array(clippedItems[...index!]) : clippedItems
      
      VStack(spacing: 0) {
        ForEach(visibleItems, id: \.self) { row in
          
          let item = row.item
          
          let cgColor = item?.calendar?.cgColor
          let color = entry.configuration.showColors
          ? cgColor != nil ? Color(cgColor: cgColor!).forScheme(scheme: colorScheme) : nil
          : accentColor
          
          
          if let item = row.item {
            let opacity = max(0.5, pow(1.0 - Double(item.start?.timeIntervalSince(entry.date) ?? 0.0) / 60.0 / 60.0 / 24.0, 0.33))
            
            let (hour, minute) = getComponents(item.date)
            
            let timeString = HStack(alignment:.lastTextBaseline, spacing:0.5) {
              Text(hour).font(font.monospacedDigit())
                .kerning(-0.5)
              Text(minute).font(smallFont.monospacedDigit())
                .baselineOffset(fontSize * 0.24)
                .kerning(-0.5)
            }
              .foregroundColor(color ?? .secondary)
              .widgetAccentable(true)
              .frame(minWidth:0, alignment: .trailing)
            
            
            if let event = item as? EKEvent {
              let eventid = "x-apple-calevent://\(row.id.replacingOccurrences(of: ":", with: "/"))"
              let titleString = Link(destination: item.url ??
                                     URL(string:eventid)!) {
                Text(event.title)
                  .font(font)
                  .lineLimit(1)
                  .foregroundColor(event.isAllDay ? .secondary : .primary)
                  .italic(event.isAllDay)
              }
                .buttonStyle(.plain)
                .opacity(opacity)
              
              // MARK: Events
              HStack(alignment: .firstTextBaseline) {
                
                let timeFirst = true
                if (timeFirst) {
                  if event.isAllDay {
                    if !widthIsLimited {
                      Text("")
                        .font(.system(size: fontSize))
                        .frame(minWidth:keyline)
                    }
                  } else {
                    
                    timeString
                      .frame(minWidth:keyline, alignment: .trailing)
                  }
                  
                  titleString
                  if event.calendar != defaultCalendar,
                     let initial = event.calendar?.title.first {
                    Image(systemName: "\(String(initial).lowercased()).square")
                      .imageScale(.small)
                      .font(font)
                      .foregroundColor(color ?? .red)
                      .widgetAccentable()
                  }
                } else {
                  titleString
                    .layoutPriority(1)
                  Rectangle()
                    .fill(.secondary)
                    .opacity(0.5)
                    .frame(maxHeight:1)
                  timeString
                    .layoutPriority(2)
                }
                //              if let suffix = row.suffix {
                //                Text(suffix)
                //                  .font(font)
                //              }
                //              if (!event.isAllDay && !widthIsLimited) {
                //                let duration = event.endDate.timeIntervalSince(event.startDate)
                //                let durationString = duration >= 3600
                //                ? String(format: "%.0fh", duration / 3600)
                //                : String(format: "%.0fm", duration / 60)
                //                Text(durationString)
                //                  .foregroundColor(.secondary)
                //                  .font(font)
                //              }
                
              }
              //            .mask(LinearGradient(gradient: Gradient(colors: [.black, .black, .black, .clear]), startPoint:.leading, endPoint: .trailing))
              .frame(maxWidth:.infinity, alignment: .bottomLeading)
              .frame(height: realLineHeight)
              
              
              
            } else if let reminder = item as? EKReminder { // MARK: Reminders
              
              
              // TODO: For some reason calendar is nil here for reminders
              
              HStack(alignment:.center) {
                //                if content == .calendar {
                //                  timeString
                //                    .frame(minWidth:keyline, alignment: .trailing)
                //                }
                HStack() {
                  Image(systemName: "circle")
                    .imageScale(.small)
                    .font(font)
                    .foregroundColor(color ?? .secondary)
                    .widgetAccentable()
                  
                }
                .frame(minWidth:keyline, alignment: .trailing)
                Link(destination: reminder.url ?? URL(string:"x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)")!) {
                  
                  Text(reminder.title ?? "No Title")
                    .font(font)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                  //                    .frame(maxWidth: content == .reminders ? .infinity : nil, alignment: .leading)
                  
                }
                .buttonStyle(.plain)
                .opacity(opacity)
                
                if let components = reminder.dueDateComponents {
                  let dueDate = components.date
                  if let hour = components.hour {
                    
                    Text(relativeDateFormatter.string(for: dueDate) ?? "due")
                      .foregroundColor(.secondary)
                      .font(font)
                    
                  } else if (content == .reminders ){
                    Text(relativeDateFormatterDay.string(for: dueDate) ?? "due")
                      .foregroundColor(.secondary)
                      .font(font)
                  }
                }
                if (reminder.priority > 0) {
                  //                  Text(reminder.priority > 0 ? "\(String(repeating:"!", count:4 - reminder.priority/3))" : "")
                  //
                  //                    .font(font)
                  //                    .foregroundColor(.secondary)
                  //                    .widgetAccentable()
                  Image(systemName: "exclamationmark.square")
                    .imageScale(.small)
                    .foregroundColor(color ?? .primary)
                    .widgetAccentable()
                }
                if reminder.calendar != defaultRemindersList,
                   let initial = reminder.calendar?.title.first {
                  Image(systemName: "\(String(initial).lowercased()).circle.fill")
                    .imageScale(.small)
                    .foregroundColor(color ?? .red)
                    .widgetAccentable()
                }
                
                
              }
              .frame(maxWidth:.infinity, alignment: .leading)
              .frame(height: realLineHeight)
            }
          } else {
            
            HStack(alignment: .bottom) {
              
              if row.id == "error", let destination = row.url {
                Link(destination: destination){
                  Text(row.title ?? "Error")
                }
              } else if row.id == "location" {
                if let location = row.title {
                  Text("")
                    .frame(minWidth:keyline, alignment:.trailing)
                  Text(location)
                    .font(font)
                    .foregroundColor(.secondary)
                }
              } else {
                HStack(alignment: .bottom) {
                  if let header = row.title  {
                    if (!widthIsLimited) {
                      Text("")
                        .font(font)
                        .frame(minWidth:keyline, alignment:.trailing)
                    }
                    Text(header)
                      .font(smallFont)
                      .textCase(.uppercase)
                      .kerning(1)
                      .monospaced()
                      .foregroundColor(.secondary)
                      .widgetAccentable()
                      .frame(minWidth:widthIsLimited ? keyline : 0, alignment:.bottomTrailing)
                      .padding(.top, 8)
                    
                  }
                }
                if let allDayItems = row.allDayItems?.prefix(widthIsLimited ? 2: 3) {
                  let visibleItems =
                  widthIsLimited ? allDayItems : allDayItems
                  ForEach(visibleItems) { item in
                    if let title = item.item?.title {
                      Text(title)
                        .font(smallFont)
                        .foregroundColor(Color.secondary)
                      
                      //                        .mask(
                      //                            LinearGradient(gradient: Gradient(stops: [
                      //                                .init(color: .black, location: 0),
                      //                                .init(color: .black, location: 0.7),
                      //                                .init(color: .clear, location: 1)
                      //                            ]), startPoint: .leading, endPoint: .trailing)
                      //                        )
                    }
                  }
                }
              }
              
            }
            .frame(maxWidth:.infinity, alignment: .bottomLeading)
            .frame(height: realLineHeight)
            
            
            
          }
        }
        
      }//.border(.gray)
      
      .frame(maxHeight: .infinity, alignment: .top)
      .frame(maxWidth: .infinity, alignment: .top)
      .padding(.top, insets.top)
      .padding(.bottom, insets.bottom)
      .padding(.leading, insets.leading)
      .padding(.trailing, insets.trailing)
      
    }//.border(.red)
    .environment(\.colorScheme, isDark ?  .dark : .light)
    .background(widgetRenderingMode == .accented ? .clear : backgroundColor)//Color("WidgetBackground"))
  }
}


//
//struct widgetReminders: Widget {
//  let kind: String = "reminders"
//
//  var body: some WidgetConfiguration {
//
//    AppIntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: TimelineProvider(kind: kind)) { entry in
//      TextWidgetView(entry: entry)
//        .containerBackground(.clear, for: .widget)
//    }
//    .contentMarginsDisabled()
//    .configurationDisplayName("Reminders")
//    .description("A text listing of your reminders")
//
//#if os(watchOS)
//    .supportedFamilies([
//      .accessoryRectangular, .accessoryInline
//    ])
//
//#elseif os(macOS)
//    .supportedFamilies([
//      .systemSmall, .systemMedium, .systemLarge,
//      .systemExtraLarge])
//#else
//    .supportedFamilies([.accessoryRectangular, .accessoryInline,
//                        .systemSmall, .systemMedium, .systemLarge])
//#endif
//
//
//  }
//}
struct widgetCalendar: Widget {
  let kind: String = "calendar"
  
  var body: some WidgetConfiguration {
    
    AppIntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: TimelineProvider()) { entry in
      TextWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .contentMarginsDisabled()
    .configurationDisplayName("Events + Reminders")
    .description("A text view of events or reminders")
    
#if os(watchOS)
    .supportedFamilies([
      .accessoryRectangular
    ])
#elseif os(iOS)
    .supportedFamilies([
      .accessoryRectangular,
      .systemSmall,
      .systemMedium,
      .systemLarge,
      .systemExtraLarge
    ])
#elseif os(macOS)
    .supportedFamilies([
      .systemSmall,
      .systemMedium,
      .systemLarge,
      .systemExtraLarge
    ])
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

//#Preview(as: .systemSmall) {
//  widgetReminders()
//} timeline: {
//  CalendarTimelineEntry(date: .now, configuration: .smiley, items:[])
//  CalendarTimelineEntry(date: .now, configuration: .starEyes, items:[])
//}
