// Regenerates fixtures/obfuscation-vectors.tsv from the Swift implementation,
// which is the source of truth for both platforms. The Kotlin port is verified
// against these vectors by ObfuscationVectorsTest.
//
//   swift scripts/generate-obfuscation-vectors.swift > fixtures/obfuscation-vectors.tsv
//
// Inputs live below so the vector set is reviewable in one place. Add a case
// here, regenerate, then make the Kotlin port agree — never hand-edit the TSV.
import Foundation

let inputs = [
  // — existing coverage: dictionary hits, fallback rules, punctuation,
  //   non-Latin scripts, single characters, weather and timezone strings —
  "Team Standup",
  "Lunch with Sarah",
  "Design Review!",
  "Colonel Wednesday",
  "Flight to Chicago (AA 1231)",
  "don't forget",
  "Back-to-back meetings",
  "1:1 w/ Alex",
  "Zyzzyva Xyloq",
  "PHONE SCREEN",
  "quarterly business review",
  "Dr. Smith — checkup",
  "café rendezvous",
  "The quick brown fox jumps over the lazy dog",
  "a",
  "I",
  "OOO",
  "WWDC keynote watch party",
  "Pick up dry cleaning @ 5",
  "école visit",
  "New York City",
  "Los Angeles",
  "London",
  "Tokyo",
  "Sunset",
  "Sunrise",
  "Mostly Clear",
  "Partly Cloudy",
  "Rain",
  "High",
  "Low",
  "Night",
  "Free time - Honor thy error as a hidden intention",

  // — acronyms: preserved at 2–5 letters, optional plural —
  "PTO all day",
  "Sync with PM and ENG",
  "Review the PRD",
  "OKRs due EOD",
  "Fly to NYC and SFO",
  "AA 1231 to ORD",
  "TEAM OFFSITE",
  "IT is fine",
  "iOS and macOS builds",
  "API v2 review (SDK)",

  // — URLs: schemes, www, and bare hosts —
  "Join https://meet.google.com/abc-defg",
  "Call zoom.us/j/1234567890",
  "See www.example.com for notes",
  "Docs at paper.dropbox.com/doc/Plan",
  "Ping bit.ly/x3k9 first",
  "Q3 vs. Q4 comparison",
  "e.g. bring snacks",
]

var out = "input\tbraille\tenigma\n"
for input in inputs {
  out += "\(input)\t\(convertToBraille(input))\t\(convertToEnigma(input))\n"
}
FileHandle.standardOutput.write(Data(out.utf8))
