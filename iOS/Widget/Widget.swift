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
  
  var entry: TXTimelineProvider.Entry = CalendarTimelineEntry(date: Date(), configuration: ConfigurationIntent(), items:[])
  
  init(entry: TXTimelineProvider.Entry) {
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
    let accessory =
    (widgetFamily == .accessoryRectangular) ||
    (widgetFamily == .systemSmall && !showsWidgetContainerBackground)
    let heightIsLimited = accessory
    let widthIsLimited = accessory || (widgetFamily == .systemSmall)
    let isHuge = widgetFamily == .systemExtraLarge
#endif
    
    let isDark = backgroundColor == .clear ? colorScheme == .dark : backgroundColor.isDark()
    
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
      let keyline = fontSize * 2.2
      
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
      let items = entry.items.filter { item in
        removeSpacers ? item.type != "spacer" : true
      }
      
      let offsetCount = entry.configuration.pageOffset * visibleItemCount
      let visibleItems: [EventEntry] = Array(items[offsetCount ..< offsetCount + visibleItemCount])
//        .removeAllFromEnd { $0.entry.canBeWidowed }
      

      
      VStack(spacing: 0) {
        
        ForEach(visibleItems, id: \.self) { row in
          
          let item = row.item
          
          let cgColor = item?.calendar?.cgColor
          let color = entry.configuration.showColors 
          ? cgColor != nil ? Color(cgColor: cgColor!).forScheme(scheme: colorScheme) : nil
          : .secondary
          
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
                .foregroundColor(color ?? .secondary)
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
                
//                  .frame(maxWidth:.infinity, alignment: .leading)
                
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
                  .foregroundColor(color)
                  .widgetAccentable()
              }.frame(minWidth:keyline, alignment: .center)
              Link(destination: reminder.url ?? URL(string:"x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)")!) {
                
                Text(reminder.title ?? "No Title")
                  .font(font)
                  .lineLimit(1)
                  .foregroundColor(.primary)
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
              
              if row.id == "error", let destination = row.url {
                Link(destination: destination){
                  Text(row.header ?? "Error")
                }
              } else if row.id == "location" {
                if let location = row.header {
                  Text("")
                    .frame(minWidth:keyline, alignment:.trailing)
                  Text(location)
                    .font(font)
                    .foregroundColor(.secondary)
                }
              } else {
                if let header = row.header  {
//                  if (!widthIsLimited) {
//                    Text("")
//                      .font(font)
//                      .frame(minWidth:keyline, alignment:.trailing)
//                  }
                  Text(header)
                    .font(font)
                    .textCase(.uppercase)
                    .monospaced()
                    .foregroundColor(.secondary)
                    .widgetAccentable()
                    .frame(minWidth:keyline, alignment:.trailing)
                }
              }
              if let allDayItems = row.allDayItems {
                let visibleItems =
                widthIsLimited ? allDayItems : allDayItems
                ForEach(visibleItems) { item in
                  if let title = item.item?.title {
                    Text(title)
                      .font(font)
                      .foregroundColor(Color.secondary)
                  }
                }
              }
              
              
            }.frame(maxWidth:.infinity, alignment: .leading)
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



struct widgetReminders: Widget {
  let kind: String = "reminders"
  
  var body: some WidgetConfiguration {
    
    AppIntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: TXTimelineProvider(kind: kind)) { entry in
      TextWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .contentMarginsDisabled()
    .configurationDisplayName("Reminders")
    .description("A text listing of your reminders")
    
#if os(watchOS)
    .supportedFamilies([
      .accessoryRectangular, .accessoryInline
    ])
    
#elseif os(macOS)
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge,
      .systemExtraLarge])
#else
    .supportedFamilies([.accessoryRectangular, .accessoryInline,
                        .systemSmall, .systemMedium, .systemLarge])
#endif
    
    
  }
}
struct widgetCalendar: Widget {
  let kind: String = "calendar"
  
  var body: some WidgetConfiguration {
    
    AppIntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: TXTimelineProvider(kind:kind)) { entry in
      TextWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .contentMarginsDisabled()
    .configurationDisplayName("Calendar")
    .description("A text listing of your calendar")
    
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
