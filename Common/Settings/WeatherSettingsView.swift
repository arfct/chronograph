import SwiftUI
import WeatherKit

struct WeatherSettingsView: View {
    @AppStorage(Keys.tokenizeParens, store: UserDefaults(suiteName: Keys.suiteName)) private var tokenize = false
    @AppStorage(Keys.compactTime, store: UserDefaults(suiteName: Keys.suiteName)) private var compactTime = true
    
    var body: some View {
        Form {
            Section(header: Text("Display Options")) {
                Toggle("Compact Time", isOn: $compactTime)
                Toggle("Tokenize Parentheses", isOn: $tokenize)
            }
            
            Section(header: Text("Weather Style")) {
                NavigationLink {
                    List {
                        Text("Current")
                        Text("Hourly")
                        Text("Daily")
                    }
                } label: {
                    Text("View Style")
                }
                
                NavigationLink {
                    LocationSelectionView()
                } label: {
                    Text("Location")
                }
            }
        }
    }
}

struct LocationSelectionView: View {
    @State private var searchText = ""
    
    var body: some View {
        List {
            Text("Current Location")
            Text("Search Locations...")
        }
        .searchable(text: $searchText)
        .navigationTitle("Location")
    }
}

#Preview {
    WeatherSettingsView()
} 