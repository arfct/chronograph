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
      Button {
        let recorderPlayer = AudioRecorderPlayer()
        recorderPlayer.startRecordingAndPlaying()

      } label: {
        Label {
          Text("hi")
        } icon: {
          Image(systemName: "microphone")
        }

      }

      List {
        if let reminders = reminders {
          Section(header: Text("Reminders")) {
            ForEach(reminders.prefix(10)) { reminder in
              Text(reminder.item?.title ?? reminder.header ?? "Error")
            }
          }
        }
        
        Section(header: Text("Events")) {
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
      }
      .navigationTitle("Reminders & Events")
      .task {
        await requestAccess()
      }
    }
  }
}

#Preview {
  ContentView()
}
