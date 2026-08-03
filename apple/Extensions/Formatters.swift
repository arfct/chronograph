
import SwiftUI

func convertToSuperscript(time: String) -> String {
  let superscriptDigits = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
  let regex = try! NSRegularExpression(pattern: "([0-9]+):([0-9]{2})")
  let range = NSRange(location: 0, length: time.utf16.count)
  
  let matches = regex.matches(in: time, options: [], range: range)
  guard let match = matches.first else { return time }
  
  let hourRange = Range(match.range(at: 1), in: time)!
  let minuteRange = Range(match.range(at: 2), in: time)!
  
  let hour = String(time[hourRange])
  let minute = String(time[minuteRange]).compactMap { superscriptDigits[String($0)] }.joined()
  
  return hour + minute
}

var shortTimeFormatter: DateFormatter {
  let formatter = DateFormatter()
  formatter.dateFormat = "H:mm"
  return formatter
}


var relativeDateFormatter: RelativeDateTimeFormatter {
  let formatter = RelativeDateTimeFormatter()
  formatter.dateTimeStyle = .named
  formatter.unitsStyle = .abbreviated
  return formatter
}


var amPmFormatter: DateFormatter {
  let formatter = DateFormatter()
  formatter.dateFormat = "a" // 'a' is used to get AM/PM
  return formatter
}

var relativeDateFormatterDay: DateFormatter {
  let formatter = DateFormatter()
  
  formatter.dateStyle = .short
  formatter.timeStyle = .none
  
  formatter.doesRelativeDateFormatting = true
  return formatter
}



var relativeTimeFormatter: DateComponentsFormatter {

  let formatter = DateComponentsFormatter()

  formatter.unitsStyle = .abbreviated
  formatter.allowedUnits = [.hour, .minute]
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

var dayOfWeekLongFormat: DateFormatter  {
  let formatter = DateFormatter()
  formatter.dateFormat = "EEEE"
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
