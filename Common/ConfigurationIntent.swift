import WidgetKit
import AppIntents
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum FontStyle: String, AppEnum {
    case normal, rounded, serif, monospace, condensed, compressed
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Font Style"
    static var caseDisplayRepresentations: [FontStyle : DisplayRepresentation] = [
        .normal: "Normal",
        .rounded: "Rounded",
        .serif: "Serif",
        .monospace: "Monospace",
        .condensed: "Condensed",
        .compressed: "Compressed",
    ]
}


enum WeatherStyle: String, AppEnum {
  case current, hourly, daily
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Weather Style"
  static var caseDisplayRepresentations: [WeatherStyle : DisplayRepresentation] = [
    .current: "Current",
    .hourly: "Hourly",
    .daily: "Daily"
  ]
}

enum FontSize: String, AppEnum {
    case tiny, small, medium, large, huge
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Font Size"
  static var caseDisplayRepresentations: [FontSize : DisplayRepresentation] = [
    .tiny: "Tiny",
    .small: "Small",
    .medium: "Medium",
    .large: "Large",
    .huge: "Huge",
  ]
  
  static var caseSize: [FontSize : UIFont.TextStyle] = [
    .tiny: .caption2,
    .small: .footnote,
    .medium: .body,
    .large: .title3,
    .huge: .title1,
  ]
  static var caseMinLines: [FontSize : Int] = [
    .tiny: 6,
    .small: 5,
    .medium: 4,
    .large: 3,
    .huge: 2,
  ]
}

enum DisplayedContent: String, AppEnum {
    case calendar, reminders, timezones, weather
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Displayed Content"
    static var caseDisplayRepresentations: [DisplayedContent : DisplayRepresentation] = [
      .calendar: "Calendar",
      .reminders: "Reminders",
      .timezones: "World Clock",
      .weather: "Weather"
    ]
}




enum WidgetFeatures: String, AppEnum {
    case allDayEvents, multiDayEvents, weather, timeBars, freeTime //, alternateCalendarIndicators
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar Content"
    static var caseDisplayRepresentations: [WidgetFeatures : DisplayRepresentation] = [
      .allDayEvents: DisplayRepresentation(title: "All-day", subtitle:"Events lasting all day", image: .init(systemName: "rectangle.grid.1x2")),
      .multiDayEvents: DisplayRepresentation(title: "Multi-day", subtitle:"Events spanning one day", image: .init(systemName: "square.grid.3x1.below.line.grid.1x2", tintColor: UIColor.blue, symbolConfiguration:.preferringMulticolor())),
      .weather: DisplayRepresentation(title: "Weather", image: .init(systemName: "cloud.sun.rain.fill", symbolConfiguration:.preferringMulticolor())),
      .timeBars: DisplayRepresentation(title: "Time Bars", image: .init(systemName: "calendar.day.timeline.leading", symbolConfiguration:.preferringMulticolor())),
      .freeTime: DisplayRepresentation(title: "Free Time", image: .init(systemName: "water.waves", symbolConfiguration:.preferringMulticolor())),
     //.alternateCalendarIndicators: DisplayRepresentation(title: "Calendar Indicators", image: .init(systemName: "paintpalette", symbolConfiguration:.preferringMulticolor())),
   ]
}

enum WidgetViewOptions: String, AppEnum {
    case showColors, fullBleed //, alternateCalendarIndicators
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "View Options"
    static var caseDisplayRepresentations: [WidgetViewOptions : DisplayRepresentation] = [
      .showColors: DisplayRepresentation(title: "Show Colors", image: .init(systemName: "paintpalette", symbolConfiguration:.preferringMulticolor())),
      .fullBleed: DisplayRepresentation(title: "Remove Padding", image: .init(systemName: "arrowshape.left.arrowshape.right", symbolConfiguration:.preferringMulticolor())),
   ]
}




