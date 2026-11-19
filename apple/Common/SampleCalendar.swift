// Common/ is a synchronized folder group, so this file joins every target
// including the watch, where EventKit's write API does not exist.
#if DEBUG && !os(watchOS)
import EventKit
import Foundation

/// Writes a day of sample events through EventKit so widget layout can actually
/// be looked at. The iOS counterpart of android/scripts/seed-calendar.sh, and the
/// same fixtures — a conferencing link, a physical location, a description
/// carrying Gmail's boilerplate, and a second day.
///
/// It exists because verifying widget layout needs rows, and there is no
/// supported way to put them in a simulator from outside: a `webcal:` URL gets
/// rewritten to https, the .ics import sheet is not reliably automatable, and
/// rows written straight into Calendar.sqlitedb are ignored because calaccessd
/// owns that store. Writing them through EventKit from inside the app is the one
/// route that works.
///
/// DEBUG only, and every event is tagged so re-seeding replaces rather than
/// accumulates.
enum SampleCalendar {

  /// Stamped into every seeded event's notes so `clear()` can find them again.
  /// Sits after Google Calendar's separator, which cleanEventNote cuts at, so
  /// the marker never reaches the widget and note rendering stays realistic.
  static let marker = "[chronograph-sample]"

  enum SeedError: LocalizedError {
    case accessDenied
    case noWritableCalendar

    var errorDescription: String? {
      switch self {
      case .accessDenied: "Calendar access was refused, so there is nowhere to write."
      case .noWritableCalendar: "No writable calendar — add a local account first."
      }
    }
  }

  /// Offsets from "now", not fixed clock times: the first two events have to land
  /// inside TimelineEngine's four-hour detail window whatever time this is run,
  /// since it is the detail rows that make a row taller than lineHeight and are
  /// the whole point of the exercise.
  private struct Sample {
    let title: String
    let start: TimeInterval
    let duration: TimeInterval
    var location: String?
    var notes: String?
  }

  private static let minute: TimeInterval = 60
  private static let hour: TimeInterval = 3600

  private static var samples: [Sample] {
    [
      // Inside the detail window: meeting link, and boilerplate that
      // cleanEventNote should strip back to the human sentence.
      Sample(title: "Standup", start: 20 * minute, duration: 15 * minute,
             location: "https://meet.google.com/abc-defg-hij",
             notes: """
             Blockers first, then the release.

             This event was created from an email you received in Gmail. \
             https://mail.google.com/mail?extsrc=cal&plid=ACUX6DOvxY
             """),
      Sample(title: "Design review — widgets", start: 90 * minute, duration: hour,
             notes: "Bring the Play screenshots."),
      Sample(title: "Lunch w/ Priya", start: 3 * hour, duration: hour,
             location: "Tartine, 600 Guerrero St"),
      // Beyond the window, so these stay single-line — the mix is what makes the
      // uniform-height estimate wrong.
      Sample(title: "Ship Play release", start: 5 * hour, duration: 45 * minute),
      Sample(title: "Retro", start: 6 * hour, duration: 30 * minute),
      Sample(title: "Gym", start: 8 * hour, duration: hour),
      // Tomorrow, so the stack carries a second day header.
      Sample(title: "Sprint kickoff", start: 22 * hour, duration: hour),
      Sample(title: "Museum with Ana", start: 27 * hour, duration: 2 * hour,
             location: "SFMOMA"),
    ]
  }

  /// Replaces any previously seeded events and returns how many were written.
  @discardableResult
  static func seed(using store: EKEventStore = EKEventStore()) async throws -> Int {
    guard try await store.requestFullAccessToEvents() else { throw SeedError.accessDenied }
    guard let calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event)
      .first(where: { $0.allowsContentModifications }) else {
      throw SeedError.noWritableCalendar
    }

    clear(in: store)

    let now = Date()
    for sample in samples {
      let event = EKEvent(eventStore: store)
      event.calendar = calendar
      event.title = sample.title
      event.startDate = now.addingTimeInterval(sample.start)
      event.endDate = now.addingTimeInterval(sample.start + sample.duration)
      event.location = sample.location
      event.notes = [sample.notes, CALENDAR_SEPARATOR, marker].compactMap { $0 }.joined(separator: "\n")
      try store.save(event, span: .thisEvent, commit: false)
    }
    try store.commit()
    return samples.count
  }

  /// Removes seeded events, identified by the marker in their notes.
  static func clear(in store: EKEventStore = EKEventStore()) {
    let calendars = store.calendars(for: .event).filter { $0.allowsContentModifications }
    guard !calendars.isEmpty else { return }
    let predicate = store.predicateForEvents(
      withStart: Date().addingTimeInterval(-14 * 24 * hour),
      end: Date().addingTimeInterval(14 * 24 * hour),
      calendars: calendars,
    )
    for event in store.events(matching: predicate)
    where event.notes?.contains(marker) == true {
      try? store.remove(event, span: .thisEvent, commit: false)
    }
    try? store.commit()
  }
}
#endif
