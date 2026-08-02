import SwiftUI
import EventKit



extension Array: @retroactive RawRepresentable where Element: Codable {
  public init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
          let result = try? JSONDecoder().decode([Element].self, from: data)
    else {
      return nil
    }
    self = result
  }
  
  public var rawValue: String {
    guard let data = try? JSONEncoder().encode(self),
          let result = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }
    return result
  }
}

struct TimezonesSettingsView: View {
  @State private var searchText = ""
  
  
  @AppStorage(Keys.favoriteTimezones, store: UserDefaults(suiteName: Keys.suiteName))
  private var favoriteTimezones: [String] = []
  
  var groupedTimezones: [String: [TimeZone]] {
    let allTimeZones = TimeZone.knownTimeZoneIdentifiers.map { TimeZone(identifier: $0)! }
    let filtered = searchText.isEmpty ? allTimeZones : allTimeZones.filter { 
      $0.identifier.localizedCaseInsensitiveContains(searchText) 
    }
    
    return Dictionary(grouping: filtered) { timezone in
      timezone.identifier.components(separatedBy: "/").first ?? "Other"
    }
  }
  
  private func simplifiedTimezoneName(_ identifier: String) -> String {
    identifier.components(separatedBy: "/")
             .dropFirst()
             .joined(separator: "/")
             .replacingOccurrences(of: "_", with: " ")
  }
  
  private func formatTime(for timezone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = timezone
    formatter.timeStyle = .short
    return formatter.string(from: Date())
  }
  
  var body: some View {
    NavigationStack {
      Form {
        // Favorites section
        Section(header: Text("Favorites")) {
          if favoriteTimezones.isEmpty {
            Text("No favorites added")
              .foregroundColor(.secondary)
          } else {
            ForEach(favoriteTimezones, id: \.self) { identifier in
              if let timezone = TimeZone(identifier: identifier) {
                HStack {
                  Image(systemName: "line.3.horizontal")
                    .foregroundColor(.gray)
                  VStack(alignment: .leading) {
                    Text(simplifiedTimezoneName(timezone.identifier))
                    Text(formatTime(for: timezone))
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                  Spacer()
                  Button(action: {
                    favoriteTimezones.removeAll(where: { $0 == identifier })
                  }) {
                    Image(systemName: "star.fill")
                      .foregroundColor(.yellow)
                  }
                }
              }
            }
            .onMove { from, to in
              favoriteTimezones.move(fromOffsets: from, toOffset: to)
            }
          }
        }
        
        // Replace single section with multiple sections by region
        ForEach(groupedTimezones.keys.sorted(), id: \.self) { region in
          Section(header: Text(region)) {
            ForEach(groupedTimezones[region] ?? [], id: \.identifier) { timezone in
              HStack {
                Text(simplifiedTimezoneName(timezone.identifier))
                Spacer()
                Button(action: {
                  if favoriteTimezones.contains(timezone.identifier) {
                    favoriteTimezones.removeAll(where: { $0 == timezone.identifier })
                  } else {
                    favoriteTimezones.append(timezone.identifier)
                  }
                }) {
                  Image(systemName: favoriteTimezones.contains(timezone.identifier) ? "star.fill" : "star")
                    .foregroundColor(favoriteTimezones.contains(timezone.identifier) ? .yellow : .gray)
                }
              }
            }
          }
        }
      }
      .searchable(text: $searchText)
    }
  }
}

#Preview {
  TimezonesSettingsView()
} 
