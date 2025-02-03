import SwiftUI
import EventKit

struct RemindersSettingsView: View {
    @AppStorage(Keys.tokenizeParens, store: UserDefaults(suiteName: Keys.suiteName)) private var tokenize = false
    @AppStorage(Keys.compactTime, store: UserDefaults(suiteName: Keys.suiteName)) private var compactTime = true
    
    var body: some View {
        Form {
            Section(header: Text("Display Options")) {
                Toggle("Compact Time", isOn: $compactTime)
                Toggle("Tokenize Parentheses", isOn: $tokenize)
            }
            
            Section(header: Text("Lists")) {
                let eventStore = EKEventStore()
                let lists = eventStore.calendars(for: .reminder)
//                ForEach(lists, id: \.calendarIdentifier) { list in
//                    HStack {
//                        Circle()
//                            .fill(Color(cgColor: list.color))
//                            .frame(width: 12, height: 12)
//                        Text(list.title)
//                    }
//                }
            }
        }
    }
}

#Preview {
    RemindersSettingsView()
} 
