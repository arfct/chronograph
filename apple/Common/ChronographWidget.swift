import WidgetKit
import SwiftUI
import EventKit



struct ChronographWidgetView : View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.widgetContentMargins) var margins
  @Environment(\.widgetRenderingMode) var widgetRenderingMode
  @Environment(\.showsWidgetContainerBackground) var showsWidgetContainerBackground
  @Environment(\.widgetFamily) var widgetFamily
  @AppStorage(Keys.tokenizeParens, store: UserDefaults(suiteName: Keys.suiteName)) private var tokenize = false
  @AppStorage(Keys.compactTime, store: UserDefaults(suiteName: Keys.suiteName)) private var compactTime = true
  @AppStorage(Keys.brailleMode, store: UserDefaults(suiteName: Keys.suiteName)) private var legacyBrailleMode = false
  @AppStorage(Keys.obfuscation, store: UserDefaults(suiteName: Keys.suiteName)) private var obfuscationRaw = ""

  @State private var eventStore = EKEventStore()
  private var visibleItemCount: Int

  
  private var isAccessory = false
  private var heightIsLimited = false
  private var widthIsLimited = false
  private var fullBleed: Bool = false
  
  private var lineHeight: CGFloat = 10.0
  /// Leading applied on top of the font's own line height; see init.
  private var lineSpread: CGFloat = 1.5
  private var fontSize: CGFloat = 16.0
  
  let textStyle: UIFont.TextStyle
  var entry: CalendarTimelineEntry
  var context: TimelineProviderContext?
  
  func designForFontStyle(_ style: FontStyle) -> Font.Design {
    switch style {
    case .rounded: return .rounded
    case .monospace: return .monospaced
    case .serif: return  .serif
    default: return .default
    }
  }
  
  // MARK: init
  init(entry: CalendarTimelineEntry) {
    self.entry = entry
    self.context = entry.context
    let resolvedSize = entry.config.fontSize.resolved
    self.textStyle = FontSize.caseSize[resolvedSize] ?? .body
    
    let widgetFamily = context?.family
    
    // Accessory rows are packed tight; everywhere else lines get 1.5x leading.
#if os(watchOS)
    self.isAccessory = true
    self.heightIsLimited = true
    self.widthIsLimited = true
    lineSpread = 1.0
#elseif os(macOS)
    self.isAccessory = false
    self.heightIsLimited = false
    self.widthIsLimited = (widgetFamily == .systemSmall)
    lineSpread = 1.5
#else
    let accessory = (widgetFamily == .accessoryRectangular)
    self.isAccessory = accessory
    self.heightIsLimited = accessory || widgetFamily == .systemSmall
    self.widthIsLimited = accessory || (widgetFamily == .systemSmall)
    lineSpread = accessory ? 1.0 : 1.5
#endif
    
    
#if os(macOS)
    self.fullBleed = entry.config.viewOptions.contains(.fullBleed)
#else
    self.fullBleed = widgetFamily == .accessoryRectangular || entry.config.viewOptions.contains(.fullBleed)
#endif
    
    let baseFont = UIFont.preferredFont(forTextStyle: textStyle)
    
    self.lineHeight = baseFont.lineHeight
    self.fontSize = baseFont.pointSize
    
    
    if let minLines = FontSize.caseMinLines[resolvedSize],
       let height = entry.context?.displaySize.height {
      self.lineHeight = min(self.lineHeight, height / CGFloat(minLines))
      self.fontSize = self.lineHeight * baseFont.pointSize / baseFont.lineHeight
    }
    
    self.lineHeight = self.lineHeight * lineSpread
    
  
    var visibleCount = 30
    if let displaySize = entry.context?.displaySize {
      visibleCount = Int(floor(displaySize.height / self.lineHeight))
    }
    self.visibleItemCount = visibleCount

    // Diagnostic for iOS 27 XL-portrait adoption: reveals whether WidgetKit
    // hands this pre-27-SDK binary the true family and canvas size.
    let family = String(describing: widgetFamily)
    let size = String(describing: entry.context?.displaySize)
    widgetLog.debug("Widget init: family=\(family, privacy: .public) displaySize=\(size, privacy: .public) rows=\(visibleCount)")
  }
  
  // MARK: body
  var body: some View {
    
    let backgroundColor = Color.withHex(entry.config.backgroundColor) ?? .clear
    
    let isDark = backgroundColor.isDark(over: colorScheme)
    
    let row = {
      var config = RowViewConfig(widget: entry.config, date: entry.date)
      config.fontSize = fontSize
      config.lineHeight = lineHeight
      config.accentColor = entry.config.accentColor.count > 0 ?
      Color.withHex(entry.config.accentColor) : .secondary
      config.colorScheme = isDark ? .dark : .light
      config.keyline = config.fontSize * (compactTime ? 2.25 : 2.6)
      config.widthIsLimited = widthIsLimited
      config.heightIsLimited = heightIsLimited
      
      let design = designForFontStyle(entry.config.fontStyle)

      let obfuscation = ObfuscationStyle.resolve(rawValue: obfuscationRaw,
                                                 legacyBrailleMode: legacyBrailleMode)
      let ishihara = obfuscation == .ishihara
      if ishihara { BundledFonts.registerIfNeeded() }

      config.font = ishihara ? Font.custom("Ishihara", size: config.fontSize) :
      Font.system(size: config.fontSize, design: design).width(.standard)
      config.smallFont = ishihara ? Font.custom("Ishihara", size: config.fontSize) :
      Font.system(size: config.fontSize * 0.66, design: design).weight(.semibold)
      config.smallLineHeight = config.lineHeight * 0.66
      config.smallFontSize = config.fontSize * (ishihara ? 1.0 : 0.66)
      
      switch entry.config.fontStyle {
      case .compressed, .condensed:
        config.font = config.font.width(.compressed)
        config.smallFont = config.smallFont.width(.compressed)
      default:
        config.font = config.font.width(.standard)
      }
      
      config.columnSpacing = fontSize / 6
      config.defaultCalendar = eventStore.defaultCalendarForNewEvents
      // TODO: Infer default from number of events
      config.defaultRemindersList = eventStore.defaultCalendarForNewReminders()
      config.compactTime = compactTime && !ishihara
      config.obfuscation = obfuscation
      config.tokenize = tokenize
      config.showTimeBars = entry.config.features.contains(.timeBars) && !widthIsLimited
      return config
    }()
    
    let hPadding = fullBleed ? margins.top / 8 : margins.leading
    let vPadding = isAccessory ? 0 : (fullBleed ? margins.top / 8 : margins.top / 2)
    let insets = EdgeInsets(top: vPadding,
                            leading: min(hPadding, row.fontSize / 2),
                            bottom: vPadding,
                            trailing: min(hPadding, row.fontSize / 2))
    
    var items: [EventEntry] = []
    let _ = items.append(contentsOf: entry.timezones)
    let _ = items.append(contentsOf: entry.events)
    let _ = items.append(contentsOf: entry.reminders.prefix(entry.config.content == .calendar ? (visibleItemCount / 2) : visibleItemCount))
    // Entries are rendered ahead of time, one per minute, so "now" is the
    // entry's date rather than the moment the view happens to be built.
    let filteredItems = items.filter { $0.isVisible(entry.date) }

    let offsetCount = max(0, entry.config.pageOffset) * visibleItemCount
    let pageItems: [EventEntry] = Array(filteredItems[min(filteredItems.count, offsetCount) ..< min(filteredItems.count, offsetCount + visibleItemCount)])

    GeometryReader { container in
      // `visibleItemCount` assumes every row is exactly lineHeight tall, which
      // day headers and rows carrying details are not, so rows are packed
      // against a height budget using the heights the views actually imply.
      rowStack(fittedItems(pageItems,
                           available: container.size.height - insets.top - insets.bottom,
                           width: container.size.width - insets.leading - insets.trailing,
                           config: row),
               config: row)
      .frame(maxHeight: .infinity, alignment: .top)
      .frame(maxWidth: .infinity, alignment: .top)
      .padding(.top, insets.top)
      .padding(.bottom, insets.bottom)
      .padding(.leading, insets.leading)
      .padding(.trailing, insets.trailing)
      .coordinateSpace(name: "stack")
      .tint(row.accentColor)

      .clipped()
      .environment(\.colorScheme, isDark ?  .dark : .light)
      .background(widgetRenderingMode == .accented ? .clear : backgroundColor)
    }
    
      .containerBackground(.clear, for: .widget)
#if os(watchOS)
      // Tapping a watch widget opens the app on that widget kind's page.
      .widgetURL(WatchPageLink.url(for: entry.config.content))
#endif
  }

  // MARK: row packing

  /// Rows that fit `available`, in order, with any trailing orphaned day header
  /// removed.
  ///
  /// SwiftUI cannot be asked this: the rows carry greedy children
  /// (TimeBarView and the title block both use maxHeight: .infinity), so
  /// ViewThatFits measures a candidate stack as far taller than it draws and
  /// settles on two rows where six fit. The heights are therefore derived from
  /// the same constants the row views lay themselves out with, which is what
  /// CalendarWidget.kt does on Android; the two must change together.
  ///
  /// Deliberately not a measure-then-store loop either: feeding measurements
  /// back into @State is what blanked widgets before 01962c3.
  private func fittedItems(_ items: [EventEntry], available: CGFloat, width: CGFloat,
                           config row: RowViewConfig) -> [EventEntry] {
    // The in-app preview hosts this view in a ScrollView, which proposes no
    // height, so the GeometryReader collapses to its 10pt default. There is no
    // budget to pack against then; show the page as before.
    guard available >= row.lineHeight else { return items }
    var used: CGFloat = 0
    var kept: [EventEntry] = []
    for item in items {
      let height = rowHeight(item, width: width, config: row)
      if used + height > available && !kept.isEmpty { break }
      used += height
      kept.append(item)
    }
    return trimmed(kept)
  }

  /// What each row type occupies, mirroring the frames and padding in
  /// ChronographRow.swift. `lineHeight` is the font's line height times
  /// `lineSpread`, so a line of text without the spread is `textLine`.
  private func rowHeight(_ item: EventEntry, width: CGFloat, config row: RowViewConfig) -> CGFloat {
    let line = row.lineHeight
    let textLine = line / lineSpread
    switch item.type {
    case "header":
      // HeaderRowView's large branch needs both flags, like rowStack below.
      // watchOS never takes it: heightIsLimited is always set there.
      let large = !widthIsLimited && !heightIsLimited
        && entry.config.content == .calendar && row.showTimeBars
      // The large header draws 1.45–1.66 lines (the 1.8x day number, or two
      // small lines plus padding when there are all-day items). 1.75 covers
      // both and matches CalendarWidget.kt; under-counting would slice a row.
      if large { return line + line / 4 + line / 2 }
      return heightIsLimited ? line : line + line / 2 + line / 8
    case "error":
      return line * 1.5
    case "free", "timezone":
      return line
    default:
      guard item.item is EKEvent else { return line }
      let column = titleColumnWidth(width, config: row)
      // The title may take a second line when the row is happening or soon.
      var height = line
      if titleWraps(item, column: column, config: row) {
        height = max(line, 2 * textLine)
      }
      guard detailsVisible(item, config: row) else { return height }
      return height + detailHeight(item, column: column, config: row)
        + row.smallLineHeight / 3
    }
  }

  /// Width left for an event's title and details once the time keyline, time
  /// bar and column spacing are taken.
  private func titleColumnWidth(_ width: CGFloat, config row: RowViewConfig) -> CGFloat {
    let bar = row.showTimeBars ? row.fontSize : 0
    return max(0, width - row.keyline - bar - row.columnSpacing * 2)
  }

  /// Characters per line, from a mean advance of 0.55 em: generous for SF, so
  /// a wrap is over- rather than under-predicted. Over-predicting costs a row
  /// of whitespace; under-predicting slices the last row.
  private func charactersPerLine(_ column: CGFloat, fontSize: CGFloat) -> Int {
    max(8, Int(column / (fontSize * 0.55)))
  }

  /// EventRowView's lineLimit(2) on the title.
  private func titleWraps(_ item: EventEntry, column: CGFloat, config row: RowViewConfig) -> Bool {
    guard !heightIsLimited, item.isHappening(entry.date) || item.isSoon(entry.date),
          let title = (item.item as? EKEvent)?.title else { return false }
    return title.count > charactersPerLine(column, fontSize: row.fontSize)
  }

  /// EventRowView's gate on the detail block.
  private func detailsVisible(_ item: EventEntry, config row: RowViewConfig) -> Bool {
    guard !heightIsLimited, item.item != nil else { return false }
    guard item.isHappening(entry.date) || item.isSoon(entry.date) else { return false }
    return item.hasAttachments || item.hasLocation || item.hasNotes
  }

  /// The detail block: every line is at least smallLineHeight tall; a note
  /// that wraps (lineLimit(2)) is two small text lines.
  private func detailHeight(_ item: EventEntry, column: CGFloat, config row: RowViewConfig) -> CGFloat {
    let small = row.smallLineHeight
    var lines = 0
    if let locations = item.locations, !locations.isEmpty { lines += 1 }
    lines += item.attachments?.count ?? 0
    if let event = item.item as? EKEvent, event.hasAttendees { lines += 1 }
    var height = CGFloat(lines) * small
    if let notes = item.notes, notes.characters.count > 1 {
      let text = String(notes.characters)
      let wraps = text.contains("\n")
        || text.count > charactersPerLine(column, fontSize: row.smallFontSize)
      height += wraps ? max(small, 2 * small / lineSpread) : small
    }
    return height
  }

  /// `items` with any trailing orphaned day header removed, so dropping the
  /// last event of a day never leaves its header dangling.
  private func trimmed(_ items: [EventEntry]) -> [EventEntry] {
    guard let last = items.lastIndex(where: { $0.removeIfOrphaned != true }) else { return items }
    return Array(items[...last])
  }

  private func rowStack(_ items: [EventEntry], config row: RowViewConfig) -> some View {
    let content = entry.config.content
    return VStack(spacing: 0) {
      ForEach(items, id: \.self) { entry in
        if let event = entry.item as? EKEvent {
          EventRowView(event: event, entry: entry, config: row)
        } else if let reminder = entry.item as? EKReminder {
          ReminderRowView(reminder: reminder, entry: entry, config: row)
        } else if entry.type == "error" {
          ErrorRowView(entry: entry, config: row)
        } else if entry.type == "header" {
          #if !os(watchOS)
          let large = !widthIsLimited && !heightIsLimited && content == .calendar
          HeaderRowView(entry: entry, config: row, large: large)
          #else
          HeaderRowView(entry: entry, config: row, large: false)
          #endif
        } else if entry.type == "free" {
          FreeRowView(entry: entry, config: row)
        } else if entry.type == "timezone" {
          TimeZoneRowView(entry: entry, config: row)
        } else if let weather = entry.weather {
          CurrentWeatherRowView(entry: entry, weather: weather, config: row)
        } else if let forecast = entry.hourForecast {
          HourlyWeatherRowView(entry: entry, forecast: forecast, config: row)
        } else if let forecast = entry.dayForecast {
          DailyWeatherRowView(entry: entry, forecast: forecast, config: row)
        } else  {
          HeaderRowView(entry: entry, config: row, large: false)
        }
      }
    }
  }
  
}


