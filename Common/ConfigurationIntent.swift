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
}

enum DisplayedContent: String, AppEnum {
    case calendar, reminders, both
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Displayed Content"
    static var caseDisplayRepresentations: [DisplayedContent : DisplayRepresentation] = [
        .calendar: "Calendar",
        .reminders: "Reminders",
        .both: "Both",
    ]
}

enum WidgetFeatures: String, AppEnum {
    case allDayEvents, multiDayEvents, /*weather,*/ calendarColors, timeBars, fullBleed //, alternateCalendarIndicators
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Included Content"
    static var caseDisplayRepresentations: [WidgetFeatures : DisplayRepresentation] = [
      .allDayEvents: DisplayRepresentation(title: "All-day", subtitle:"Events lasting all day", image: .init(systemName: "rectangle.grid.1x2")),
      .multiDayEvents: DisplayRepresentation(title: "Multi-day", subtitle:"Events spanning one day", image: .init(systemName: "square.grid.3x1.below.line.grid.1x2", tintColor: UIColor.blue, symbolConfiguration:.preferringMulticolor())),
//      .weather: DisplayRepresentation(title: "Weather", image: .init(systemName: "cloud.sun.rain.fill", symbolConfiguration:.preferringMulticolor())),
      .calendarColors: DisplayRepresentation(title: "Calendar Colors", image: .init(systemName: "paintpalette", symbolConfiguration:.preferringMulticolor())),
      .timeBars: DisplayRepresentation(title: "Time Bars", image: .init(systemName: "calendar.day.timeline.leading", symbolConfiguration:.preferringMulticolor())),
      .fullBleed: DisplayRepresentation(title: "Remove Padding", image: .init(systemName: "arrowshape.left.arrowshape.right", symbolConfiguration:.preferringMulticolor())),
     //.alternateCalendarIndicators: DisplayRepresentation(title: "Calendar Indicators", image: .init(systemName: "paintpalette", symbolConfiguration:.preferringMulticolor())),
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
  
  @Parameter(title: "Reminders", default: [])
  var reminders: [ReminderSelectionEntity]

  @Parameter(title: "Font Style", default: .normal)
   var fontStyle: FontStyle
  
  @Parameter(title: "Font Size", default: .medium)
   var fontSize: FontSize
  
  @Parameter(title: "Background (Hex)", default: "")
  var backgroundColor: String
  
  @Parameter(title: "Accent (Hex)", default: "")
  var accentColor: String

  
  @Parameter(title: "Draw to Edges", default: false)
  var fullBleed: Bool
  
  @Parameter(title: "Skip Pages", default: 0)
  var pageOffset: Int
  
  static var calendarConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .calendar
    config.calendars = []
    config.features = [.allDayEvents, .timeBars, .multiDayEvents]
    config.fontStyle = .normal
    config.fullBleed = false
    return config
  }
  
  static var remindersConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .reminders
    config.reminders = []
    config.fontStyle = .normal
    config.fullBleed = false
    return config
  }
  
  static var comboConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .both
    config.calendars = []
    config.features = [.allDayEvents, .timeBars, .multiDayEvents]
    config.fontStyle = .normal
    config.fullBleed = false
    return config
  }
  
  static var combo2Config: ConfigurationIntent {
    let config = comboConfig
    config.pageOffset = 1
    return config
  }
  
  static var parameterSummary: some ParameterSummary {
    Switch(\.$content) {
      Case(DisplayedContent.calendar) {
        Summary {
          \.$content
          \.$features
          \.$calendars
          \.$fontStyle
          \.$fontSize
          \.$backgroundColor
          \.$accentColor
          \.$fullBleed
        }
      }
      
      Case(DisplayedContent.both) {
        Summary {
          \.$content
          \.$calendars
//          \.$reminders
          \.$fontStyle
          \.$fontSize
          \.$backgroundColor
          \.$accentColor
          \.$fullBleed
        }
      }
      
      Case(DisplayedContent.reminders) {
        Summary {
          \.$content
          \.$reminders
          \.$fontStyle
          \.$fontSize
          \.$backgroundColor
          \.$accentColor
          \.$fullBleed
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
