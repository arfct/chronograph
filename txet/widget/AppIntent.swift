//
//  AppIntent.swift
//  widget
//
//  Created by Nicholas Jitkoff on 1/4/24.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Configuration"
  static var description = IntentDescription("Txet Widget")
  
  @Parameter(title: "First Source")
  var source1: CalendarEntity
  
  @Parameter(title: "Second Source")
  var source2: CalendarEntity
  
  @Parameter(title: "Background Color", default: "")
  var backgroundColor: String
  
  @Parameter(title: "Full Bleed", default: false)
  var fullBleed: Bool
}
