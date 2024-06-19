//
//  ContentView.swift
//  txet
//
//  Created by Nicholas Jitkoff on 1/4/24.
//

import SwiftUI
import EventKit

struct Reminder: Identifiable {
  var id: String
  var reminder: EKReminder
}

struct Event: Identifiable {
  var id: String
  var event: EKEvent
}
struct ContentView: View {
  
  let eventStore = EKEventStore()
  @State var reminders: [EventEntry]? = []
  @State var events: [EventEntry]? = []
  
  
  
  private func requestAccess() async {
    do {
      if try await eventStore.requestFullAccessToReminders() {
        reminders = await fetchReminders()
      }
    } catch {
      print("Access to reminders denied: \(String(describing: error.localizedDescription))")
    }
    
    do {
      if try await eventStore.requestFullAccessToEvents() {
        events = await fetchEvents(calendarIDs: [])
      }
    } catch {
      print("Access to events denied: \(String(describing: error.localizedDescription))")
    }
    
  }
  
  var body: some View {
    NavigationStack {
//      Button {
//        let recorderPlayer = AudioRecorderPlayer()
//        recorderPlayer.startRecordingAndPlaying()
//
//      } label: {
//        Label {
//          Text("hi")
//        } icon: {
//          Image(systemName: "microphone")
//        }
//
//      }

      VStack(alignment: .leading) {
        Text("txet").font(.largeTitle)
        Text("provides a pair of simple text-based widgets for reminders and calendars. Add widgets from the home screen.\n\nBelow are the items that will be shown (requires permission)")
      }.frame(alignment:.leading)
        .padding(30)
      List {
        if let reminders = reminders {
          VStack(alignment: .leading) {
            ForEach(reminders.prefix(10)) { reminder in
              Text(reminder.item?.title ?? reminder.header ?? "Error")
                .lineLimit(1)
            }
          }
          .listRowBackground(Color.clear)
        }
        
        VStack (alignment:.leading){
          if let events = events {
            ForEach(events.prefix(10)) { row in
              
              if row.item is EKEvent {
                EventEntryRow(entry: row)
              } else {
                Text(row.header ?? "–")
              }
            }
          }
        }
        .listRowBackground(Color.clear)
      }
      .task {
        await requestAccess()
      }
    }
  }
}

#Preview {
  ContentView()
}
