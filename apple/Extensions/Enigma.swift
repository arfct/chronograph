import Foundation

/// Renders text as IPA phonemes in the style of https://github.com/arfct/enigma
/// with its default settings: en-US, stress as accents, long vowels doubled,
/// punctuation and capitalization preserved.
///
/// The site phonemizes with eSpeak NG (GPL, so not bundleable here). Instead,
/// words are looked up in the CMU Pronouncing Dictionary (see Cmudict.swift)
/// for real pronunciations, with compact spelling rules as the fallback for
/// out-of-vocabulary words. Digits pass through so times stay readable.
func convertToEnigma(_ input: String) -> String {
  input.split(separator: " ", omittingEmptySubsequences: false)
    .map { enigmaWord(String($0)) }
    .joined(separator: " ")
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
  // as fallback for names and other out-of-vocabulary words.
  var ipa = Cmudict.lookup(lookupKey) ?? applyStressAccent(graphemesToIPA(lookupKey))

  // Default: capitals preserved.
  if wasCapitalized, let first = ipa.first {
    ipa = String(first).uppercased() + ipa.dropFirst()
  }
  return leading + ipa + trailing
}

// Ordered longest-match spelling rules, en-US flavored. Long vowels are
// written doubled rather than with ː (the site's "Doubling aa" default).
private let enigmaRules: [(String, String)] = [
  ("tion", "ʃən"), ("sion", "ʒən"), ("ture", "tʃəɹ"), ("ough", "ɔɔ"),
  ("eigh", "eɪ"), ("igh", "aɪ"), ("tch", "tʃ"), ("dge", "dʒ"),
  ("ing", "ɪŋ"), ("ear", "ɪɹ"), ("air", "ɛɹ"), ("oor", "ɔɹ"),
  ("ch", "tʃ"), ("sh", "ʃ"), ("th", "θ"), ("ph", "f"), ("wh", "w"),
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

private let ipaVowels = Set("æɛɪɑʌəaeiouʊɔ")

/// First-syllable stress as a combining acute accent (the site's default
/// "Accents" stress style).
private func applyStressAccent(_ ipa: String) -> String {
  var vowelGroups = 0
  var previousWasVowel = false
  for character in ipa {
    let isVowel = ipaVowels.contains(character)
    if isVowel && !previousWasVowel { vowelGroups += 1 }
    previousWasVowel = isVowel
  }
  guard vowelGroups > 1 else { return ipa }

  guard let index = ipa.firstIndex(where: { ipaVowels.contains($0) }) else { return ipa }
  var result = ipa
  result.insert("\u{0301}", at: result.index(after: index))
  return result
}
