import Foundation

/// Renders text as IPA phonemes per https://github.com/arfct/enigma
/// NOTATION.md defaults: en-US, stress as accents (word-initial primary
/// stress unwritten), long vowels doubled, theta as script ϑ (capital ϴ),
/// punctuation and capitalization preserved.
///
/// The site phonemizes with eSpeak NG (GPL, so not bundleable here). Instead,
/// words are looked up in the CMU Pronouncing Dictionary (see Cmudict.swift)
/// for real pronunciations, with compact spelling rules as the fallback for
/// out-of-vocabulary words. Digits pass through so times stay readable.
func convertToEnigma(_ input: String) -> String {
  input.split(separator: " ", omittingEmptySubsequences: false)
    .map { isPhoneticallyOpaque(String($0)) ? String($0) : enigmaWord(String($0)) }
    .joined(separator: " ")
}

/// URLs and acronyms have no useful pronunciation, so phonemizing them
/// destroys the only thing that made them readable. Both pass through
/// untouched. Braille is unaffected: it is a character cipher, and every
/// character still maps.
func isPhoneticallyOpaque(_ token: String) -> Bool {
  isURLLike(token) || isAcronym(token)
}

/// Matches explicit schemes, `www.` hosts, and bare hosts like
/// `meet.google.com/abc-defg` — meeting links usually arrive bare in the
/// location field. Requires an alphabetic TLD of 2+ characters, so "e.g."
/// and "i.e." are not treated as hosts.
private let urlPattern = try! NSRegularExpression(
  pattern: #"(?:[a-z][a-z0-9+.\-]*://\S+)"#
    + #"|(?:www\.\S+)"#
    + #"|(?:[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?)*\.[a-z]{2,24}(?:[/?#]\S*)?)"#,
  options: [.caseInsensitive]
)

private func isURLLike(_ token: String) -> Bool {
  let range = NSRange(token.startIndex..., in: token)
  return urlPattern.firstMatch(in: token, options: [], range: range) != nil
}

/// An all-caps run of 2–5 letters, optionally pluralised: PTO, EOD, NYC,
/// OKRs. The upper bound keeps a shouty title ("TEAM OFFSITE") from passing
/// through wholesale, which would defeat the mode.
private func isAcronym(_ token: String) -> Bool {
  let core = enigmaCore(token)
  guard (2...5).contains(core.count) || (core.count == 6 && core.hasSuffix("s")) else { return false }
  let letters = core.hasSuffix("s") ? String(core.dropLast()) : core
  guard letters.count >= 2 else { return false }
  return letters.allSatisfy { $0.isUppercase && $0.isLetter }
}

/// The alphanumeric middle of a token, with surrounding punctuation peeled.
private func enigmaCore(_ word: String) -> String {
  let leading = word.prefix { !$0.isLetter && !$0.isNumber }
  let trailing = String(word.reversed().prefix { !$0.isLetter && !$0.isNumber }.reversed())
  guard word.count >= leading.count + trailing.count else { return "" }
  return String(word.dropFirst(leading.count).dropLast(trailing.count))
}

private func enigmaWord(_ word: String) -> String {
  guard word.contains(where: { $0.isLetter }) else { return word }

  // Peel punctuation off the ends so it survives untouched (default:
  // punctuation preserved).
  let leading = word.prefix { !$0.isLetter && !$0.isNumber }
  let trailing = String(word.reversed().prefix { !$0.isLetter && !$0.isNumber }.reversed())
  let core = String(word.dropFirst(leading.count).dropLast(trailing.count))
  guard !core.isEmpty else { return word }

  let wasCapitalized = core.first?.isUppercase == true
  let lookupKey = core.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
  // Real pronunciation when the dictionary knows the word; spelling rules
  // as fallback for names and other out-of-vocabulary words. The fallback
  // writes no stress: it can only guess the first syllable, and word-initial
  // primary stress is unwritten by notation.
  var ipa = Cmudict.lookup(lookupKey) ?? graphemesToIPA(lookupKey)

  // Default: capitals preserved. Unicode raises ϑ to Θ; the notation
  // specifies ϴ (U+03F4).
  if wasCapitalized, let first = ipa.first {
    let upper = first == "ϑ" ? "ϴ" : String(first).uppercased()
    ipa = upper + ipa.dropFirst()
  }
  return leading + ipa + trailing
}

// Ordered longest-match spelling rules, en-US flavored. Long vowels are
// written doubled rather than with ː (the site's "Doubling aa" default).
private let enigmaRules: [(String, String)] = [
  ("tion", "ʃən"), ("sion", "ʒən"), ("ture", "tʃəɹ"), ("ough", "ɔɔ"),
  ("eigh", "eɪ"), ("igh", "aɪ"), ("tch", "tʃ"), ("dge", "dʒ"),
  ("ing", "ɪŋ"), ("ear", "ɪɹ"), ("air", "ɛɹ"), ("oor", "ɔɹ"),
  ("ch", "tʃ"), ("sh", "ʃ"), ("th", "ϑ"), ("ph", "f"), ("wh", "w"),
  ("ck", "k"), ("ng", "ŋ"), ("qu", "kw"), ("wr", "ɹ"), ("kn", "n"),
  ("ee", "ii"), ("ea", "ii"), ("oo", "uu"), ("ou", "aʊ"), ("ow", "aʊ"),
  ("oi", "ɔɪ"), ("oy", "ɔɪ"), ("ai", "eɪ"), ("ay", "eɪ"), ("au", "ɔɔ"),
  ("aw", "ɔɔ"), ("ew", "juu"), ("oa", "oʊ"), ("ie", "aɪ"), ("ue", "uu"),
  ("er", "əɹ"), ("ar", "ɑɹ"), ("or", "ɔɹ"),
]

private let enigmaSingles: [Character: String] = [
  "a": "æ", "e": "ɛ", "i": "ɪ", "o": "ɑ", "u": "ʌ",
  "b": "b", "d": "d", "f": "f", "h": "h", "j": "dʒ", "k": "k",
  "l": "l", "m": "m", "n": "n", "p": "p", "r": "ɹ", "s": "s",
  "t": "t", "v": "v", "w": "w", "x": "ks", "z": "z",
]

private func graphemesToIPA(_ word: String) -> String {
  var characters = Array(word)

  // Magic-e: a final silent e lengthens the previous vowel sound.
  if characters.count > 3, characters.last == "e",
     let consonant = characters.dropLast().last, !"aeiou".contains(consonant) {
    characters.removeLast()
  }

  var result = ""
  var i = 0
  while i < characters.count {
    let rest = String(characters[i...])

    if let (pattern, ipa) = enigmaRules.first(where: { rest.hasPrefix($0.0) }) {
      result += ipa
      i += pattern.count
      continue
    }

    let char = characters[i]
    let next = i + 1 < characters.count ? characters[i + 1] : nil
    switch char {
    case "c":
      result += (next.map { "eiy".contains($0) } ?? false) ? "s" : "k"
    case "g":
      result += (next.map { "eiy".contains($0) } ?? false) ? "dʒ" : "g"
    case "y":
      result += i == 0 ? "j" : "i"
    default:
      result += enigmaSingles[char] ?? String(char)
    }
    i += 1
  }
  return result
}