#if os(watchOS)
let widgetFamilies: [WidgetFamily] = [
  .accessoryRectangular
]
#elseif os(iOS)
// iOS 27's page-size widget. The case is availability-gated until the
// iOS 27 SDK, but exists in the runtime framework; construct it via the
// public rawValue init, matched by description so a raw-value shift can
// never select the wrong family.
let extraLargePortraitFamily: WidgetFamily? = (0..<16)
  .compactMap(WidgetFamily.init(rawValue:))
  .first { $0.description == "systemExtraLargePortrait" }

let widgetFamilies: [WidgetFamily] = [
  .accessoryRectangular,
  .systemSmall,
  .systemMedium,
  .systemLarge,
  .systemExtraLarge
] + (extraLargePortraitFamily.map { [$0] } ?? [])
#elseif os(macOS)
let widgetFamilies: [WidgetFamily] = [
  .systemSmall,
  .systemMedium,
  .systemLarge,
  .systemExtraLarge
]
#endif


// MARK: ChronographWidget
struct ChronographWidget: Widget {
  let kind: String = "calendar"
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: CalendarWidgetIntent.self,
      provider: ChronographTimelineProvider<CalendarWidgetIntent>()) { ChronographWidgetView(entry: $0)

              .containerBackground(.clear, for: .widget)
      }
      .contentMarginsDisabled()
      .configurationDisplayName("Calendar")
