import WidgetKit
import SwiftUI

@main
struct widgetBundle: WidgetBundle {
  var body: some Widget {
    ChronographWidget()
    #if os(iOS)
    ClockWidget()
          #endif
  }
}
