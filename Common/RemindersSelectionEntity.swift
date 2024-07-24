import WidgetKit
@preconcurrency import EventKit
import AppIntents

struct ReminderSelectionEntity: AppEntity {
  let id: String
  let title: String
  
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Reminder"
  static var defaultQuery = ReminderQuery()
  
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(title)", image: .init(systemName: "checklist.unchecked"))
  }
}


struct ReminderQuery: EntityQuery {
  let eventStore = EKEventStore()
  
  func entities(for identifiers: [ReminderSelectionEntity.ID]) async throws -> [ReminderSelectionEntity] {

    let entities = try? await suggestedEntities().filter { identifiers.contains($0.id)}
    return entities ?? []
  }
  
  func suggestedEntities() async throws -> [ReminderSelectionEntity] {
    let reminders = eventStore.calendars(for: .reminder)
    
    var entities: [ReminderSelectionEntity] = [
      ReminderSelectionEntity(id: "*", title: "All Reminders")
    ]
    
    // Step 4: Create an array of names and IDs
    var reminderInfoArray: [(name: String, id: String)] = []
    for reminder in reminders {
      entities.append(ReminderSelectionEntity(id:reminder.calendarIdentifier, title:reminder.title))
      let reminderInfo = (name: reminder.title, id: reminder.calendarIdentifier)
      reminderInfoArray.append(reminderInfo)
    }
    
    return entities
  }
  
  func defaultResult() async -> ReminderSelectionEntity? {
    return nil
  }
}



