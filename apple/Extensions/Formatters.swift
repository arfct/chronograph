
import SwiftUI

var relativeDateFormatter: RelativeDateTimeFormatter {
  let formatter = RelativeDateTimeFormatter()
  formatter.dateTimeStyle = .named
  formatter.unitsStyle = .abbreviated
  return formatter
}


var relativeDateFormatterDay: DateFormatter {
  let formatter = DateFormatter()
  
  formatter.dateStyle = .short
  formatter.timeStyle = .none
  
  formatter.doesRelativeDateFormatting = true
  return formatter
}



var percentFormatter: NumberFormatter {
  let formatter = NumberFormatter()
  formatter.numberStyle = .percent
  formatter.maximumFractionDigits = 2
  return formatter
}

var dayOfWeekFormat: DateFormatter  {
  let formatter = DateFormatter()
  formatter.dateFormat = "EEE"
  return formatter
}

var dayOfMonthFormat: DateFormatter  {
  let formatter = DateFormatter()
  formatter.dateFormat = "d"
  return formatter
}

extension Measurement where UnitType == UnitTemperature {
  /// The user's preferred temperature unit — °F or °C per system locale.
  var localizedUnit: Measurement<UnitTemperature> {
    converted(to: UnitTemperature(forLocale: .current))
  }
}
