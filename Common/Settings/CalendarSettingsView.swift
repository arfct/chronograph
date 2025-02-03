import SwiftUI
import EventKit

struct ViewOptionsView: View {
  static let defaultForegroundColor = Color.primary
  static let defaultBackgroundColor = Color.clear
  
  @AppStorage(Keys.foregroundColor, store: UserDefaults(suiteName: Keys.suiteName))
  private var foregroundColorHex = defaultForegroundColor.toHex() ?? "#000000"
  
  @AppStorage(Keys.backgroundColor, store: UserDefaults(suiteName: Keys.suiteName))
  private var backgroundColorHex = defaultBackgroundColor.toHex() ?? "#00000000"
  
  @AppStorage(Keys.fontSize, store: UserDefaults(suiteName: Keys.suiteName))
  private var fontSize: FontSize = .medium
  
  @AppStorage(Keys.fontStyle, store: UserDefaults(suiteName: Keys.suiteName))
  private var fontStyle: FontStyle = .normal
  
  @AppStorage(Keys.multicolor, store: UserDefaults(suiteName: Keys.suiteName))
  private var multicolor = false
  
  @AppStorage(Keys.padding, store: UserDefaults(suiteName: Keys.suiteName))
  private var padding: PaddingStyle = .automatic
  
  private var foregroundColor: Binding<Color> {
    Binding(
      get: { Color.withHex(foregroundColorHex) ?? Self.defaultForegroundColor },
      set: { foregroundColorHex = $0.toHex() ?? "#000000" }
    )
  }
  
  private var backgroundColor: Binding<Color> {
    Binding(
      get: { Color.withHex(backgroundColorHex) ?? Self.defaultBackgroundColor },
      set: { backgroundColorHex = $0.toHex() ?? "#00000000" }
    )
  }
  
  var body: some View {
    Form {
      Section {
#if !os(watchOS)
        ColorPicker("Text Color", selection: foregroundColor)
        ColorPicker("Background Color", selection: backgroundColor)
#endif
      
        Picker("Font Size", selection: $fontSize) {
          ForEach(FontSize.allCases, id: \.rawValue) { size in
            let _ = print("case \(size)")
//            Text(FontSize.caseDisplayRepresentations[size] ?? "").tag(size)
          }
        }
        
//
        Picker("Font Style", selection: $fontStyle) {
          ForEach(FontStyle.allCases, id: \.self) { style in
            let _ = print("case \(style)")
//            Text(style.displayName).tag(style)
          }
        }
//        
//        Toggle("Multicolor", isOn: $multicolor)
//        
//        Picker("Padding", selection: $padding) {
//          ForEach(PaddingStyle.allCases, id: \.self) { style in
//            Text(style.displayName).tag(style)
//          }
//        }
      } header: {
        Text("Theme")
      }
    }
  }
}



enum PaddingStyle: String, CaseIterable {
    case automatic, vertical, horizontal, none
    
    var displayName: String {
        rawValue.capitalized
    }
}

struct CalendarSettingsView: View {
  @AppStorage(Keys.tokenizeParens, store: UserDefaults(suiteName: Keys.suiteName))
  private var tokenize = false
  @AppStorage(Keys.compactTime, store: UserDefaults(suiteName: Keys.suiteName))
  private var compactTime = true
  @AppStorage(Keys.enabledCalendars, store: UserDefaults(suiteName: Keys.suiteName))
  private var selectedCalendarIds: [String] = []
  @State private var calendars: [EKCalendar] = []
  
  var body: some View {
    NavigationStack {
      Form {
        NavigationLink {
          ViewOptionsView()
        } label: {
          Text("View options")
        }
        Section("Display Options") {
          Toggle(isOn: $tokenize) {
            Text("Wrap Parenthesis")
          }
          Toggle(isOn: $compactTime) {
            Text("Compact Time")
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
