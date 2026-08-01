import WidgetKit
import SwiftUI
import EventKit



struct CustomToggleStyle: ToggleStyle {
  var onLabel: String
  var offLabel: String
  var onImageName: String
  var offImageName: String
  var onColor: Color
  var offColor: Color

  func makeBody(configuration: Configuration) -> some View {
    HStack {
      Link(destination: URL(string: "https://www.google.com")!) {
        Text(configuration.isOn ? onLabel : offLabel)
          .font(.headline)

      }
      Image(systemName: configuration.isOn ? onImageName : offImageName)
        .resizable()
        .frame(width: 24, height: 24)
        .foregroundColor(configuration.isOn ? onColor : offColor)
      configuration.label
    }
    .padding()
  }
}

struct ChronographWidgetView : View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.widgetContentMargins) var margins
  @Environment(\.widgetRenderingMode) var widgetRenderingMode
  @Environment(\.showsWidgetContainerBackground) var showsWidgetContainerBackground
  @Environment(\.widgetFamily) var widgetFamily
  @AppStorage(Keys.tokenizeParens, store: UserDefaults(suiteName: Keys.suiteName)) private var tokenize = false
  @AppStorage(Keys.compactTime, store: UserDefaults(suiteName: Keys.suiteName)) private var compactTime = true
  @AppStorage(Keys.brailleMode, store: UserDefaults(suiteName: Keys.suiteName)) private var brailleMode = false
  @AppStorage(Keys.fullBleed, store: UserDefaults(suiteName: Keys.suiteName)) private var wantsFullBleed = true
  
