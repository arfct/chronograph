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

extension Date {
  func getComponents() -> (hour: String, minute: String) {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.current

    // Format hour
    dateFormatter.dateFormat = "h"
    let hourString = dateFormatter.string(from: self)

    // Format minute with leading zero
    dateFormatter.dateFormat = "mm"
    let minuteString = dateFormatter.string(from: self)

    return (hourString, minuteString)
  }
}

struct TextWidgetView : View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.widgetContentMargins) var margins
  @Environment(\.widgetRenderingMode) var widgetRenderingMode
  @Environment(\.showsWidgetContainerBackground) var showsWidgetContainerBackground
  @Environment(\.widgetFamily) var widgetFamily
  @AppStorage("state") private var state = false
  @AppStorage(Keys.tokenizeParens, store: UserDefaults(suiteName: Keys.suiteName)) private var tokenize = false
  @AppStorage(Keys.compactTime, store: UserDefaults(suiteName: Keys.suiteName)) private var compactTime = true
  

  @State private var visibleRows: Int = 100
  
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
    
    let now = Date()
    
    let backgroundColor = entry.configuration.backgroundColor.count > 0 ?
    Color.withHex(entry.configuration.backgroundColor) : .clear;
    
    let accentColor = entry.configuration.accentColor.count > 0 ?
    Color.withHex(entry.configuration.accentColor) : .secondary;
    
#if os(watchOS)
    let accessory = true
    let heightIsLimited = true
    let widthIsLimited = true
    let isHuge = false
#elseif os(macOS)
    let accessory =
    (widgetFamily == .systemSmall && !showsWidgetContainerBackground)
    let heightIsLimited = accessory
    let widthIsLimited = accessory || (widgetFamily == .systemSmall)
    let isHuge = widgetFamily == .systemExtraLarge
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
    
    GeometryReader { container in
      
#if os(macOS)
      let fullBleed = !showsWidgetContainerBackground ? true : entry.configuration.fullBleed
#else
      let fullBleed =
      widgetFamily == .accessoryRectangular  ||
      !showsWidgetContainerBackground ? true : entry.configuration.fullBleed
#endif
      
      //      let isStandBy = !showsWidgetContainerBackground && (widgetFamily != .accessoryRectangular)
      let hPadding = fullBleed ? margins.top / 3 : margins.leading
      let vPadding = accessory ? margins.top / 3 : margins.top / 2
      let height = container.size.height - vPadding * 2
      
      let minLineHeight = widthIsLimited ? 18.0 : isHuge ? 48.0 : 24.0
//      let lineHeight = height / ceil(height / minLineHeight)
      
      let textStyle = FontSize.caseSize[entry.configuration.fontSize] ?? .body
      let baseFont = UIFont.preferredFont(forTextStyle: textStyle)
      let baseFontSize = baseFont.pointSize
      
      
      let fontSize = widthIsLimited ? baseFontSize * 0.75 : (isHuge ? baseFontSize * 2.0 : baseFontSize)
      
      let lineHeight = fontSize * baseFont.lineHeight / baseFont.pointSize * (heightIsLimited ? 1.0 : 1.25)

      let keyline = fontSize * (compactTime ? 2.25 : 2.5)
      
      let design = designForFontStyle(entry.configuration.fontStyle)
      var font = Font.system(size: fontSize, design: design).width(.standard)
      var smallFont = Font.system(size: fontSize * 0.66, design: design).weight(.semibold)
      let smallLineHeight = lineHeight * 0.66
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
      
      let visibleItemCount = visibleRows // container.size.height > 0 ? Int((container.size.height - vPadding) / lineHeight) : 4
      
      let realLineHeight = lineHeight //(frame.size.height - verticalPadding) / CGFloat(visibleItemCount)
      
      let removeSpacers = heightIsLimited
      let reminders = entry.reminders.prefix(entry.configuration.content == .both ? (visibleItemCount / 2) : visibleItemCount)
      let events = entry.events
      var items: [EventEntry] = []
      
      let _ = items.append(contentsOf: events)
      let _ = items.append(contentsOf: reminders)
      let filteredItems = items.filter { item in
        removeSpacers ? item.type != "spacer" : true
      }.filter { item in
        item.isVisible()
      }
      
      let offsetCount = entry.configuration.pageOffset * visibleItemCount
      
      let clippedItems: [EventEntry] = Array(items[min(filteredItems.count, offsetCount) ..< min(filteredItems.count, offsetCount + visibleItemCount)])
      let index = clippedItems.lastIndex { $0.removeIfOrphaned != true}
      
      let visibleItems =  index != nil ?  Array(clippedItems[...index!]) : clippedItems
      
      VStack(spacing: 0) {
        ForEach(visibleItems, id: \.self) { row in
          if let item = row.item {
            if let event = item as? EKEvent {
              EventRowView(event: event, row: row, font: font, smallFont: smallFont, keyline: keyline, realLineHeight: realLineHeight, colorScheme: colorScheme, defaultCalendar: defaultCalendar, compactTime: compactTime, accentColor: accentColor, entry: entry, tokenize: tokenize, fontSize: fontSize, smallLineHeight: smallLineHeight)
            } else if let reminder = item as? EKReminder {
              ReminderRowView(reminder: reminder, row: row, font: font, smallFont: smallFont, keyline: keyline, realLineHeight: realLineHeight, colorScheme: colorScheme, defaultRemindersList: defaultRemindersList, compactTime: compactTime, accentColor: accentColor, entry: entry, tokenize: tokenize, fontSize: fontSize, smallLineHeight: smallLineHeight)
            }
          } else {
            HeaderRowView(row: row, font: font, smallFont: smallFont, keyline: keyline, realLineHeight: realLineHeight, widthIsLimited: widthIsLimited)
          }
        }
      }
      .onPreferenceChange(RowHeightPreferenceKey.self) { heights in
        updateVisibleRows(with: heights, containerHeight: container.size.height)
      }
      
      .frame(maxHeight: .infinity, alignment: .top)
      .frame(maxWidth: .infinity, alignment: .top)
      .padding(.top, insets.top)
      .padding(.bottom, insets.bottom)
      .padding(.leading, insets.leading)
      .padding(.trailing, insets.trailing)
      
      .coordinateSpace(name: "stack")
    }.clipped()
      .environment(\.colorScheme, isDark ?  .dark : .light)
      .background(widgetRenderingMode == .accented ? .clear : backgroundColor)//Color("WidgetBackground"))
  }
  
  
  private func updateVisibleRows(with rowMaxY: [CGFloat], containerHeight: CGFloat) {
    let visibleCount = rowMaxY.indices.last { index in
      let maxY = rowMaxY[index]
      return maxY <= containerHeight
    } ?? 0
    
    visibleRows = visibleCount + 1
  }
  
}

