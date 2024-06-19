//
//  calendarEntity.swift
//  txet
//
//  Created by Nicholas Jitkoff on 6/13/24.
//

import WidgetKit
@preconcurrency import EventKit
import AppIntents

struct CalendarEntity: AppEntity {
  let id: String
  let title: String
  
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Character"
  static var defaultQuery = CalendarQuery()
  
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(title)")
  }
}


struct CalendarQuery: EntityQuery {
  let eventStore = EKEventStore()
  
  func entities(for identifiers: [CalendarEntity.ID]) async throws -> [CalendarEntity] {

    let entities = try? await suggestedEntities().filter { identifiers.contains($0.id)}
    return entities ?? []
  }
  
  func suggestedEntities() async throws -> [CalendarEntity] {
    let calendars = eventStore.calendars(for: .event)
    
    var entities: [CalendarEntity] = [
      CalendarEntity(id: "*", title: "All Calendars")
    ]
    
    // Step 4: Create an array of names and IDs
    var calendarInfoArray: [(name: String, id: String)] = []
    for calendar in calendars {
      entities.append(CalendarEntity(id:calendar.calendarIdentifier, title:calendar.title))
      let calendarInfo = (name: calendar.title, id: calendar.calendarIdentifier)
      calendarInfoArray.append(calendarInfo)
    }
    
    return entities
  }
  
  func defaultResult() async -> CalendarEntity? {
    return CalendarEntity(id: "*", title: "All Calendars")
  }
}