//      .description("A text view of events or reminders")
      .supportedFamilies(widgetFamilies)
#if os(iOS)
      .disfavoredLocations([.homeScreen], for: [.systemSmall, .systemLarge, .systemExtraLarge])
#endif
  }
}

struct RemindersWidget: Widget {
  let kind: String = "reminders"
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: RemindersWidgetIntent.self,
      provider: ChronographTimelineProvider<RemindersWidgetIntent>()) {
        ChronographWidgetView(entry: $0)
      }
      .contentMarginsDisabled()
      .configurationDisplayName("Reminders")
//      .description("A text view of events or reminders")
      .supportedFamilies(widgetFamilies)
#if os(iOS)
      .disfavoredLocations([.homeScreen], for: [.systemSmall, .systemLarge, .systemExtraLarge])
#endif
  }
}

struct TimezonesWidget: Widget {
  let kind: String = "timezones"
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: TimezonesWidgetIntent.self,
      provider: ChronographTimelineProvider<TimezonesWidgetIntent>()) {
        ChronographWidgetView(entry: $0)
      }
      .contentMarginsDisabled()
      .configurationDisplayName("Time Zones")
//      .description("A text view of timezones")
      .supportedFamilies(widgetFamilies)
#if os(iOS)
      .disfavoredLocations([.homeScreen], for: [.systemSmall, .systemLarge, .systemExtraLarge] + (extraLargePortraitFamily.map { [$0] } ?? []))
#endif
  }
}

struct WeatherWidget: Widget {
  let kind: String = "weather"
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: WeatherWidgetIntent.self,
      provider: ChronographTimelineProvider<WeatherWidgetIntent>()) {
        ChronographWidgetView(entry: $0)
      }
      .contentMarginsDisabled()
      .configurationDisplayName("Weather")
//      .description("A text view of weather")
      .supportedFamilies(widgetFamilies)
#if os(iOS)
      .disfavoredLocations([.homeScreen], for: [.systemSmall, .systemLarge, .systemExtraLarge])
#endif
  }
}
