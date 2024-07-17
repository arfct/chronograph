struct Keys {
  #if os(macOS)
  
  static let suiteName = "A7X888RRVJ.chronograph.page"
  #else
  static let suiteName = "group.page.chronograph"
  #endif

  static let tokenizeParens = "tokenizeParens"
  static let compactTime = "compactTime"
}

struct Values {
  static let summary = "summary"
  static let listen = "listen"
  static let profile = "profile"
  
}
struct Defaults {
  static let serverAddress = "https://vermillion.ai/api/"
}