struct RowHeightPreferenceKey: PreferenceKey {
  static var defaultValue: [CGFloat] = []
  static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
    value.append(contentsOf: nextValue())
  }
}

struct EventRowView: View {
  let event: EKEvent
  let row: EventEntry
  let font: Font
  let smallFont: Font
  let keyline: CGFloat
  let realLineHeight: CGFloat
  let colorScheme: ColorScheme
  let defaultCalendar: EKCalendar?
  let compactTime: Bool
  let accentColor: Color
  let entry: TimelineProvider.Entry
  let tokenize: Bool
  let fontSize: CGFloat
  let smallLineHeight: CGFloat

  var body: some View {
    let (hour, minute) = event.date.getComponents()

    let timeString = Group {
      if (compactTime) {
        HStack(alignment:.lastTextBaseline, spacing:0.5) {
          Text(hour).font(font.monospacedDigit())
            .kerning(-0.5)
          Text(minute).font(smallFont.monospacedDigit())
            .baselineOffset(fontSize * 0.24)
            .kerning(-0.5)
        }
      } else {
        Text("\(hour):\(minute)")
          .font(font.monospacedDigit())
          .kerning(-0.5)
      }
    }
    .foregroundColor(event.isAllDay ? .secondary : .primary)
    .widgetAccentable(true)
    .frame(minWidth:0, alignment: .trailing)

    let calendarId = event.calendar?.source?.sourceIdentifier ?? event.calendar?.calendarIdentifier ?? ""
    let eventid = "x-apple-calevent://\(calendarId)/\(event.calendarItemExternalIdentifier.replacingOccurrences(of: ":", with: "/"))"

    let title = (event.title.count > 0 ? event.title : nil) ?? "Untitled"
    let titleString = Link(destination: event.url ??
                           URL(string:eventid)!) {
      Group {
        if (tokenize) {
          TokenizedTextView(text:title, font:font, tokenFont:font)
        } else {
          Text(title ?? "Untitled")
        }
      }
      
      .font(font)
      .lineLimit(1)
      .foregroundColor(event.isAllDay ? .secondary : .primary)
      .italic(event.isAllDay)
    }
    .buttonStyle(.plain)

    let hoursAway = Double(row.startDate?.timeIntervalSince(entry.date) ?? 0.0) / 60.0 / 60.0
    let opacity = max(1.0, pow(1.0 - hoursAway / 4.0, 0.33))

    let isHappening = row.isHappening()
    let isSoon = row.isSoon()

    VStack(spacing: 0) {
      HStack(alignment: .center) {
        if event.isAllDay {
          Text("")
            .font(.system(size: fontSize))
            .frame(minWidth:keyline)
        } else if (row.hasConflict && row.hasStartConflict) {
          Text("")
            .frame(minWidth:keyline, alignment: .trailing)
        } else {
          timeString
            .frame(minWidth:keyline, alignment: .trailing)
        }

        HStack(spacing:2) {
          titleString
          if (row.hasConflict) {
            Image(systemName: "exclamationmark.triangle.fill")
              .imageScale(.small)
              .font(font)
              .foregroundColor(.yellow)
          }

          if event.calendar != defaultCalendar,
             let initial = event.calendar?.title.first {
            Image(systemName: "\(String(initial).lowercased()).circle.fill")
              .imageScale(.small)
              .font(font)
              .foregroundColor(accentColor)
              .widgetAccentable()
              .layoutPriority(1)
          }
        }
      }
      .opacity(opacity)
      .background(GeometryReader {
        Color.clear.preference(key: RowHeightPreferenceKey.self, value: [$0.frame(in: .named("stack")).maxY])
      })
      .frame(maxWidth:.infinity, alignment: .bottomLeading)
      .frame(height: realLineHeight)
      .clipped()

      if ((isHappening || isSoon)
          && (row.hasAttachments || row.hasLocation)
      ) {
        HStack(alignment: .top) {
          VStack(alignment: .trailing) { }
            .frame(minWidth:keyline, alignment:.trailing)
          
          VStack(alignment: .leading, spacing:smallLineHeight/4.0) {
            Group {
              if let locations = row.locations, locations.count > 0 {
                HStack {
                  if let meeting = row.meeting, let url = meeting.url {
                    Link(destination: url) {
                      HStack(spacing:4){
                        Image(systemName: "video")
                          .foregroundStyle(.secondary)
                        Text(meeting.title ?? "Video conference").foregroundStyle(.primary)
                      }
                    }
                    .buttonStyle(.plain)
                  }
                  Text("\(locations.joined(separator: ", "))")
                    .foregroundStyle(.secondary)
                    .italic()
                }
              }
              
              if let attachments = row.attachments {
                ForEach(attachments, id: \.self) { document in
                  if let url = document.url {
                    Link(destination: url, label: {
                      HStack(spacing:4) {
                        Image(systemName: document.displayIcon)
                          .foregroundStyle(.secondary)
                        
                        if let prefix = document.prefix, prefix.count > 0 { Text(prefix).foregroundStyle(.secondary) }
                        Text(document.displayName).foregroundStyle(.primary)
                      }
                    })
                    .buttonStyle(.plain)
                  }
                }
              }
              if event.hasAttendees {
                FacePile(event: event)
                  .foregroundStyle(.secondary)
              }

              if let notes = row.notes, notes.characters.count > 1 {
                Text(notes)
                  .multilineTextAlignment(.leading)
                  .lineLimit(2)
                  .foregroundStyle(.secondary)
              }
            }
            .foregroundStyle(.primary)
            .font(smallFont)
            .frame(maxWidth:.infinity, minHeight:smallLineHeight, alignment: .leading)
            .opacity(opacity)
          }
          .frame(maxWidth:.infinity, alignment:.leading)
          .padding(.top, smallLineHeight/3)
          .padding(.bottom, 2 * smallLineHeight/3)
        }
      }
    }
  }
}

