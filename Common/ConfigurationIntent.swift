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
    .timezones: "Time Zones",
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


