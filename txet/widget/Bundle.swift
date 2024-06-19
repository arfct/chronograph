//
//  widgetBundle.swift
//  widget
//
//  Created by Nicholas Jitkoff on 6/13/24.
//

import WidgetKit
import SwiftUI

@main
struct widgetBundle: WidgetBundle {
  var body: some Widget {
    widgetReminders()
    widgetCalendar()
    widgetControl()
    widgetLiveActivity()
  }
}
