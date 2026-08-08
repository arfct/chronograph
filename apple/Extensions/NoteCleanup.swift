import Foundation

/// Strips the boilerplate that calendar and conferencing systems append to
/// event descriptions, so a widget row shows what a human typed rather than
/// dial-in instructions.
///
/// Deliberately free of EventKit so it can be exercised from
/// scripts/check-note-cleanup.swift.

/// Google's "do not edit this section" divider; everything after it is machine
/// generated.
let CALENDAR_SEPARATOR = "-::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-"

/// The box-drawing rule Zoom puts above its dial-in block.
let ZOOM_SEPARATOR = "──────────"

/// Once one of these appears, the rest of the description is boilerplate, so
/// the note is truncated there. Matched case-insensitively.
let noteBlockMarkers = [
  // Gmail turns a message into an event and explains itself at length.
  "This event was created from an email you received in Gmail",
  "This event was created from an email",
  // Google Meet / Calendar
  "Join with Google Meet",
  "Join Google Meet",
  "Google Meet joining info",
  "Please do not edit this section",
  "-::~:~::~",              // a truncated CALENDAR_SEPARATOR
  // Zoom
  "Join Zoom Meeting",
  "is inviting you to a scheduled Zoom meeting",
  ZOOM_SEPARATOR,
  // Microsoft Teams
  "Microsoft Teams meeting",
  "Join on your computer",
  "________________________________________",
  // Webex / generic
  "----( Video Call )----",
  "Join by phone",
  "Join meeting now",
]

/// Lines that are pure conferencing chrome. Unlike the markers above these can
/// appear on their own without a following block, so the line is dropped and
/// the rest of the note kept. Matched case-insensitively at the line start.
let noteNoiseLinePrefixes = [
  "meeting id:", "meeting url:", "meeting link:",
  "passcode:", "password:", "pin:", "access code:",
  "one tap mobile", "dial by your location", "or dial:", "dial-in",
  "find your local number", "more phone numbers",
  "learn more about meet at", "learn more at",
  "phone conference id:", "video call:",
]

/// Hosts whose links are plumbing, never a document worth surfacing as an
/// attachment row.
let noteNoiseLinkHosts = [
  "mail.google.com",       // "view this email in Gmail"
  "meet.google.com",       // surfaced separately as the meeting link
  "zoom.us",
  "teams.microsoft.com",
  "tel.meet",
  "support.google.com",
  "aka.ms",
]

/// Truncates at the earliest boilerplate marker, keeping whole lines.
func removeMeetingMetadata(from text: String, containing markers: [String] = noteBlockMarkers) -> String {
  var earliest: String.Index? = nil
  for marker in markers {
    guard let range = text.range(of: marker, options: [.caseInsensitive]) else { continue }
    if earliest == nil || range.lowerBound < earliest! { earliest = range.lowerBound }
  }
  guard let index = earliest else { return text }

  let head = text[..<index]
  if let lineBreak = head.range(of: "\n", options: .backwards) {
    return String(head[..<lineBreak.lowerBound])
  }
  if let paragraph = head.range(of: "<p>", options: [.backwards, .caseInsensitive]) {
    return String(head[..<paragraph.lowerBound])
  }
  return String(head)
}

/// Drops lines that are nothing but conferencing chrome or a bare noise link.
func stripNoiseLines(from text: String) -> String {
  let kept = text.components(separatedBy: "\n").filter { line in
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let bare = strippedOfMarkup(trimmed).trimmingCharacters(in: .whitespaces)
    if bare.isEmpty { return true }  // blank lines collapse later

    let lowered = bare.lowercased()
    if noteNoiseLinePrefixes.contains(where: { lowered.hasPrefix($0) }) { return false }

    // A line that is only a link to a plumbing host carries no information.
    if !bare.contains(" "), noteNoiseLinkHosts.contains(where: { lowered.contains($0) }) {
      return false
    }
    return true
  }
  return collapseBlankLines(kept.joined(separator: "\n"))
}

/// The whole pipeline: cut the machine-generated tail, drop chrome lines, and
/// return "" when nothing human is left so callers can skip the row entirely.
func cleanEventNote(_ raw: String) -> String {
  let beforeSeparator = raw.components(separatedBy: CALENDAR_SEPARATOR).first ?? raw
  let withoutBlocks = removeMeetingMetadata(from: beforeSeparator)
  let withoutNoise = stripNoiseLines(from: withoutBlocks)
  let trimmed = withoutNoise.trimmingCharacters(in: .whitespacesAndNewlines)
  // Left with only punctuation or markup scaffolding? Treat it as empty.
  return strippedOfMarkup(trimmed).rangeOfCharacter(from: .alphanumerics) == nil ? "" : trimmed
}

private func strippedOfMarkup(_ text: String) -> String {
  text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    .replacingOccurrences(of: "&nbsp;", with: " ")
}

private func collapseBlankLines(_ text: String) -> String {
  text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
}
