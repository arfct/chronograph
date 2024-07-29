
import SwiftUI
import EventKit

private let emailSelector = "emailAddress"
extension EKParticipant {
  var email: String? {
    if responds(to: Selector(emailSelector)) {
      return value(forKey: emailSelector) as? String
    }
    
    let emailComponents = description.components(separatedBy: "email = ")
    if emailComponents.count > 1 {
      return emailComponents[1].components(separatedBy: ";")[0]
    }
    
    if let email = (url as NSURL).resourceSpecifier, !email.hasPrefix("/") {
      return email
    }
    
    return nil
  }
  
  
  var displayName: String {
    if let name = self.name, !name.isEmpty {
      let components = name.components(separatedBy: CharacterSet(charactersIn: " @"))
      if let firstComponent = components.first {
        return firstComponent
      }
      return name
    } else if let email = self.email, !email.isEmpty,
              let emailPrefix = email.split(separator: "@").first {
      return String(emailPrefix)
    } else {
      return "No Name"
    }
  }
}

struct FacePile: View {
  var event: EKEvent
  var body: some View {
    
    if let attendees = event.attendees, attendees.count > 2 {
      
      HStack(spacing:4) {
        Image(systemName: "person")
        Text(attendees.compactMap { $0.isCurrentUser ? nil :  $0.displayName }.joined(separator: ", "))
          .lineLimit(1)
        Text(attendees.count, format:.number)
      }
//      LazyVGrid(
//        columns: [GridItem(.adaptive(minimum: 1, maximum: 100))],
//        spacing: 1
//      ) {
//        ForEach(attendees, id: \.self) { attendee in
//          
//          if !attendee.isCurrentUser {
//            if let initial = attendee.displayName.first {
//              Image(systemName: "\(String(initial).lowercased()).circle.fill")
//                .imageScale(.small)
//                .widgetAccentable()
//                .layoutPriority(1)
//                .foregroundColor(ColorGenerator.color(from:attendee.displayName))
//            }
//            
//          }
//        }
//      }
    }
  }
}

#Preview {
  let event = EKEventStore().event(withIdentifier: "1234567890")!
  FacePile(event: event)
}
