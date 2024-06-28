//
//  AppIntent.swift
//  widget
//
//  Created by Nicholas Jitkoff on 1/4/24.
//

import WidgetKit
import AppIntents


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

enum DisplayedContent: String, AppEnum {
    case calendar, reminders, both
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Displayed Content"
    static var caseDisplayRepresentations: [DisplayedContent : DisplayRepresentation] = [
        .calendar: "Calendar",
        .reminders: "Reminders",
        .both: "Both",
    ]
}

struct ConfigurationIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Configuration"
  static var description = IntentDescription("Txet Widget")
  
  @Parameter(title: "Show", default: .calendar)
   var content: DisplayedContent
  
  @Parameter(title: "Calendars", default: [])
  var calendars: [CalendarSelectionEntity]
  
  @Parameter(title: "Reminders", default: [])
  var reminders: [CalendarSelectionEntity]

  @Parameter(title: "Font Style", default: .normal)
   var fontStyle: FontStyle
  
  @Parameter(title: "Background (Hex)", default: "")
  var backgroundColor: String
  
  @Parameter(title: "Show All Day Events", default: false)
  var showAllDay: Bool
  
  @Parameter(title: "Show Item Colors", default: false)
  var showColors: Bool
  
  @Parameter(title: "Draw to Edges", default: false)
  var fullBleed: Bool
  
  @Parameter(title: "Skip Pages", default: 0)
  var pageOffset: Int
  
  static var calendarConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .calendar
    config.calendars = []
    config.fontStyle = .normal
    config.backgroundColor = ""
    config.fullBleed = false
    return config
  }
  
  static var calendar2Config: ConfigurationIntent {
    let config = calendarConfig
    config.pageOffset = 1
    return config
  }
  
  static var remindersConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .reminders
    config.calendars = []
    config.fontStyle = .normal
    config.backgroundColor = ""
    config.fullBleed = false
    return config
  }
  
  static var parameterSummary: some ParameterSummary {
    Switch(\.$content) {
      Case(DisplayedContent.calendar) {
        Summary {
          \.$content
          \.$calendars
          \.$fontStyle
          \.$backgroundColor
          \.$showColors
          \.$showAllDay
          \.$fullBleed
        }
      }
      
      Case(DisplayedContent.both) {
        Summary {
          \.$content
          \.$calendars
//          \.$reminders
          \.$fontStyle
          \.$backgroundColor
          \.$showColors
          \.$fullBleed
        }
      }
      
      Case(DisplayedContent.reminders) {
        Summary {
          \.$content
//          \.$reminders
          \.$fontStyle
          \.$backgroundColor
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
