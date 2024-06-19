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
  
  @Parameter(title: "Background Color", default: "")
  var backgroundColor: String
  
  @Parameter(title: "Draw to Edges", default: false)
  var fullBleed: Bool
  
  static var parameterSummary: some ParameterSummary {
    Switch(\.$content) {
      Case(DisplayedContent.reminders) {
        Summary {
          \.$content
          \.$reminders
          \.$fontStyle
          \.$backgroundColor
          \.$fullBleed
        }
      }
      Case(DisplayedContent.both) {
        Summary {
          \.$content
          \.$calendars
          \.$reminders
          \.$fontStyle
          \.$backgroundColor
          \.$fullBleed
        }
      }
      Case(DisplayedContent.calendar) {
        Summary {
          \.$content
          \.$calendars
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
