import EventKit

import Swift
#if os(macOS)
  import Cocoa
typealias UIColor = NSColor
typealias UIFont = NSFont

extension NSFont {
  var lineHeight: CGFloat {
    return NSLayoutManager().defaultLineHeight(for: self)
  }
}
#endif

func attributedString(from html: String) -> AttributedString? {
  guard let data = html.data(using: .utf8) else { return nil }
  do {
    let attributedString = try NSMutableAttributedString(data: data,
                                                    options: [.documentType: NSAttributedString.DocumentType.html,
                                                              .characterEncoding: String.Encoding.utf8.rawValue],
                                                    documentAttributes: nil)
    let range = NSRange(location: 0, length: attributedString.length)
    attributedString.addAttribute(.font, value: 9.0, range: range )
    
//    attributedString.addAttribute(.foregroundColor, value: UIColor(.black), range: range )
    
    return AttributedString(attributedString.trimWhiteSpace())
  } catch {
    print("Error creating attributed string from HTML: \(error)")
    return nil
  }
}

func extractMeetingUrls(from text: String) -> [EventAttachment] {
  let zoomRegexPattern = #"https://(?:\w+\.)?zoom\.us/j/\d+\?pwd=\w+"#
  let googleMeetRegexPattern = #"https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}"#
  let facetimeRegexPattern = #"https://facetime.apple.com/join#[^\s\">]+"#
  var meetings: [EventAttachment] = []

  let regexPatterns = [zoomRegexPattern, googleMeetRegexPattern, facetimeRegexPattern]

  for pattern in regexPatterns {
    do {
      let regex = try NSRegularExpression(pattern: pattern, options: [])
      let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

      for match in matches {
        if let range = Range(match.range, in: text) {
          let urlString = String(text[range])
          if let url = URL(string: urlString) {
            meetings.append(EventAttachment(url: urlString))
          }
        }
      }
    } catch {
      print("Invalid regex pattern: \(pattern)")
    }
  }

  return meetings
}

func splitAndTrim(_ input: String, delimiter: Character = ",") -> [String] {
  return input.split(separator: delimiter)
               .map { $0.trimmingCharacters(in: .whitespaces) }
}

extension NSAttributedString {

    /** Will Trim space and new line from start and end of the text */
    public func trimWhiteSpace() -> NSAttributedString {
        let invertedSet = CharacterSet.whitespacesAndNewlines.inverted
        let startRange = string.utf16.description.rangeOfCharacter(from: invertedSet)
        let endRange = string.utf16.description.rangeOfCharacter(from: invertedSet, options: .backwards)
        guard let startLocation = startRange?.upperBound, let endLocation = endRange?.lowerBound else {
            return NSAttributedString(string: string)
        }

        let location = string.utf16.distance(from: string.startIndex, to: startLocation) - 1
        let length = string.utf16.distance(from: startLocation, to: endLocation) + 2
        let range = NSRange(location: location, length: length)
        return attributedSubstring(from: range)
    }
}

// https://chatgpt.com/share/7196f0e7-2815-422a-a790-8d21bd34de9d


func stripHTMLTags(from string: String) -> String {
  guard let data = string.data(using: .utf8) else { return string }
  let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
    .documentType: NSAttributedString.DocumentType.html,
    .characterEncoding: String.Encoding.utf8.rawValue
  ]
  let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
  return attributedString?.string ?? string
}

func cleanPrefix(_ prefix: String) -> String {
  let strippedPrefix = stripHTMLTags(from: prefix)
  return strippedPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "-•").union(.whitespacesAndNewlines))
}