struct ConfigurationIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Configuration"
  static var description = IntentDescription("Chronograph")
  
  @Parameter(title: "Widget Type", default: .calendar)
   var content: DisplayedContent
  
  @Parameter(title: "Show", default: [.allDayEvents, .timeBars])
   var features: [WidgetFeatures]
  
  @Parameter(title: "Calendars", default: [])
  var calendars: [CalendarSelectionEntity]
  
  @Parameter(title: "Lists", default: [])
  var reminders: [ReminderSelectionEntity]
  
  @Parameter(title: "Time Zones", default: [])
  var timezones: [TimeZoneSelectionEntity]
  
  @Parameter(title: "Weather Style", default: .current)
  var weatherStyle: WeatherStyle

  @Parameter(title: "View Options", default: [])
  var viewOptions: [WidgetViewOptions]

  @Parameter(title: "Font Style", default: .normal)
   var fontStyle: FontStyle
    
  @Parameter(title: "Font Size", default: .medium)
   var fontSize: FontSize
  
  @Parameter(title: "Background (Hex)", description:"Hex", default: "")
  var backgroundColor: String
  
  @Parameter(title: "Accent (Hex)", default: "")
  var accentColor: String

  
//  @Parameter(title: "Draw to Edges", default: false)
//  var fullBleed: Bool
  
  @Parameter(title: "Skip Pages", default: 0)
  var pageOffset: Int
  
  static var calendarConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .calendar
    config.calendars = []
    config.features = [.allDayEvents, .timeBars, .multiDayEvents]
    config.fontStyle = .normal
    
    return config
  }
  
  static var remindersConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .reminders
    config.reminders = []
    config.fontStyle = .normal
    
    return config
  }
  
  static var timezonesConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .timezones
    config.timezones = [
      TimeZoneSelectionEntity(id: "America/Los_Angeles", title: "Los Angeles", subtitle:nil, color:nil),
      TimeZoneSelectionEntity(id: "America/New_York", title: "New York City", subtitle:nil, color:nil),
      TimeZoneSelectionEntity(id: "Europe/London", title: "London", subtitle:nil, color:nil),
      TimeZoneSelectionEntity(id: "Asia/Tokyo", title: "Tokyo", subtitle:nil, color:nil)
      ]
    return config
  }
  
  static var weatherConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .weather
    return config
  }
  
  static var weatherCurrentConfig: ConfigurationIntent {
    var config = weatherConfig
    config.weatherStyle = .current
    return config
  }
  
  static var weatherHourlyConfig: ConfigurationIntent {
    var config = weatherConfig
    config.weatherStyle = .hourly
    return config
  }
  
  static var weatherDailyConfig: ConfigurationIntent {
    var config = weatherConfig
    config.weatherStyle = .daily
    return config
  }
  
  static var comboConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .calendar
    config.calendars = []
    config.features = [.allDayEvents, .timeBars, .multiDayEvents, .weather]
    config.fontStyle = .normal
    
    return config
  }
  static var simpleCalendarConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .calendar
    config.calendars = []
    config.features = [.allDayEvents]
    config.fontStyle = .normal
    
    return config
  }
  
  
  static var appComboConfig: ConfigurationIntent {
    let config = comboConfig
    config.accentColor = "#db4437"
    config.features = config.features
    config.viewOptions = [.showColors]
    return config
  }
  
  static var bigAppComboConfig: ConfigurationIntent {
    let config = appComboConfig
    config.fontSize = .huge
    return config
  }
  

  
  static var parameterSummary: some ParameterSummary {
    Switch(\.$content) {
      Case(DisplayedContent.calendar) {
        Summary {
          \.$content
          \.$calendars
          \.$features
          \.$fontStyle
          \.$fontSize
          \.$viewOptions
          \.$backgroundColor
          \.$accentColor
          
        }
      }

      
      Case(DisplayedContent.reminders) {
        Summary {
          \.$content
          \.$reminders
          \.$fontStyle
          \.$fontSize
          \.$viewOptions
          \.$backgroundColor
          \.$accentColor
          
        }
      }

      Case(DisplayedContent.timezones) {
        Summary {
          \.$content
          \.$timezones
          \.$fontStyle
          \.$fontSize
          \.$viewOptions
          \.$backgroundColor
          \.$accentColor
        }
      }
      
      
      Case(DisplayedContent.weather) {
        Summary {
          \.$content
          \.$weatherStyle
          \.$fontStyle
          \.$fontSize
          \.$viewOptions
          \.$backgroundColor
          \.$accentColor
        }
      }

      DefaultCase {
        Summary {
          \.$content
        }
      }
    }

  }
}
