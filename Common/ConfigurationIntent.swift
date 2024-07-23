//
//  AppIntent.swift
//  widget
//
//  Created by Nicholas Jitkoff on 1/4/24.
//

import WidgetKit
import AppIntents
import SwiftUI


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

struct ConfigurationIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Configuration"
  static var description = IntentDescription("Chronograph")
  
  @Parameter(title: "Show", default: .calendar)
   var content: DisplayedContent
  
  @Parameter(title: "Calendars", default: [])
  var calendars: [CalendarSelectionEntity]
  
  @Parameter(title: "Reminders", default: [])
  var reminders: [CalendarSelectionEntity]

  @Parameter(title: "Font Style", default: .normal)
   var fontStyle: FontStyle
  
  @Parameter(title: "Font Size", default: .medium)
   var fontSize: FontSize
  
  @Parameter(title: "Background (Hex)", default: "")
  var backgroundColor: String
  
  @Parameter(title: "Accent (Hex)", default: "")
  var accentColor: String
  
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
    config.showColors = true
    config.fullBleed = false
    return config
  }
  
  static var remindersConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .reminders
    config.calendars = []
    config.fontStyle = .normal
    config.showColors = true
    config.fullBleed = false
    return config
  }
  
  static var comboConfig: ConfigurationIntent {
    let config = ConfigurationIntent()
    config.content = .both
    config.calendars = []
    config.fontStyle = .normal
    config.showColors = true
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
          \.$calendars
          \.$fontStyle
          \.$fontSize
          \.$backgroundColor
          \.$accentColor
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
          \.$fontSize
          \.$backgroundColor
          \.$accentColor
          \.$showColors
          \.$fullBleed
        }
      }
      
      Case(DisplayedContent.reminders) {
        Summary {
          \.$content
//          \.$reminders
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
