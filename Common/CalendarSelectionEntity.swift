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
  
  static func with(calendar: EKCalendar?) -> CalendarSelectionEntity {
    guard let calendar = calendar else {
      return CalendarSelectionEntity(id: "", title: "", subtitle: nil, color: nil)
    }
    return CalendarSelectionEntity(id:calendar.calendarIdentifier,
                                   title:calendar.title,
                                   subtitle:calendar.source.title,
                                   color:UIColor(cgColor:calendar.cgColor))
  }
  
}

//struct CreateBook: AppIntent {
//    @Parameter(title: "Author Name",
//               optionsProvider: AuthorNamesOptionsProvider())
//    var authorName: String
//
//
//    // Other properties and the perform() implementation.
//
//
//    private struct AuthorNamesOptionsProvider: DynamicOptionsProvider {
//        func results() async throws -> [String] {
//            ["Juan Chavez", "Anne Johnson"]
//        }
//    }
//}

struct CalendarQuery: EntityQuery {
  let eventStore = EKEventStore()
  
  func entities(for identifiers: [CalendarSelectionEntity.ID]) async throws -> [CalendarSelectionEntity] {
    return identifiers.map({ CalendarSelectionEntity.with(calendar:eventStore.calendar(withIdentifier:$0))})
  }
  
  func suggestedEntities() async throws -> IntentItemCollection<CalendarSelectionEntity> {
      let calendars = eventStore.calendars(for: .event).sorted(by: { $0.source.title < $1.source.title })
      
      var sections: [IntentItemSection<CalendarSelectionEntity>] = []
      sections.append(IntentItemSection<CalendarSelectionEntity>(
        "",
        items: [IntentItem(CalendarSelectionEntity(id: "*", title: "All Calendars", subtitle:nil,  color:UIColor.blue))]
      ))
      
      var sectionsBySource = Dictionary<EKSource, IntentItemSection<CalendarSelectionEntity>>()
      
      for calendar in calendars {
        if sectionsBySource[calendar.source] == nil {
          sectionsBySource[calendar.source] = IntentItemSection<CalendarSelectionEntity>(
            "\(calendar.source.title)", items: Array<CalendarSelectionEntity>()

          )
        }
        
        let entry = IntentItem(CalendarSelectionEntity(id: calendar.calendarIdentifier,
                                            title: calendar.title,
                                            subtitle: calendar.source.title,
                                            color: UIColor(cgColor: calendar.cgColor)))
        sectionsBySource[calendar.source]?.items.append(entry)
      }
      
      sections.append(contentsOf: sectionsBySource.values)
      
      return IntentItemCollection(promptLabel: nil, sections: sections)
  }
  
  func defaultResult() async -> CalendarSelectionEntity? {
    return nil
  }
}




