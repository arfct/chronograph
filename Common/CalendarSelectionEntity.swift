import WidgetKit
@preconcurrency import EventKit
import AppIntents

struct CalendarSelectionEntity: AppEntity {
  let id: String
  let title: String
  
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar"
  static var defaultQuery = CalendarQuery()
  
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(title)", image: .init(systemName: "calendar"))
  }
}


struct CalendarQuery: EntityQuery {
  let eventStore = EKEventStore()
  
  func entities(for identifiers: [CalendarSelectionEntity.ID]) async throws -> [CalendarSelectionEntity] {

    let entities = try? await suggestedEntities().filter { identifiers.contains($0.id)}
    return entities ?? []
  }
  
  func suggestedEntities() async throws -> [CalendarSelectionEntity] {
    let calendars = eventStore.calendars(for: .event)
    
    var entities: [CalendarSelectionEntity] = [
      CalendarSelectionEntity(id: "*", title: "All Calendars")
    ]
    
    // Step 4: Create an array of names and IDs
    var calendarInfoArray: [(name: String, id: String)] = []
    for calendar in calendars {
      entities.append(CalendarSelectionEntity(id:calendar.calendarIdentifier, title:calendar.title))
      let calendarInfo = (name: calendar.title, id: calendar.calendarIdentifier)
      calendarInfoArray.append(calendarInfo)
    }
    
    return entities
  }
  
  func defaultResult() async -> CalendarSelectionEntity? {
    return nil
  }
}



