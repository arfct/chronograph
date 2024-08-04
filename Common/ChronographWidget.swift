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
    self.textStyle = FontSize.caseSize[entry.configuration.fontSize] ?? .body
    
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
    self.fullBleed = entry.configuration.features.contains(.fullBleed)
#else
    self.fullBleed = widgetFamily == .accessoryRectangular || entry.configuration.features.contains(.fullBleed)
#endif
    
    let baseFont = UIFont.preferredFont(forTextStyle: textStyle)
    
    self.lineHeight = baseFont.lineHeight
    self.fontSize = baseFont.pointSize

    if let minLines = FontSize.caseMinLines[entry.configuration.fontSize],
       let height = entry.context?.displaySize.height {
      self.lineHeight = min(self.lineHeight, height / CGFloat(minLines))
      self.fontSize = self.lineHeight * baseFont.pointSize / baseFont.lineHeight
    }

    self.lineHeight = self.lineHeight * (heightIsLimited ? 1.0 : 1.5)
    
  
    var visibleCount = 30
    if let displaySize = entry.context?.displaySize {
      print("font: \(baseFont.lineHeight) \(self.fontSize) \(self.lineHeight) \(displaySize.height) \(widgetFamily?.debugDescription ?? "")")
      visibleCount = Int(floor(displaySize.height / self.lineHeight))
    }
    _visibleItemCount = State(initialValue: visibleCount)
    
    
    //    print("\n Init view \(widgetFamily).\(entry.configuration.content) \(shortTimeFormatter.string(from:entry.date)) ")
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
    

    
    let now = Date()
    
    let backgroundColor = entry.configuration.backgroundColor.count > 0 ?
    Color.withHex(entry.configuration.backgroundColor) : .clear
    
    let isDark = backgroundColor == .clear ? colorScheme == .dark : backgroundColor.isDark()
    
    let row = {
      var config = RowViewConfig(entry: entry)
      config.fontSize = fontSize
      config.lineHeight = lineHeight
      config.accentColor = entry.configuration.accentColor.count > 0 ?
      Color.withHex(entry.configuration.accentColor) : .secondary
      config.colorScheme = isDark ? .dark : .light
      config.keyline = config.fontSize * (compactTime ? 2.25 : 2.6)
      config.widthIsLimited = widthIsLimited
      config.heightIsLimited = heightIsLimited
      
      let design = designForFontStyle(entry.configuration.fontStyle)
      config.font = Font.system(size: config.fontSize, design: design).width(.standard)
      config.smallFont = Font.system(size: config.fontSize * 0.66, design: design).weight(.semibold)
      config.smallLineHeight = config.lineHeight * 0.66
      config.smallFontSize = config.fontSize * 0.66
      
      switch entry.configuration.fontStyle {
      case .compressed, .condensed:
        config.font = config.font.width(.compressed)
        config.smallFont = config.smallFont.width(.compressed)
      default:
        config.font = config.font.width(.standard)
      }
      
      config.columnSpacing = fontSize / 8
      config.defaultCalendar = eventStore.defaultCalendarForNewEvents
      // TODO: Infer default from number of events
      config.defaultRemindersList = eventStore.defaultCalendarForNewReminders()
      config.compactTime = compactTime
      config.tokenize = tokenize
      config.showTimeBars = entry.configuration.features.contains(.timeBars) && !widthIsLimited
      return config
    }()
    
    let hPadding = fullBleed ? margins.top / 3 : margins.leading
    let vPadding = isAccessory ? margins.top / 3 : margins.top / 2
    let insets = EdgeInsets(top: vPadding,
                            leading: min(hPadding, row.fontSize / 2),
                            bottom: vPadding,
                            trailing: hPadding)
    
    var items: [EventEntry] = []
    let _ = items.append(contentsOf: entry.events)
    let _ = items.append(contentsOf: entry.reminders.prefix(entry.configuration.content == .both ? (visibleItemCount / 2) : visibleItemCount))
    let filteredItems = items.filter { $0.isVisible() }
    
    let offsetCount = entry.configuration.pageOffset * visibleItemCount
    let clippedItems: [EventEntry] = Array(items[min(filteredItems.count, offsetCount) ..< min(filteredItems.count, offsetCount + visibleItemCount)])
    let index = clippedItems.lastIndex { $0.removeIfOrphaned != true}
    let visibleItems =  index != nil ?  Array(clippedItems[...index!]) : clippedItems
    let extraSpacing =  extraSpace < (row.lineHeight) ? CGFloat(extraSpace) / CGFloat(visibleItemCount) : 0
    
    GeometryReader { container in
      VStack(spacing: extraSpacing) {
        ForEach(visibleItems, id: \.self) { entry in
          if let event = entry.item as? EKEvent {
            EventRowView(event: event, entry: entry, config: row)
          } else if let reminder = entry.item as? EKReminder {
            ReminderRowView(reminder: reminder, entry: entry, config: row)
          } else if let forecast = entry.forecast {
            WeatherRowView(entry: entry, forecast: forecast, config: row)
          } else if entry.type == "error" {
            ErrorRowView(entry: entry, config: row)
          } else if entry.type == "header" {
            #if !os(watchOS)
            let large = !widthIsLimited && !heightIsLimited
            HeaderRowView(entry: entry, config: row, large: large)
            #else
            HeaderRowView(entry: entry, config: row, large: false)
            #endif
          } else if entry.type == "free" {
            FreeRowView(entry: entry, config: row)
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
    
    //    let _ = print("Rendered \(widgetFamily).\(entry.configuration.content) for \(shortTimeFormatter.string(from:entry.date)) \(visibleItemCount) in \(round(-now.timeIntervalSinceNow * 1000))ms")
  }
  
  private func updateVisibleRows(with rowMaxY: [CGFloat], containerHeight: CGFloat) {
    let visibleCount = rowMaxY.indices.last { index in
      let maxY = rowMaxY[index]
      return maxY <= containerHeight
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

// MARK: ChronographWidget
struct ChronographWidget: Widget {
  let kind: String = "calendar"
  
  var body: some WidgetConfiguration {
    
    let configuration = AppIntentConfiguration(
      kind: kind,
      intent: ConfigurationIntent.self,
      provider: TimelineProvider()) { entry in
        ChronographWidgetView(entry: entry)
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
    
//#if os(iOS) // This may only work for Controls
//    if #available(iOS 18.0, *) {
//      return configuration
//        .promptsForUserConfiguration()
//    }
//#endif
    return configuration
  }
}
