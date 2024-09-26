import SwiftUI
import EventKit
import WeatherKit

struct TimeZoneRowView: View {
  var entry: EventEntry
  let config: RowViewConfig
  
  private var calendar: Calendar {
    var calendar = Calendar.current
    if let timeZone = entry.timeZone {
      calendar.timeZone = timeZone
    }
    return calendar
  }

  private var isNightTime: Bool {
    let hour = calendar.component(.hour, from: Date())
    return hour < 6 || hour >= 22
  }
  
  private var isLikelySleeping: Bool {
    let hour = calendar.component(.hour, from: Date())
    return hour >= 0 && hour < 7
  }
  
  private var isLikelyWorking: Bool {
    let hour = calendar.component(.hour, from: Date())
    return hour >= 8 && hour < 18
  }
  
  var daylightColors = ["#012459", "#001322", "#003972", "#001322", "#003972", "#001322", "#004372", "#00182b", "#004372", "#011d34", "#016792", "#00182b", "#07729f", "#042c47", "#12a1c0", "#07506e", "#74d4cc", "#1386a6", "#efeebc", "#61d0cf", "#fee154", "#a3dec6", "#fdc352", "#e8ed92", "#ffac6f", "#ffe467", "#fda65a", "#ffe467", "#fd9e58", "#ffe467", "#f18448", "#ffd364", "#f06b7e", "#f9a856", "#ca5a92", "#f4896b", "#5b2c83", "#d1628b", "#371a79", "#713684", "#28166b", "#45217c", "#192861", "#372074", "#040b3c", "#233072", "#040b3c", "#012459" ];

  private enum TimeOfDay {
    case sunrise
    case morning
    case day
    case endOfDay
    case evening
    case night
    case sleeping
    case dawn
    
    var icon: String {
      switch self {
      case .sunrise:
        return "sunrise"
      case .morning:
        return "sun.min"
      case .day:
        return "sun.max"
      case .endOfDay:
        return "sunset"
      case .evening:
        return "sun.haze"
      case .night:
        return "moon.stars.fill"
      case .sleeping:
        return "moon.zzz.fill"
      case .dawn:
        return "sun.dust"
      }
    }
    
    var color: Color {
      switch self {
      case .dawn:
        return Color.withHex("041D80")
      case .sunrise:
        return Color.withHex("00B2FF")
      case .morning:
        return Color.withHex("00B2FF")
      case .day:
        return Color.withHex("00B2FF")
      case .endOfDay:
        return Color.withHex("FAC22B")
      case .evening:
        return Color.withHex("FA732B")
      case .night:
        return Color.withHex("450063")
      case .sleeping:
        return Color.withHex("041D80")
      }
    }
  }
  
  private func getTimeOfDay(hour: Int) -> TimeOfDay {
    switch hour {
      
    case 6..<8:
      return .dawn
    case 8..<10:
      return .sunrise
    case 9..<11:
      return .morning
    case 11..<17:
      return .day
    case 17..<19:
      return .endOfDay
    case 19..<20:
      return .evening
    case 20..<22:
      return .night
    case 22..<23:
      return .sleeping
    default:
      return .night
    }
  }
  
  private var timeOfDay: TimeOfDay {
    getTimeOfDay(hour: calendar.component(.hour, from: Date()))
  }
  
  var body: some View {
    let hour = calendar.component(.hour, from: Date())
    
    let daylightGradient = LinearGradient(colors: [Color.withHex(daylightColors[hour * 2]), Color.withHex(daylightColors[hour * 2 + 1])], startPoint: .top, endPoint: .bottom)
      
    HStack(spacing: config.columnSpacing) {
      HStack {
        
        TimeStringView(entry: entry, config: config, date: Date(), timeZone: entry.timeZone, showAMPM: true)
//          .foregroundColor(isLikelySleeping ? .secondary : .primary)
          


      }.frame(minWidth:config.keyline, alignment:.trailing)
      
      .foregroundColor(isLikelySleeping ? .secondary : .primary)
//        .foregroundStyle(daylightGradient)
      
      Text(entry.title ?? "Timezone")
        .font(config.font)
        .foregroundColor(isLikelySleeping ? .secondary : .primary)
        .italic(isLikelySleeping)
        .lineLimit(1)
      
      
      
      
      Image(systemName: timeOfDay.icon)
        .font(config.font)
//        .foregroundColor(timeOfDay.color)
        .imageScale(.small)
      
        .foregroundStyle(daylightGradient)

    }
    .frame(maxWidth:.infinity, alignment:.leading)
  }
}


