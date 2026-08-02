import Foundation

enum ObfuscationStyle: String, CaseIterable, Identifiable {
  case none, braille, ishihara, enigma

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .none: return "None"
    case .braille: return "Braille"
    case .ishihara: return "Ishihara"
    case .enigma: return "Enigma"
    }
  }

  /// Resolves the stored style, honoring the legacy Braille Mode toggle
  /// (which rendered with the Ishihara font).
  static func resolve(rawValue: String, legacyBrailleMode: Bool) -> ObfuscationStyle {
    if let style = ObfuscationStyle(rawValue: rawValue) {
      return style
    }
    return legacyBrailleMode ? .ishihara : .none
  }

  /// The text transformation for this style, or nil when text passes through
  /// unchanged (.ishihara obfuscates via the font, not the text).
  var textTransform: ((String) -> String)? {
    switch self {
    case .braille: return convertToBraille
    case .enigma: return convertToEnigma
    case .none, .ishihara: return nil
    }
  }
}
