// Exercises apple/Extensions/NoteCleanup.swift against real-world event
// descriptions. NoteCleanup is deliberately EventKit-free so this compiles
// standalone:
//
//   T=$(mktemp -d); cp apple/Extensions/NoteCleanup.swift "$T/"
//   cp scripts/check-note-cleanup.swift "$T/main.swift"
//   swiftc -O -o "$T/notecheck" "$T"/*.swift && "$T/notecheck"
//
// (top-level code must live in main.swift, hence the copy)
//
// Exits non-zero if any case fails, so it works as a check as well as a demo.
import Foundation

struct Case {
  let name: String
  let raw: String
  /// Exact expected output after cleaning.
  let expected: String
}

let cases: [Case] = [
  Case(
    name: "Gmail-created event, boilerplate only",
    raw: "This event was created from an email you received in Gmail. https://mail.google.com/mail?extsrc=cal&plid=ACUX6DOvxY-PUirhc7XpC93SzRrE77m0GoTtlY8",
    expected: ""
  ),
  Case(
    name: "Gmail boilerplate after a real note",
    raw: """
    Bring the signed lease.

    This event was created from an email you received in Gmail. https://mail.google.com/mail?extsrc=cal&plid=ACUX6DO
    """,
    expected: "Bring the signed lease."
  ),
  Case(
    name: "Google Meet block",
    raw: """
    Weekly sync — bring metrics.

    Join with Google Meet: https://meet.google.com/abc-defg-hij
    Or dial: (US) +1 555-000-1111 PIN: 123456789#
    More phone numbers: https://tel.meet/abc-defg-hij?pin=123
    Learn more about Meet at: https://support.google.com/a/users/answer/9282720
    """,
    expected: "Weekly sync — bring metrics."
  ),
  Case(
    name: "Zoom invite block",
    raw: """
    Design review

    Priya is inviting you to a scheduled Zoom meeting.

    Join Zoom Meeting
    https://example.zoom.us/j/1234567890?pwd=abcdef
    Meeting ID: 123 456 7890
    Passcode: 998877
    """,
    expected: "Design review"
  ),
  Case(
    name: "Zoom separator block",
    raw: """
    Notes: read the RFC first.
    ──────────
    Zoom dial-in details follow
    """,
    expected: "Notes: read the RFC first."
  ),
  Case(
    name: "Microsoft Teams block",
    raw: """
    Vendor call

    ________________________________________
    Microsoft Teams meeting
    Join on your computer, mobile app or room device
    Phone conference ID: 123 456 78#
    """,
    expected: "Vendor call"
  ),
  Case(
    name: "Google calendar separator tail",
    raw: """
    Quarterly planning agenda in the doc.
    \(CALENDAR_SEPARATOR)
    Please do not edit this section.
    Join with Google Meet: https://meet.google.com/xyz
    """,
    expected: "Quarterly planning agenda in the doc."
  ),
  Case(
    name: "stray chrome lines with no block marker",
    raw: """
    Budget review
    Meeting ID: 999 111 2222
    Passcode: hunter2
    Bring last quarter's numbers.
    """,
    expected: "Budget review\nBring last quarter's numbers."
  ),
  Case(
    name: "bare plumbing link on its own line is dropped",
    raw: """
    Standup
    https://meet.google.com/abc-defg-hij
    """,
    expected: "Standup"
  ),
  Case(
    name: "a real document link survives",
    raw: """
    Read the spec first.
    https://paper.dropbox.com/doc/Plan--abc
    """,
    expected: "Read the spec first.\nhttps://paper.dropbox.com/doc/Plan--abc"
  ),
  Case(
    name: "ordinary note is untouched",
    raw: "Dentist — bring the insurance card.",
    expected: "Dentist — bring the insurance card."
  ),
  Case(
    name: "HTML note keeps its markup",
    raw: "<p>Bring <b>two</b> copies.</p>",
    expected: "<p>Bring <b>two</b> copies.</p>"
  ),
  Case(
    name: "markup-only description counts as empty",
    raw: "<p></p><br>&nbsp;",
    expected: ""
  ),
]

var failures = 0
for c in cases {
  let got = cleanEventNote(c.raw)
  let ok = got == c.expected
  if !ok { failures += 1 }
  print("\(ok ? "PASS" : "FAIL")  \(c.name)")
  if !ok {
    print("      expected: \(c.expected.debugDescription)")
    print("      got:      \(got.debugDescription)")
  }
}
print("\n\(cases.count - failures)/\(cases.count) passed")
exit(failures == 0 ? 0 : 1)
