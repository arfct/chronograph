import SwiftUI
import EventKit

struct CalendarSettingsView: View {
  @AppStorage(Keys.tokenizeParens, store: UserDefaults(suiteName: Keys.suiteName))
  private var tokenize = false
  @AppStorage(Keys.compactTime, store: UserDefaults(suiteName: Keys.suiteName))
  private var compactTime = true
  @AppStorage(Keys.brailleMode, store: UserDefaults(suiteName: Keys.suiteName))
  private var legacyBrailleMode = false
  @AppStorage(Keys.obfuscation, store: UserDefaults(suiteName: Keys.suiteName))
  private var obfuscationRaw = ""

  private var obfuscation: Binding<ObfuscationStyle> {
    Binding(
      get: { ObfuscationStyle.resolve(rawValue: obfuscationRaw, legacyBrailleMode: legacyBrailleMode) },
      set: { obfuscationRaw = $0.rawValue }
    )
  }
  @AppStorage(Keys.enabledCalendars, store: UserDefaults(suiteName: Keys.suiteName))
  private var selectedCalendarIds: [String] = []
  @State private var calendars: [EKCalendar] = []

  var body: some View {
    NavigationStack {
      Form {
        Section("Display Options") {
          Toggle(isOn: $tokenize) {
            Text("Wrap Parentheses")
          }
          Toggle(isOn: $compactTime) {
            Text("Compact Time")
          }
          Picker("Obfuscation", selection: obfuscation) {
            ForEach(ObfuscationStyle.allCases) { style in
              Text(style.displayName).tag(style)
            }
          }
        }

        // Group calendars by source (account)
        ForEach(Array(Dictionary(grouping: calendars, by: { $0.source.title })
          .sorted(by: { $0.key < $1.key })), id: \.key) { source, sourceCalendars in
            Section(header: Text(source)) {
              ForEach(sourceCalendars.sorted(by: { $0.title < $1.title }),
                      id: \.calendarIdentifier) { calendar in
                HStack {
                  Circle()
                    .fill(Color(calendar.cgColor))
                    .frame(width: 12, height: 12)
                  Text(calendar.title)
                  Spacer()
                  if selectedCalendarIds.contains(calendar.calendarIdentifier) {
                    Image(systemName: "checkmark")
                      .foregroundColor(.accentColor)
                  }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                  toggleCalendar(calendar)
                }
              }
            }
          }

      }
    }
    .onAppear {
      loadCalendars()
    }
  }

  private func toggleCalendar(_ calendar: EKCalendar) {
    if selectedCalendarIds.contains(calendar.calendarIdentifier) {
      selectedCalendarIds.removeAll { $0 == calendar.calendarIdentifier }
    } else {
      selectedCalendarIds.append(calendar.calendarIdentifier)
    }
  }

  private func loadCalendars() {
    let eventStore = EKEventStore()
    Task {
      calendars = eventStore.calendars(for: .event)
    }
  }
}

#Preview {
  CalendarSettingsView()
}
