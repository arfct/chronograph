import Foundation

func extractEmoji(from input: String) -> (emojis: String, remaining: String) {
  var emojis = ""
  var remaining = ""

  for char in input {
    if char.unicodeScalars.contains(where: {
      $0.properties.isEmoji && $0.properties.isEmojiPresentation && $0.properties.numericType != .decimal
    }) {
      emojis.append(char)
    } else {
      remaining.append(char)
    }
  }

  return (emojis, remaining.trimmingCharacters(in: .whitespacesAndNewlines))
}