struct RowViewConfig {
  var entry: TimelineProvider.Entry
  var font: Font = .system(size: 14)
  var smallFont: Font = .system(size: 12)
  var fontSize: CGFloat = 14
  var smallFontSize: CGFloat = 12
  var lineHeight: CGFloat = 20
  var smallLineHeight: CGFloat = 16
  var keyline: CGFloat = 10
  var colorScheme: ColorScheme = .light
  var accentColor: Color?
  var defaultCalendar: EKCalendar? = nil
  var defaultRemindersList: EKCalendar? = nil
  var compactTime: Bool = false
  var tokenize: Bool = false
  var widthIsLimited: Bool = false
  var heightIsLimited: Bool = false
  
  var showTimeBars: Bool = false
  var columnSpacing: CGFloat = 4.0
}

var tempFormatter: MeasurementFormatter {
  let formatter = MeasurementFormatter()
  formatter.unitStyle = .medium
  formatter.numberFormatter.maximumFractionDigits = 0
  formatter.unitOptions = .temperatureWithoutUnit
  return formatter
}

var tempFormatterTrailing: MeasurementFormatter {
  let formatter = MeasurementFormatter()
  formatter.unitStyle = .short
  formatter.numberFormatter.maximumFractionDigits = 0
  formatter.unitOptions = .temperatureWithoutUnit
  return formatter
}

struct HourlyWeatherRowView: View {
  let entry: EventEntry
  let forecast: HourWeather
  let config: RowViewConfig

  var body: some View {
    if let date = entry.startDate {
      let (hour, minute, ampm) = date.formattedHourAndMinute()
      let timeString = Group {
        HStack(alignment:.center, spacing:0.5) {
          Text(hour).font(config.font.monospacedDigit())
            .kerning(-0.5)
          Text(minute).font(config.smallFont.monospacedDigit())
            .kerning(-0.5)
        }
        .frame(minWidth:config.keyline, alignment: .trailing)
        
      }
      
      HStack {
        timeString
        Image(systemName: forecast.symbolName)
          .font(config.font)
        Spacer()
        Text(forecast.temperature.converted(to: .fahrenheit), formatter: tempFormatter)
          .font(config.smallFont)
          .foregroundColor(.secondary)
        Text(NSNumber(value:forecast.precipitationChance), formatter:percentFormatter)
        
          .font(config.smallFont)
          .foregroundColor(.secondary)
      }
      .padding(.vertical, 4)
      .padding(.horizontal, 8)
      .frame(maxHeight:config.lineHeight)
    }
  }
}

struct DailyWeatherRowView: View {
  let entry: EventEntry
  let forecast: DayWeather
  let config: RowViewConfig

  var body: some View {
    if let date = entry.startDate {
      let (hour, minute, ampm) = date.formattedHourAndMinute()
      let timeString = Group {
        HStack(alignment:.center, spacing:0.5) {
          Text(dayOfWeekFormat.string(for:date) ?? "")
            .font(config.smallFont)
        }
        
        .frame(minWidth:config.keyline, alignment: .trailing)
      }
      
      HStack {
        timeString
        Image(systemName: forecast.symbolName)
          .font(config.font)
          .frame(minWidth:config.lineHeight * 1.125)
        Spacer()
        Text(forecast.lowTemperature.converted(to: .fahrenheit), formatter: tempFormatter)
          .font(config.font)
          .foregroundColor(.secondary)

        Rectangle()
          .fill(.tertiary)
          
          .frame(maxWidth:.infinity, maxHeight:2)

        Text(forecast.highTemperature.converted(to: .fahrenheit), formatter: tempFormatter)
          .font(config.font)
          .foregroundColor(.secondary)

        Text(NSNumber(value:forecast.precipitationChance), formatter:percentFormatter)
        
          .font(config.smallFont)
          .foregroundColor(.secondary)
          .opacity(forecast.precipitationChance)
      }
      .padding(.vertical, 4)
      .padding(.horizontal, 8)
      .frame(maxHeight:config.lineHeight)
    }
  }
}

