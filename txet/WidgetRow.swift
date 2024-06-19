//
//  WidgetRow.swift
//  txet
//
//  Created by Nicholas Jitkoff on 6/14/24.
//

import SwiftUI
import EventKit

struct EventEntryRow: View {
  let entry: EventEntry
  
  private var timeFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "H:mm"
    return formatter
  }
  
  private var relativeDateFormatter: RelativeDateTimeFormatter {
    let formatter = RelativeDateTimeFormatter()
    formatter.dateTimeStyle = .named
    formatter.unitsStyle = .full
    return formatter
  }
  
  var body: some View {
    let event = entry.item as! EKEvent
    
    
    let showDate = false
    VStack(alignment: .leading) {
      if showDate {
        Text(relativeDateFormatter.localizedString(for: event.startDate, relativeTo: Date()))
      }
      
      HStack {
        if !event.isAllDay {
          let timeString = timeFormatter.string(from: event.startDate)
          Text(convertToSuperscript(time: timeString))
            .foregroundColor(event.isAllDay ? .green : .primary)
        }
        Text(event.title)
          .foregroundColor(event.isAllDay ? .green : .primary)
      }
    }
    //      let color = Color(cgColor: event.calendar.cgColor ?? Color.green.cgColor!)
    //
    //      // MARK: Events
    //        HStack {
    //          if !event.isAllDay {
    //            let timeString = timeFormatter.string(from: event.startDate)
    //            Text(convertToSuperscript(time: timeString))
    //              .font(.system(size: fontSize))
    //              .widgetAccentable(true)
    //              .frame(minWidth:keyline)
    //          } else {
    //            if !small {
    //              Text("")
    //                .font(.system(size: fontSize))
    //                .frame(minWidth:keyline)
    //            }
    //          }
    //
    //          let eventid = "x-apple-calevent://\(row.id.replacingOccurrences(of: ":", with: "/"))"
    //          //                let _ = print("ID \(event)")
    //          Link(destination: item?.url ??
    //               URL(string:eventid)!) {
    //
    //            Text(event.title)
    //
    //            .font(.system(size: fontSize))
    //              .lineLimit(1)
    //              .foregroundColor(event.isAllDay ? color : .primary)
    //              .widgetAccentable(event.isAllDay)
    //            //                    .frame(maxWidth:.infinity)
    //
    //          }
    //          if (!event.isAllDay) {
    //            let duration = event.endDate.timeIntervalSince(event.startDate)
    //            let durationString = duration >= 3600
    //            ? String(format: "%.0fh", duration / 3600)
    //            : String(format: "%.0fm", duration / 60)
    //            Text(durationString)
    //              .foregroundColor(.secondary)
    //
    //          }
    //
    //        }.frame(maxWidth:.infinity, alignment: .leading)
    //        .frame(height: realLineHeight)
    //
  }
}

//#Preview {
//  EntryRow()
//}
