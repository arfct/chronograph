import WidgetKit
import SwiftUI

@main
struct widgetBundle: WidgetBundle {
  var body: some Widget {
    ChronographWidget()
    RemindersWidget()
    TimezonesWidget()
    WeatherWidget()
#if os(iOS)
    ClockWidget()
#endif
  }
}