func extractAttachments(from html: String) -> ([EventAttachment], String) {
  do {
    
    // TODO: Consider <p> when doing this
    let anchorRegex = try NSRegularExpression(
      pattern: "(.*?)(<a\\s+href=\"(https?://[^\"]+)\"[^>]*>([^<]+)</a>)",
      options: .caseInsensitive
    )
    let urlRegex = try NSRegularExpression(
      pattern: "([^>]*?)(https?://[^\\s\"<]+)",
      options: .caseInsensitive
    )

    var urls: [String] = []
    var results: [EventAttachment] = []
    var rangesToRemove: [NSRange] = []

    // Extract URLs from anchor tags
    let anchorMatches = anchorRegex.matches(
      in: html,
      options: [],
      range: NSRange(location: 0, length: html.utf16.count)
    )

    for match in anchorMatches {
      guard let prefixRange = Range(match.range(at: 1), in: html),
            let urlRange = Range(match.range(at: 3), in: html),
            let titleRange = Range(match.range(at: 4), in: html) else { continue }
      let prefix = cleanPrefix(String(html[prefixRange]))
      let url = String(html[urlRange])
      let title = String(html[titleRange])
      if urls.contains(url) {
        continue
      }
      urls.append(url)
      results.append(EventAttachment(url: url, title: title, prefix: prefix))
      rangesToRemove.append(match.range)
    }

    // Extract standalone URLs
    let urlMatches = urlRegex.matches(
      in: html,
      options: [],
      range: NSRange(location: 0, length: html.utf16.count)
    )

    for match in urlMatches {
      guard let prefixRange = Range(match.range(at: 1), in: html),
            let urlRange = Range(match.range(at: 2), in: html) else { continue }
      let prefix = cleanPrefix(String(html[prefixRange]))
      let url = String(html[urlRange])
      if !urls.contains(url) {
        urls.append(url)
        results.append(EventAttachment(url: url, title: nil, prefix: prefix))
        rangesToRemove.append(match.range)
      }
    }

    // Remove matched ranges from the original string
    let sortedRanges = rangesToRemove.sorted { $0.location > $1.location }
    var cleanedHTML = html
    for range in sortedRanges {
      if let range = Range(range, in: cleanedHTML) {
        cleanedHTML.removeSubrange(range)
      }
    }

    return (results, cleanedHTML)
  } catch {
    print("Invalid regex: \(error.localizedDescription)")
    return ([], html)
  }
}

// https://chatgpt.com/share/d38ac2e5-f999-4b9d-9c38-dee4ed98cffb

let COMMON_MEETING_SUFFIXES = [
  "Join Zoom Meeting",
  "Join with Google Meet",
  "----( Video Call )----",
  ZOOM_SEPARATOR
]

func removeMeetingMetadata(from text: String, containing suffixes: [String] = COMMON_MEETING_SUFFIXES) -> String {
  var earliestIndex: String.Index? = nil

  for suffix in suffixes {
    if let range = text.range(of: suffix), earliestIndex == nil || range.lowerBound < earliestIndex! {
      earliestIndex = range.lowerBound
    }
  }

  guard let index = earliestIndex else { return text }

  let substringBeforeIndex = text[..<index]
  if let lineBreakRange = substringBeforeIndex.range(of: "\n", options: .backwards) {
    return String(substringBeforeIndex[..<lineBreakRange.lowerBound])
  } else if let paragraphRange = substringBeforeIndex.range(of: "<p>", options: .backwards) {
    return String(substringBeforeIndex[..<paragraphRange.lowerBound])
  } else {
    return String(substringBeforeIndex)
  }
}



func extractTitleFromURL(from urlString: String) -> String? {
  let pattern = "https://paper.dropbox.com/doc/([^\\-]+)--"
  
  do {
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    let results = regex.matches(in: urlString, options: [], range: NSRange(urlString.startIndex..., in: urlString))
    
    if let match = results.first {
      if let range = Range(match.range(at: 1), in: urlString) {
        return String(urlString[range]).replacingOccurrences(of: "-", with: " ")
      }
    }
  } catch {
    print("Invalid regex: \(error.localizedDescription)")
  }
  
  if urlString.contains("zoom.us") { return "Zoom" }
  if urlString.contains("meet.google.com") { return "Meet" }
  
  
  if let url = URL(string: urlString) {
    return url.host()
  }
  
  return nil
}
