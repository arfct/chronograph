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
    self.textStyle = FontSize.caseSize[entry.config.fontSize] ?? .body
    
    let widgetFamily = context?.family
    
    // Accessory rows are packed tight; everywhere else lines get 1.5x leading.
    let lineSpread: CGFloat
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
    
    
    if let minLines = FontSize.caseMinLines[entry.config.fontSize],
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

    let content = entry.config.content
    
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
    let clippedItems: [EventEntry] = Array(filteredItems[min(filteredItems.count, offsetCount) ..< min(filteredItems.count, offsetCount + visibleItemCount)])
    let index = clippedItems.lastIndex { $0.removeIfOrphaned != true}
    let visibleItems =  index != nil ?  Array(clippedItems[...index!]) : clippedItems


    GeometryReader { container in
      VStack(spacing: 0) {
        ForEach(visibleItems, id: \.self) { entry in
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