struct CurrentWeatherRowView: View {
  let entry: EventEntry
  let weather: Weather
  let config: RowViewConfig

  var body: some View {

    if let date = entry.startDate {
      let (hour, minute, ampm) = date.formattedHourAndMinute()
      let timeString = Group {
        HStack(alignment:.center, spacing:0.5) {
          Text(hour).font(config.font.monospacedDigit())
            .kerning(-0.5)
          Text(minute).font(config.smallFont.monospacedDigit())
            .kerning(-0.5)
        }
      }
      let forecast = weather.currentWeather
      HStack {
        timeString
        
        Text("Current")
        Image(systemName: forecast.symbolName)
          .font(config.font)
        Spacer()
        Text(forecast.temperature.converted(to: .fahrenheit), formatter: tempFormatter)
          .font(config.smallFont)
          .foregroundColor(.secondary)
//        Text(NSNumber(value:forecast.), formatter:percentFormatter)
//          .font(config.smallFont)
//          .foregroundColor(.secondary)
      }
      .padding(.vertical, 4)
      .padding(.horizontal, 8)
      .frame(maxHeight:config.lineHeight)
    }
  }
}

struct TimeStringView: View {
  let entry: EventEntry
  let config: RowViewConfig
  var date: Date? = nil
  var timeZone: TimeZone? = nil
  var showAMPM: Bool = false
  
  
  var body: some View {
      
    if let displayDate = date ?? entry.startDate {
      let (hour, minute, ampm) = displayDate.formattedHourAndMinute(timeZone:timeZone)
      
      Group {
        if (config.compactTime) {
          HStack(alignment:.center, spacing:0.5) {
            Text(hour).font(config.font.monospacedDigit())
              .kerning(-0.5)
            
            if (showAMPM) {
              Text(ampm)
                .font(config.smallFont.monospacedDigit())
                .baselineOffset(config.fontSize * 0.24)
            } else {
              Text(minute).font(config.smallFont.monospacedDigit())
                .baselineOffset(config.fontSize * 0.24)
                .kerning(-0.5)
            }
            
          }
        } else {
          Text("\(hour):\(minute)")
            .font(config.font.monospacedDigit())
            .kerning(-0.5)
        }
      }
      .frame(minWidth:0, minHeight:config.lineHeight, alignment: .trailing)
    }
  }
}

struct TimeBarView: View {
  let entry: EventEntry
  let config: RowViewConfig
  let color: Color?
  
  var body: some View {
    let SFRegularStrokeWidthMultiple = 0.085
    VStack(alignment: .center, spacing:3) {
      RoundedRectangle(cornerRadius: .infinity)
        .fill((color ?? .secondary).opacity(0.5))
        .frame(maxWidth:SFRegularStrokeWidthMultiple * config.fontSize * 1.5)
      
    }
    .padding(.vertical, config.fontSize / 16)
  }
}
struct EventRowView: View {
  let event: EKEvent
  let entry: EventEntry
  let config: RowViewConfig
  