//  @AppStorage("KEY", store: UserDefaults(suiteName: Keys.suiteName)) private var defaultValueTest1 = "test1"
  
  @AppStorage("view") private var defaultValueTest2 = "view"
  
  @State private var eventStore = EKEventStore()
  @State private var visibleItemCount: Int
  @State private var extraSpace: CGFloat = 0.0
  
  @State private var toggled = false
  
  
  private var isAccessory = false
  private var heightIsLimited = false
  private var widthIsLimited = false
  private var fullBleed: Bool = false
  
  private var lineHeight: CGFloat = 10.0
  private var fontSize: CGFloat = 16.0
  
  let textStyle: UIFont.TextStyle
  var entry: TimelineProvider.Entry
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
  init(entry: TimelineProvider.Entry) {
    self.entry = entry
    self.context = entry.context
    self.textStyle = FontSize.caseSize[entry.config.fontSize] ?? .body
    
    let widgetFamily = context?.family
    
#if os(watchOS)
    self.isAccessory = true
    self.heightIsLimited = true
    self.widthIsLimited = true
    let isIOS = false
#elseif os(macOS)
    self.isAccessory = false
    self.heightIsLimited = isAccessory
    self.widthIsLimited = isAccessory || (widgetFamily == .systemSmall)
    let isIOS = false
#else
    self.isAccessory = (widgetFamily == .accessoryRectangular)
    self.heightIsLimited = isAccessory || widgetFamily == .systemSmall
    self.widthIsLimited = isAccessory || (widgetFamily == .systemSmall)
    let isIOS = true
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
    
    self.lineHeight = self.lineHeight * (self.isAccessory ? 1.0 : 1.5)
    
  
    var visibleCount = 30
    if let displaySize = entry.context?.displaySize {
//      print("font: \(baseFont.lineHeight) \(self.fontSize) \(self.lineHeight) \(displaySize.height) \(widgetFamily?.debugDescription ?? "")")
      visibleCount = Int(floor(displaySize.height / self.lineHeight))
    }
    _visibleItemCount = State(initialValue: visibleCount)
    
    
    //    print("\n Init view \(widgetFamily).\(entry.config.content) \(shortTimeFormatter.string(from:entry.date)) ")
  }
  
  var defaults = UserDefaults.standard
  
  // MARK: body
  var body: some View {
    
    // Preliminary tests of intents and toggles
//    HStack {
//      let selectedTab = defaults.string(forKey: "view")
//      
//      Button(intent: SetDefault("reminders", for: "view")) {
//        Image(systemName: "checkmark.square")
//      }
//      .foregroundColor(selectedTab == "reminders" ? .red : .blue)
//      
//      
//      Button(intent: SetDefault("calendar", for: "view")) {
//        Image(systemName: "calendar")
//      }
//      .foregroundColor(selectedTab == "calendar" ? .red : .blue)
//      
//      let isOn = defaults.string(forKey: "isOn") == "true"
//      Toggle(isOn: isOn, intent: SetDefault(isOn ? "false" : "true", for: "isOn")) {
//        
//      }
//      .toggleStyle(CustomToggleStyle(
//        onLabel: "On",
//        offLabel: "Off",
//        onImageName: "checkmark.circle.fill",
//        offImageName: "circle",
//        onColor: .green,
//        offColor: .gray
//      ))
//    }.hidden()
    

    let content = entry.config.content
    let now = Date()
    
    let backgroundColor = Color.withHex(entry.config.backgroundColor) ?? .clear
    
    let isDark = backgroundColor == .clear ? colorScheme == .dark : backgroundColor.isDark()
    
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
      
      config.font = brailleMode ? Font.custom("Ishihara", size: config.fontSize) :
      Font.system(size: config.fontSize, design: design).width(.standard)
      config.smallFont =  brailleMode ? Font.custom("Ishihara", size: config.fontSize) :
      Font.system(size: config.fontSize * 0.66, design: design).weight(.semibold)
      config.smallLineHeight = config.lineHeight * 0.66
      config.smallFontSize = config.fontSize * (brailleMode ? 1.0 : 0.66)
      
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
      config.compactTime = compactTime && !brailleMode
      config.brailleMode = false
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
    let filteredItems = items.filter { $0.isVisible() }
    
    let offsetCount = entry.config.pageOffset * visibleItemCount
    let clippedItems: [EventEntry] = Array(items[min(filteredItems.count, offsetCount) ..< min(filteredItems.count, offsetCount + visibleItemCount)])
    let index = clippedItems.lastIndex { $0.removeIfOrphaned != true}
    let visibleItems =  index != nil ?  Array(clippedItems[...index!]) : clippedItems
    let extraSpacing = 0.0 // extraSpace < (row.lineHeight) ? CGFloat(extraSpace) / CGFloat(visibleItemCount) : 0
    
    
    GeometryReader { container in
      VStack(spacing: extraSpacing) {
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
        
        .background(GeometryReader {
          Color.clear.preference(key: RowHeightPreferenceKey.self, value: [$0.frame(in: .named("stack")).maxY])
        })
      }
      
      .frame(maxHeight: .infinity, alignment: .top)
      .frame(maxWidth: .infinity, alignment: .top)
      .padding(.top, insets.top)
      .padding(.bottom, insets.bottom)
      .padding(.leading, insets.leading)
      .padding(.trailing, insets.trailing)
      .coordinateSpace(name: "stack")
      .tint(row.accentColor)
      
      .onPreferenceChange(RowHeightPreferenceKey.self) { heights in
        updateVisibleRows(with: heights, containerHeight: container.size.height)
      }
      
      .clipped()
      .environment(\.colorScheme, isDark ?  .dark : .light)
      .background(widgetRenderingMode == .accented ? .clear : backgroundColor)
    }
    
      .containerBackground(.clear, for: .widget)
    //    let _ = print("Rendered \(widgetFamily).\(entry.config.content) for \(shortTimeFormatter.string(from:entry.date)) \(visibleItemCount) in \(round(-now.timeIntervalSinceNow * 1000))ms")
  }
  
  private func updateVisibleRows(with rowMaxY: [CGFloat], containerHeight: CGFloat) {
    let visibleCount = rowMaxY.indices.last { index in
      let maxY = rowMaxY[index]
      return maxY <= containerHeight + 2
    }
    
    if let visibleCount = visibleCount, visibleItemCount != visibleCount + 1 {
      visibleItemCount = visibleCount + 1
      extraSpace = containerHeight - rowMaxY[visibleCount]
    }
  }
}

struct RowHeightPreferenceKey: PreferenceKey {
  static var defaultValue: [CGFloat] = []
  static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
    value.append(contentsOf: nextValue())
  }
}


#if os(watchOS)
let widgetFamilies: [WidgetFamily] = [
  .accessoryRectangular
]
#elseif os(iOS)
let widgetFamilies: [WidgetFamily] = [
  .accessoryRectangular,
  .systemSmall,
  .systemMedium,
  .systemLarge,
  .systemExtraLarge
]
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
      intent: ConfigurationIntent.self,
      provider: TimelineProvider(kind: kind)) { ChronographWidgetView(entry: $0)
          
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
      intent: ConfigurationIntent.self,
      provider: TimelineProvider(kind: kind)) {
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
      intent: ConfigurationIntent.self,
      provider: TimelineProvider(kind: kind)) {
        ChronographWidgetView(entry: $0)
      }
      .contentMarginsDisabled()
      .configurationDisplayName("Timezones")
//      .description("A text view of timezones")
      .supportedFamilies(widgetFamilies)
#if os(iOS)
      .disfavoredLocations([.homeScreen], for: [.systemSmall, .systemLarge, .systemExtraLarge])
#endif
  }
}

struct WeatherWidget: Widget {
  let kind: String = "weather"
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: ConfigurationIntent.self,
      provider: TimelineProvider(kind: kind)) {
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
