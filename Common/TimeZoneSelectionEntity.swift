import WidgetKit
@preconcurrency import EventKit
import AppIntents
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct TimeZoneSelectionEntity: AppEntity {
  let id: String
  let title: String
  let subtitle: String?
  let color: UIColor?
  
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Time Zone"
  static var defaultQuery = TimeZoneQuery()
  
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(title)",
                          subtitle: subtitle != nil ? "\(subtitle!)": nil//,
//                          image: .init(systemName: "circle.fill", tintColor: color, symbolConfiguration:.init(pointSize: 10, weight: .regular))
    )
    
  }
  
  static func with(timeZone: TimeZone?) -> TimeZoneSelectionEntity {
    guard let timeZone = timeZone else {
      return TimeZoneSelectionEntity(id: "", title: "", subtitle: nil, color: nil)
    }
    return TimeZoneSelectionEntity(id: timeZone.identifier,
                                   title: timeZone.identifier,
                                   subtitle: nil,
                                   color: nil)
  }
  
}

struct TimeZoneQuery: EntityQuery {
  
  func entities(for identifiers: [TimeZoneSelectionEntity.ID]) async throws -> [TimeZoneSelectionEntity] {
    return identifiers.map({ TimeZoneSelectionEntity.with(timeZone: TimeZone(identifier: $0)) })
  }
  
  func suggestedEntities() async throws -> IntentItemCollection<TimeZoneSelectionEntity> {
    var knownTimeZoneIdentifiers = TimeZone.knownTimeZoneIdentifiers
    
    var knownTimeZones = knownTimeZoneIdentifiers.compactMap({ TimeZone(identifier: $0) })
    knownTimeZones = knownTimeZones.sorted(by: { (timeZone1, timeZone2) -> Bool in
      return timeZone1.secondsFromGMT() < timeZone2.secondsFromGMT()
    })
    
    
    var sections: [IntentItemSection<TimeZoneSelectionEntity>] = []
    var countries: [String: [TimeZoneSelectionEntity]] = [:]
    
    for timeZone in knownTimeZones {
      let identifier = timeZone.identifier
      let abbreviation = timeZone.localizedName(for:.standard, locale: Locale.current) ?? ""
      let gmt = timeZone.localizedName(for:.shortStandard, locale: Locale.current) ?? ""
      
       
      
      let components = identifier.components(separatedBy: "/")
      if components.count == 2 {
        let country = components[0]
        if countries[country] == nil {
          countries[country] = []
        }
        
        let title = components[1].replacingOccurrences(of: "_", with: " ")
        
        let timeZoneEntity = TimeZoneSelectionEntity(id: identifier,
                                                     title: "\(title) (\(gmt))\n\(abbreviation)",
                                                     subtitle: nil,
                                                     color: nil)
        countries[country]?.append(timeZoneEntity)
      }
      
    }
    //    countries = countries.sorted(by: { (country1, country2) -> Bool in
    //      guard let timeZone1 = country1.value.first, let timeZone2 = country2.value.first else {
//        return false
//      }
//      return timeZone1.subtitle?.localizedStandardCompare(timeZone2.subtitle ?? "") == .orderedAscending
//    })
    for (country, timeZones) in countries {
      sections.append(IntentItemSection<TimeZoneSelectionEntity>("\(country)", items: timeZones))
    }
    
    return IntentItemCollection(promptLabel: nil, sections: sections)
  }
  
  func defaultResult() async -> TimeZoneSelectionEntity? {
    return nil
  }
}