  var body: some View {
    let (hour, minute, ampm) = event.date.formattedHourAndMinute()
    
    
    let color = config.entry.configuration.features.contains(.calendarColors)
    ? event.color?.forScheme(scheme: config.colorScheme)
    : config.accentColor
    
    
    let hoursAway = Double(entry.startDate?.timeIntervalSince(config.entry.date) ?? 0.0) / 60.0 / 60.0
    let opacity = max(1.0, pow(1.0 - hoursAway / 4.0, 0.33))
    
    let isHappening = entry.isHappening()
    let isSoon = entry.isSoon()
    
    //    let availability = event.availability
    //    let attending = event.participantStatus
    
    let calendarId = event.calendar?.source?.sourceIdentifier ?? event.calendar?.calendarIdentifier ?? ""
    let eventid = "x-apple-calevent://\(calendarId)/\(event.calendarItemExternalIdentifier.replacingOccurrences(of: ":", with: "/"))"
    
//    let _ = print("Event", event.title ?? "",
//                  "\neid:", eventid,
//                  "\ncid:", event.calendarItemExternalIdentifier ?? "",
//                  "\ndid:", event.eventIdentifier)
    
    let title = (event.title.count > 0 ? event.title : nil) ?? "Untitled"
    
    HStack(alignment: .top, spacing:config.columnSpacing) {
      VStack(spacing: 0) {
        HStack {
          if (entry.hasConflict && entry.hasStartConflict) {
            
          } else {
            TimeStringView(entry:entry, config:config)
              .foregroundColor(.secondary)
              .widgetAccentable(true)
          }
        }
      }
      .frame(minWidth:config.keyline, alignment: .trailing)
      
      if (config.showTimeBars) {
        TimeBarView(entry: entry, config:config, color: color)
          .frame(minWidth:config.fontSize, maxHeight:.infinity)
      } else {
        Text("")
      }
      
      
      VStack(spacing: 0) {
        HStack(alignment: .center, spacing:2) {
          Link(destination: event.url ??
               URL(string:eventid)!) {
            let (emoji, remaining) = extractEmoji(from: title)
            
            
            if (config.tokenize) {
              TokenizedTextView(text:remaining, font:config.font, tokenFont:config.font)
            } else {
              HStack(alignment: .center, spacing:1) {
                Text(remaining)
                if emoji.count > 0 {
                  Text(emoji)
                    .font(config.smallFont)
                }
              }
              
            }
            
          }.font(config.font)
            .buttonStyle(.plain)
            .lineLimit(!config.heightIsLimited && (isHappening || isSoon) ? 2 : 1, reservesSpace: false)
            .fixedSize(horizontal: false, vertical: true)
          
          
          if (entry.hasConflict) {
            Image(systemName: "exclamationmark.triangle")
              .imageScale(.small)
              .font(config.font)
              .foregroundColor(.secondary)
          }
          if event.calendar != config.defaultCalendar,
             let initial = event.calendar?.title.first {
            Image(systemName: "\(String(initial).lowercased()).circle")
              .imageScale(.small)
              .font(config.font)
              .foregroundColor(color)
              .widgetAccentable()
            
              .layoutPriority(1)
          }
          
        }
        .frame(minHeight:config.lineHeight, maxHeight:.infinity)
        .opacity(opacity)
        
        .frame(maxWidth:.infinity, alignment: .bottomLeading)
        
        .clipped()
        
        if (!config.heightIsLimited && (isHappening || isSoon)
            && (entry.hasAttachments || entry.hasLocation) ) {
          
          
          VStack(alignment: .leading, spacing:0) {
            Group {
              if let locations = entry.locations, locations.count > 0 {
                HStack {
                  if let meeting = entry.meeting, let url = meeting.url {
                    Link(destination: url) {
                      HStack(spacing:4){
                        Image(systemName: "video")
                          .foregroundStyle(.secondary)
                        Text(meeting.title ?? "Video conference").foregroundStyle(.primary)
                      }
                    }
                    .buttonStyle(.plain)
                  }
                  Text("\(locations.joined(separator: ", "))")
                    .foregroundStyle(.secondary)
                    .italic()
                }
              }
              
              if let attachments = entry.attachments {
                ForEach(attachments, id: \.self) { document in
                  if let url = document.url {
                    Link(destination: url, label: {
                      HStack(spacing:4) {
                        Image(systemName: document.displayIcon)
                          .foregroundStyle(.secondary)
                        
                        if let prefix = document.prefix, prefix.count > 0 { Text(prefix).foregroundStyle(.secondary) }
                        Text(document.displayName).foregroundStyle(.primary)
                      }
                    })
                    .buttonStyle(.plain)
                  }
                }
              }
              if event.hasAttendees {
                FacePile(event: event)
                  .foregroundStyle(.secondary)
              }
              
              if let notes = entry.notes, notes.characters.count > 1 {
                Text(notes)
                  .multilineTextAlignment(.leading)
                  .lineLimit(2)
                  .foregroundStyle(.secondary)
              }
            }
            .foregroundStyle(.primary)
            .font(config.smallFont)
            .frame(maxWidth:.infinity, minHeight:config.smallLineHeight, alignment: .leading)
            .opacity(opacity)
          }
          .frame(maxWidth:.infinity, alignment:.leading)
          .padding(.bottom, config.smallLineHeight/3)
          
        }
      }
    }
    
    .fixedSize(horizontal: false, vertical: true)
  }
}

struct ReminderRowView: View {
  let reminder: EKReminder
  let entry: EventEntry
  let config: RowViewConfig
  
