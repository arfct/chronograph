import SwiftUI
import EventKit

struct RemindersSettingsView: View {
  @AppStorage(Keys.tokenizeParens, store: UserDefaults(suiteName: Keys.suiteName)) private var tokenize = false
  @AppStorage(Keys.compactTime, store: UserDefaults(suiteName: Keys.suiteName)) private var compactTime = true
  @State private var lists: [EKCalendar] = []
  
  @AppStorage(Keys.enabledReminders, store: UserDefaults(suiteName: Keys.suiteName))
  private var enabledReminders: [String] = []

  var body: some View {
    Form {
      Section(header: Text("Display Options")) {
        Toggle("Compact Time", isOn: $compactTime)
        Toggle("Wrap Parentheses", isOn: $tokenize)
      }
      
      Section(header: Text("Lists")) {
        ForEach(lists, id: \.calendarIdentifier) { list in
          
          HStack {
            Circle()
              .fill(Color(cgColor: list.cgColor))
              .frame(width: 12, height: 12)
            Text(list.title)
            Spacer()
            if enabledReminders.isEmpty || enabledReminders.contains(list.calendarIdentifier) {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
          .contentShape(Rectangle())
          .onTapGesture {
            toggleReminder(list)
          }
        }
      }
    }
    .onAppear {
      let eventStore = EKEventStore()
      self.lists = eventStore.calendars(for: .reminder).sorted(by: { $0.title < $1.title })
    }
  }
  
  private func toggleReminder(_ calendar: EKCalendar) {
    enabledReminders = toggledSelection(enabledReminders,
                                        id: calendar.calendarIdentifier,
                                        allIds: lists.map(\.calendarIdentifier))
  }
}

/// Toggles `id` in a selection where empty means "all". Tapping a row while
/// everything is implicitly selected deselects only that row, a selection that
/// grows back to everything collapses to empty again, and the last selected
/// row stays selected because empty would mean "all" rather than "none".
func toggledSelection(_ selection: [String], id: String, allIds: [String]) -> [String] {
  var selected = selection.isEmpty ? allIds : selection
  if selected.contains(id) {
    selected.removeAll { $0 == id }
    if selected.isEmpty { return selection }
  } else {
    selected.append(id)
  }
  return Set(selected) == Set(allIds) ? [] : selected
}

#Preview {
  RemindersSettingsView()
} 
