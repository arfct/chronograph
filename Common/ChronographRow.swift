import SwiftUI
import EventKit
import WeatherKit


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
  static let columnSpacing = 4.0
}

var tempFormatter: MeasurementFormatter {
  let formatter = MeasurementFormatter()
  formatter.unitStyle = .medium
  formatter.numberFormatter.maximumFractionDigits = 0
  formatter.unitOptions = .temperatureWithoutUnit
  return formatter
}

struct WeatherRowView: View {
  let entry: EventEntry
  let forecast: HourWeather
  let config: RowViewConfig
  
  var percentFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = 2
    return formatter
  }
  
  var body: some View {
    
    if let date = entry.startDate {
      let (hour, minute) = date.formattedHourAndMinute()
      let timeString = Group {
        HStack(alignment:.center, spacing:0.5) {
          Text(hour).font(config.font.monospacedDigit())
            .kerning(-0.5)
          Text(minute).font(config.smallFont.monospacedDigit())
          //              .baselineOffset(fontSize * 0.24)
            .kerning(-0.5)
          
        }
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

struct TimeStringView: View {
  let entry: EventEntry
  let config: RowViewConfig
  
  var body: some View {
    if let date = entry.startDate {
      let (hour, minute) = date.formattedHourAndMinute()
      
      Group {
        if (config.compactTime) {
          HStack(alignment:.center, spacing:0.5) {
            Text(hour).font(config.font.monospacedDigit())
              .kerning(-0.5)
            Text(minute).font(config.smallFont.monospacedDigit())
              .baselineOffset(config.fontSize * 0.24)
              .kerning(-0.5)
          }
        } else {
          Text("\(hour):\(minute)")
            .font(config.font.monospacedDigit())
            .kerning(-0.5)
        }
      }
      .frame(minWidth:0, minHeight:config.lineHeight, maxHeight:.infinity, alignment: .trailing)
    }
    
  }
}

struct EventRowView: View {
  let event: EKEvent
  let entry: EventEntry
  let config: RowViewConfig
  
  var body: some View {
    let (hour, minute) = event.date.formattedHourAndMinute()
    
    
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
    
    let title = (event.title.count > 0 ? event.title : nil) ?? "Untitled"
    
    HStack(alignment: .top, spacing:RowViewConfig.columnSpacing) {
      VStack(spacing: 0) {
        HStack {
          if (entry.hasConflict && entry.hasStartConflict) {
            
          } else {
            TimeStringView(entry:entry, config:config)
              .foregroundColor(color ?? .primary)
              .widgetAccentable(true)
          }
        }
      }
      .frame(minWidth:config.keyline, alignment: .trailing)
      
      if (config.showTimeBars) {
        let SFRegularStrokeWidthMultiple = 0.085
        VStack(alignment: .center, spacing:3) {
          RoundedRectangle(cornerRadius: .infinity)
            .fill(color ?? .secondary)
            .frame(maxWidth:SFRegularStrokeWidthMultiple * config.fontSize)
          
        }
        .padding(.vertical, 4)
        .frame(minWidth:config.fontSize, maxHeight:.infinity)
      }
      
      
      VStack(spacing: 0) {
        HStack(alignment: .center, spacing:2) {
          Link(destination: event.url ??
               URL(string:eventid)!) {
            
            if (config.tokenize) {
              TokenizedTextView(text:title, font:config.font, tokenFont:config.font)
            } else {
              Text(title)
            }
            
          }.font(config.font)
            .buttonStyle(.plain)
            .lineLimit(isHappening || isSoon ? 2 : 1, reservesSpace: false)
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
        
        if ((isHappening || isSoon)
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
    
    HStack(alignment:.center, spacing: RowViewConfig.columnSpacing) {
      
      if (entry.startDate != nil) {
        TimeStringView(entry:entry, config:config)
          .foregroundColor(.primary)
          .widgetAccentable(true)
          .frame(minWidth:config.keyline, alignment: .trailing)
      } else {
        Text("").frame(minWidth:config.keyline, alignment: .trailing)
      }
      
      HStack() {
        Image(systemName: "circle")
          .imageScale(.small)
          .font(config.font)
          .foregroundColor(config.accentColor)
          .widgetAccentable()
      }
      .frame(minWidth:config.fontSize, maxHeight:.infinity, alignment: .center)
      
      
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
      
      
      if reminder.calendar != config.defaultRemindersList,
         let initial = reminder.calendar?.title.first {
        Image(systemName: "\(String(initial).lowercased()).circle")
          .imageScale(.small)
          .foregroundColor(config.accentColor)
          .widgetAccentable()
      }
      
      
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
    
    HStack(alignment: .center, spacing: RowViewConfig.columnSpacing) {
      
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
  
  var body: some View {
    let hoursAway = Double(entry.startDate?.timeIntervalSince(Date()) ?? 0.0) / 60.0 / 60.0
    let opacity = max(1.0, pow(1.0 - hoursAway / 4.0, 0.33))
    HStack(alignment: .center, spacing: RowViewConfig.columnSpacing) {
      
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
      let hasAllDayItems = entry.allDayItems?.count ?? 0 > 0
      
      if (true) {
        
        if let startDate = entry.startDate,
           let shortDayName = dayOfWeekFormat.string(for:startDate),
           let shortDayNumber = dayOfMonthFormat.string(for:startDate)
        {
          VStack() {
            HStack { Text(shortDayName)}
            .font(config.smallFont)
            .textCase(.uppercase)
            .lineLimit(1)
            .kerning(1)
            .monospaced()
            .widgetAccentable()
            .frame(minWidth:config.widthIsLimited ? config.keyline : 0, alignment:.trailing)
          }.frame(minWidth:config.keyline, alignment:.trailing)
          
          if (!config.widthIsLimited) {
            VStack() {
              Text(shortDayNumber)
                .foregroundColor(config.accentColor)
                .font(config.smallFont)
            }.frame(minWidth:config.fontSize, alignment:.center)
          }
        }
      }
      
      VStack(alignment:.leading) {
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
      
    }
    .padding(.top, config.heightIsLimited ? 0 : config.lineHeight / 2)
    .padding(.bottom, config.heightIsLimited ? 0 : config.lineHeight / 8)
    .frame(maxWidth:.infinity, minHeight: config.lineHeight, alignment: .leading)
  }
}