  var body: some View {
    let hoursAway = Double(entry.startDate?.timeIntervalSince(config.entry.date) ?? 0.0) / 60.0 / 60.0
    let opacity = max(1.0, pow(1.0 - hoursAway / 4.0, 0.33))
    
    HStack(alignment:.center, spacing: config.columnSpacing) {
      
      let circleView = HStack() {
        Image(systemName: "circle")
          .imageScale(.small)
          .font(config.font)
          .foregroundColor(config.accentColor)
          .widgetAccentable()
      }
        .frame(minWidth:config.fontSize, maxHeight:.infinity, alignment: .center)
      
      
      if (!config.widthIsLimited) {
        if (entry.startDate != nil && entry.item?.allDay == false) {
          TimeStringView(entry:entry, config:config)
            .foregroundColor(.secondary)
            .widgetAccentable(true)
            .frame(minWidth:config.keyline, alignment: .trailing)
        } else {
          Text("").frame(minWidth:config.keyline, alignment: .trailing)
        }
        circleView
      } else {
        circleView
        
          .frame(minWidth:config.keyline, alignment: .trailing)
      }
      
      
      
      
      Link(destination: reminder.url ?? URL(string:"x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)")!) {
        HStack {
          if (reminder.priority > 0) {
            Text(reminder.priority > 0 ? reminder.priorityPrefix : "")
              .font(config.font)
              .foregroundColor(.secondary)
              .widgetAccentable()
          }
          Group {
            if (config.tokenize) {
              Text(reminder.title ?? "No Title")
            } else {
              Text(reminder.title)
            }
          }
          .font(config.font)
          .lineLimit(1)
          .foregroundColor(.primary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .buttonStyle(.plain)
      
      if let components = reminder.dueDateComponents {
        let dueDate = components.date
        if components.hour != nil {
          
          Text(relativeDateFormatter.string(for: dueDate) ?? "due")
            .foregroundColor(.secondary)
            .font(config.font)
          
        } else if (config.entry.configuration.content == .reminders ){ // allDay
          Text(relativeDateFormatterDay.string(for: dueDate) ?? "due")
            .foregroundColor(.secondary)
            .font(config.font)
          
        }
      }
      
      
      //      if reminder.calendar != config.defaultRemindersList,
      //         let initial = reminder.calendar?.title.first {
      //        Image(systemName: "\(String(initial).lowercased()).circle")
      //          .imageScale(.small)
      //          .foregroundColor(config.accentColor)
      //          .widgetAccentable()
      //      }
      
      
    }
    .frame(maxWidth:.infinity, alignment: .leading)
    .frame(height: config.lineHeight)
    
    .opacity(opacity)
    
  }
}

struct FreeRowView: View {
  let entry: EventEntry
  let config: RowViewConfig
  
  var body: some View {
    let hoursAway = Double(entry.startDate?.timeIntervalSince(Date()) ?? 0.0) / 60.0 / 60.0
    let opacity = max(1.0, pow(1.0 - hoursAway / 4.0, 0.33))
    
    HStack(alignment: .center, spacing: config.columnSpacing) {
      
      HStack{}.frame(minWidth:config.keyline, alignment:.trailing)
      if (config.showTimeBars) {
        HStack {
          Image("Time Squiggle")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .font(config.smallFont)
            .foregroundStyle(.secondary)
            .opacity(0.667)
            .frame(width:config.fontSize, height:config.fontSize * 1.25)
        }
        .frame(minWidth:config.fontSize)
      }
      
      Text(entry.title ?? "Free")
        .font(config.smallFont)
        .italic()
        .foregroundColor(.secondary)
        .frame(minWidth:config.widthIsLimited ? config.keyline : 0, alignment:.bottomTrailing)
      
    }
    .frame(minHeight:config.lineHeight)
    .opacity(opacity)
    .frame(maxWidth:.infinity, alignment: .bottomLeading)
    
  }
}

struct ErrorRowView: View {
  let entry: EventEntry
  let config: RowViewConfig
  
  var body: some View {
    let hoursAway = Double(entry.startDate?.timeIntervalSince(Date()) ?? 0.0) / 60.0 / 60.0
    let opacity = max(1.0, pow(1.0 - hoursAway / 4.0, 0.33))
    
    HStack(alignment: .bottom) {
      if let destination = entry.url {
        Link(destination: destination){
          Text(entry.title ?? "Error")
        }
      }
    }
    .opacity(opacity)
    .frame(maxWidth:.infinity, minHeight: config.lineHeight * 1.5, alignment: .bottomLeading)
    
  }
}

struct HeaderRowView: View {
  let entry: EventEntry
  let config: RowViewConfig
  let large: Bool
  
  var body: some View {
    let hoursAway = Double(entry.startDate?.timeIntervalSince(Date()) ?? 0.0) / 60.0 / 60.0
    let opacity = max(1.0, pow(1.0 - hoursAway / 4.0, 0.33))
    
    
    
    let hasAllDayItems = entry.allDayItems?.count ?? 0 > 0
    
    let allDayItems = VStack(alignment:.leading) {
      HStack(alignment:.center) {
        if let allDayItems = entry.allDayItems?.prefix(config.widthIsLimited ? 2: 3) {
          let visibleItems = config.widthIsLimited ? allDayItems : allDayItems
          ForEach(visibleItems) { item in
            if let title = item.item?.title {
              let (emoji, remaining) = extractEmoji(from: title)
              Text(sanitizeAllDayEvents(remaining))
                .font(config.smallFont)
                .foregroundColor(Color.secondary)
                .lineLimit(1)
              //              if emoji.count > 0 {
              //                Text(emoji)
              //                  .font(config.smallFont)
              //              }
            }
          }
        }
      }
    }
    
    let forecastView =  HStack(spacing:0) {
      Text("")
      if let forecast = entry.dayForecast {
        (
        Text(Image(systemName: forecast.symbolName))
        + Text(" ")
        + Text(tempFormatter.string(from: forecast.lowTemperature.converted(to: .fahrenheit)).replacingOccurrences(of: "°", with: ""))
        + Text("–")
        + Text(forecast.highTemperature.converted(to: .fahrenheit), formatter: tempFormatterTrailing)
        + (forecast.precipitationChance > 0 ?
           Text(" ") + Text(Image(systemName: "drop")) +
           Text(NSNumber(value:forecast.precipitationChance), formatter:percentFormatter)
           : Text(""))
        )
          .lineLimit(1)
        
      }
    }.font(config.smallFont)
    
    
    
    if let startDate = entry.startDate,
       let shortDayName = dayOfWeekFormat.string(for:startDate),
       let shortDayNumber = dayOfMonthFormat.string(for:startDate)
    {
      
      let dayName =
      Text(shortDayName)
        .font(config.smallFont)
        .textCase(.uppercase)
        .lineLimit(1)
        .kerning(1)
        .monospaced()
        .widgetAccentable()
        .frame(minWidth:config.widthIsLimited ? config.keyline : 0, alignment:.trailing)
      
      let dayNumber = Text(shortDayNumber)
        .foregroundColor(config.accentColor)
      
      if (large) {
        HStack(alignment: .center, spacing: config.columnSpacing) {
          
          VStack() {
            dayNumber
              .font(.system(size: config.fontSize * 1.8).weight(.light))
          }.frame(width:config.keyline, alignment:.trailing)
          
          TimeBarView(entry: entry, config:config, color: config.accentColor )
            .frame(minWidth:config.fontSize, maxHeight:.infinity)
          
          
          VStack(alignment:.leading) {
            HStack(spacing:config.smallFontSize / 2) {
              dayName
              forecastView
            }
            allDayItems
          }
          .padding(.vertical, config.lineHeight / 2)
        }
        .frame(maxWidth:.infinity, minHeight: config.lineHeight, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        
      } else {
        HStack(alignment: .center, spacing: config.columnSpacing) {
          
          VStack() {
            dayName
          }.frame(minWidth:config.keyline, alignment:.trailing)
          
          if (!config.widthIsLimited) {
            VStack() {
              dayNumber
                .font(config.smallFont)
            }.frame(minWidth:config.fontSize, alignment:.center)
          }
          forecastView
          allDayItems
        }
        .padding(.top, config.heightIsLimited ? 0 : config.lineHeight / 2)
        .padding(.bottom, config.heightIsLimited ? 0 : config.lineHeight / 8)
        .frame(maxWidth:.infinity, minHeight: config.lineHeight, alignment: .leading)
      }
      
    }
  }
}
