import Foundation

/// Pronunciations from the CMU Pronouncing Dictionary (BSD license,
/// Carnegie Mellon University — see cmudict-LICENSE.txt), pre-converted to
/// IPA at build time with enigma's default styling: stress as accents
/// (acute primary, grave secondary) and long vowels doubled.
///
/// The resource is sorted "word\tipa" lines, memory-mapped and
/// binary-searched so widget processes never load the whole file.
enum Cmudict {
  private static let newline = UInt8(ascii: "\n")
  private static let tab = UInt8(ascii: "\t")

  private static let data: Data? = {
    guard let url = Bundle.main.url(forResource: "cmudict-ipa", withExtension: "txt") else { return nil }
    return try? Data(contentsOf: url, options: .alwaysMapped)
  }()

  static func lookup(_ word: String) -> String? {
    guard let data, !word.isEmpty, word.count < 50 else { return nil }
    let key = Array(word.utf8) + [tab]

    var low = 0
    var high = data.count - 1
    while low <= high {
      let mid = (low + high) / 2
      let lineStart = startOfLine(in: data, from: mid)
      switch compare(key, in: data, lineAt: lineStart) {
      case .orderedSame:
        return ipa(in: data, lineAt: lineStart, keyLength: key.count)
      case .orderedAscending:
        high = lineStart - 1
      case .orderedDescending:
        low = endOfLine(in: data, from: lineStart) + 1
      }
    }
    return nil
  }

  private static func startOfLine(in data: Data, from index: Int) -> Int {
    var i = index
    while i > 0 && data[i - 1] != newline { i -= 1 }
    return i
  }

  private static func endOfLine(in data: Data, from index: Int) -> Int {
    var i = index
    while i < data.count && data[i] != newline { i += 1 }
    return i
  }

  /// Compares the search key against the line's "word\t" prefix.
  private static func compare(_ key: [UInt8], in data: Data, lineAt start: Int) -> ComparisonResult {
    for (offset, keyByte) in key.enumerated() {
      let index = start + offset
      let lineByte = index < data.count ? data[index] : newline
      if keyByte < lineByte { return .orderedAscending }
      if keyByte > lineByte { return .orderedDescending }
    }
    return .orderedSame
  }

  private static func ipa(in data: Data, lineAt start: Int, keyLength: Int) -> String? {
    let valueStart = start + keyLength
    let valueEnd = endOfLine(in: data, from: valueStart)
    guard valueStart <= valueEnd else { return nil }
    return String(data: data[valueStart..<valueEnd], encoding: .utf8)
  }
}
