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
            if enabledReminders.contains(list.calendarIdentifier) {
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
    if enabledReminders.contains(calendar.calendarIdentifier) {
      enabledReminders.removeAll { $0 == calendar.calendarIdentifier }
    } else {
      enabledReminders.append(calendar.calendarIdentifier)
    }
  }
}

#Preview {
  RemindersSettingsView()
} 
