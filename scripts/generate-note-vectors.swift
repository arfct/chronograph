// Regenerates fixtures/note-vectors.tsv from the Swift implementation, which is
// the source of truth. The Kotlin port is verified against these by
// NoteVectorsTest.
//
//   T=$(mktemp -d); cp apple/Extensions/NoteCleanup.swift "$T/"
//   cp scripts/generate-note-vectors.swift "$T/main.swift"
//   swiftc -O -o "$T/gen" "$T"/*.swift && "$T/gen" > fixtures/note-vectors.tsv
//
// Columns: raw description, cleaned note. Tabs and newlines in the raw input
// are escaped so each vector stays on one TSV line.
import Foundation

let inputs: [String] = [
  "This event was created from an email you received in Gmail. https://mail.google.com/mail?extsrc=cal&plid=ACUX6DOvxY-PUirhc7XpC93SzRrE77m0GoTtlY8",
  "Bring the signed lease.\n\nThis event was created from an email you received in Gmail. https://mail.google.com/mail?extsrc=cal&plid=ACUX6DO",
  "Weekly sync — bring metrics.\n\nJoin with Google Meet: https://meet.google.com/abc-defg-hij\nOr dial: (US) +1 555-000-1111 PIN: 123456789#\nMore phone numbers: https://tel.meet/abc-defg-hij?pin=123\nLearn more about Meet at: https://support.google.com/a/users/answer/9282720",
  "Design review\n\nPriya is inviting you to a scheduled Zoom meeting.\n\nJoin Zoom Meeting\nhttps://example.zoom.us/j/1234567890?pwd=abcdef\nMeeting ID: 123 456 7890\nPasscode: 998877",
  "Notes: read the RFC first.\n──────────\nZoom dial-in details follow",
  "Vendor call\n\n________________________________________\nMicrosoft Teams meeting\nJoin on your computer, mobile app or room device\nPhone conference ID: 123 456 78#",
  "Quarterly planning agenda in the doc.\n\(CALENDAR_SEPARATOR)\nPlease do not edit this section.\nJoin with Google Meet: https://meet.google.com/xyz",
  "Budget review\nMeeting ID: 999 111 2222\nPasscode: hunter2\nBring last quarter's numbers.",
  "Standup\nhttps://meet.google.com/abc-defg-hij",
  "Read the spec first.\nhttps://paper.dropbox.com/doc/Plan--abc",
  "Dentist — bring the insurance card.",
  "<p>Bring <b>two</b> copies.</p>",
  "<p></p><br>&nbsp;",
  "",
  "   \n  \n ",
  "One line only",
  "Trailing chrome\nvideo call: https://example.com/x",
  "----( Video Call )----\nnothing above this",
  "Offsite\n\nJoin meeting now\nhttps://teams.microsoft.com/l/meetup-join/xyz",
]

func esc(_ s: String) -> String {
  s.replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\t", with: "\\t")
    .replacingOccurrences(of: "\n", with: "\\n")
}

var out = "raw\tcleaned\n"
for input in inputs {
  out += "\(esc(input))\t\(esc(cleanEventNote(input)))\n"
}
FileHandle.standardOutput.write(Data(out.utf8))