struct ReminderRowView: View {
  let reminder: EKReminder
  let row: EventEntry
  let font: Font
  let smallFont: Font
  let keyline: CGFloat
  let realLineHeight: CGFloat
  let colorScheme: ColorScheme
  let defaultRemindersList: EKCalendar?
  let compactTime: Bool
  let accentColor: Color
  let entry: TimelineProvider.Entry
  let tokenize: Bool
  let fontSize: CGFloat
  let smallLineHeight: CGFloat

  var body: some View {
    let hoursAway = Double(row.startDate?.timeIntervalSince(entry.date) ?? 0.0) / 60.0 / 60.0
    let opacity = max(1.0, pow(1.0 - hoursAway / 4.0, 0.33))

    HStack(alignment:.center) {
      HStack() {
        Image(systemName: "circle")
          .imageScale(.small)
          .font(font)
          .foregroundColor(accentColor)
          .widgetAccentable()
      }
      .frame(minWidth:keyline, alignment: .trailing)
      
      Link(destination: reminder.url ?? URL(string:"x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)")!) {
        HStack {
          if (reminder.priority > 0) {
            Text(reminder.priority > 0 ? reminder.priorityPrefix : "")
              .font(font)
              .foregroundColor(.secondary)
              .widgetAccentable()
          }
          Group {
            if (tokenize) {
              Text(reminder.title ?? "No Title")
            } else {
              Text(reminder.title)
            }
          }
          .font(font)
          .lineLimit(1)
          .foregroundColor(.primary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .buttonStyle(.plain)
      
      if let components = reminder.dueDateComponents {
        let dueDate = components.date
        if let hour = components.hour {
          
          Text(relativeDateFormatter.string(for: dueDate) ?? "due")
            .foregroundColor(.secondary)
            .font(font)
          
        } else if (entry.configuration.content == .reminders ){ // allDay
          Text(relativeDateFormatterDay.string(for: dueDate) ?? "due")
            .foregroundColor(.secondary)
            .font(font)
          
        }
      }
      
      
      if reminder.calendar != defaultRemindersList,
         let initial = reminder.calendar?.title.first {
        Image(systemName: "\(String(initial).lowercased()).circle.fill")
          .imageScale(.small)
          .foregroundColor(accentColor)
          .widgetAccentable()
      }
      
      
    }
    .frame(maxWidth:.infinity, alignment: .leading)
    .frame(height: realLineHeight)
    
    .opacity(opacity)
    .background(GeometryReader {
      Color.clear.preference(key: RowHeightPreferenceKey.self, value: [$0.frame(in: .named("stack")).maxY])
    })
  }
}

struct HeaderRowView: View {
  let row: EventEntry
  let font: Font
  let smallFont: Font
  let keyline: CGFloat
  let realLineHeight: CGFloat
  let widthIsLimited: Bool

  var body: some View {
    let hoursAway = Double(row.startDate?.timeIntervalSince(Date()) ?? 0.0) / 60.0 / 60.0
    let opacity = max(1.0, pow(1.0 - hoursAway / 4.0, 0.33))

    HStack(alignment: .bottom) {
      if row.id == "error", let destination = row.url {
        Link(destination: destination){
          Text(row.title ?? "Error")
        }
      } else if row.type == "header" {
        HStack(alignment: .bottom) {
          if let header = row.title  {
            let hasAllDayItems = row.allDayItems?.count ?? 0 > 0
             
            if (!widthIsLimited || !hasAllDayItems) {
              Text("")
                .font(font)
                .frame(minWidth:keyline, alignment:.trailing)
            }
            
            Text(header)
              .font(smallFont)
              .textCase(.uppercase)
              .kerning(1)
              .monospaced()
              .foregroundColor(.primary)
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
              Text(sanitizeAllDayEvents(title))
                .font(smallFont)
                .foregroundColor(Color.secondary)
            }
          }
        }
      } else if row.type == "free" {
        HStack(alignment: .center) {
          if let header = row.title  {
            Image(systemName: "ellipsis")
              .font(smallFont)
              .rotationEffect(.degrees(90))
              .foregroundStyle(.secondary)
              .frame(minWidth:keyline, alignment:.trailing)
              .opacity(0.667)
            
            Text(header)
              .font(smallFont)
              .italic()
              .foregroundColor(.secondary)
              .frame(minWidth:widthIsLimited ? keyline : 0, alignment:.bottomTrailing)
          }
        }.frame(minHeight:realLineHeight)
      }
    }
    .opacity(opacity)
    .frame(maxWidth:.infinity,
           maxHeight: realLineHeight * 1.5, alignment: .bottomLeading)
    .background(GeometryReader {
      Color.clear.preference(key: RowHeightPreferenceKey.self, value: [$0.frame(in: .named("stack")).maxY])
    })
  }
}

struct ChronographWidget: Widget {
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
  fileprivate static var slmiley: ConfigurationIntent {
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
