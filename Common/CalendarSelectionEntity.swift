import WidgetKit
@preconcurrency import EventKit
import AppIntents
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct CalendarSelectionEntity: AppEntity {
  let id: String
  let title: String
  let subtitle: String?
  let color: UIColor?
  
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar"
  static var defaultQuery = CalendarQuery()
  
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(title)",
                          subtitle: subtitle != nil ? "\(subtitle!)": nil,
                          image: .init(systemName: "circle.fill",  tintColor: color, symbolConfiguration:.init(pointSize: 10, weight: .regular)))
    
  }
}


struct CalendarQuery: EntityQuery {
  let eventStore = EKEventStore()
  
  func entities(for identifiers: [CalendarSelectionEntity.ID]) async throws -> [CalendarSelectionEntity] {

    let entities = try? await suggestedEntities().filter { identifiers.contains($0.id)}
    return entities ?? []
  }
  
  func suggestedEntities() async throws -> [CalendarSelectionEntity] {
    let calendars = eventStore.calendars(for: .event).sorted(by: { $0.source.title < $1.source.title })
    
    var entities: [CalendarSelectionEntity] = [
      CalendarSelectionEntity(id: "*", title: "All Calendars", subtitle:nil,  color:UIColor.blue)
    ]
    
    // Step 4: Create an array of names and IDs
//    var calendarInfoArray: [(name: String, id: String)] = []
    for calendar in calendars {
      
      entities.append(CalendarSelectionEntity(id:calendar.calendarIdentifier,
                                              title:calendar.title,
                                              subtitle:calendar.source.title,
                                              color:UIColor(cgColor:calendar.cgColor)))
//      let calendarInfo = (name: calendar.title, id: calendar.calendarIdentifier)
//      calendarInfoArray.append(calendarInfo)
    }
    
    return entities
  }
  
  func defaultResult() async -> CalendarSelectionEntity? {
    return nil
  }
}



