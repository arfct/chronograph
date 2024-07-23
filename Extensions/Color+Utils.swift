import SwiftUI


extension Color {
  func toHex() -> String? {
#if os(macOS)
    let uic = NSColor(self)
#else
    let uic = UIColor(self)
#endif
    guard let components = uic.cgColor.components, components.count >= 3 else {
      return nil
    }
    let r = Float(components[0])
    let g = Float(components[1])
    let b = Float(components[2])
    var a = Float(1.0)
    
    if components.count >= 4 {
      a = Float(components[3])
    }
    
    if a != Float(1.0) {
      return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
    } else {
      return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
  }
  
  static func withHex(_ hex: String) -> Color{
    
    switch(hex) {
    case "white":
      return .white
    case "black":
      return .black
    case "light":
      return .white.opacity(0.5)
    case "dark":
      return .black.opacity(0.5)
    case "transparent":
      return .clear
    default:
      
      let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
      var int: UInt64 = 0
      Scanner(string: hex).scanHexInt64(&int)
      let a, r, g, b: UInt64
      switch hex.count {
      case 3: // RGB (12-bit)
        (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
      case 4: // RGB (12-bit)
        (r, g, b, a) = ((int >> 12) * 17, (int >> 8 & 0xF) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
      case 6: // RGB (24-bit)
        (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
      case 8: // RGBA (32-bit)
        (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
      default:
        (r, g, b, a) = (1, 1, 1, 0)
      }
      
      return Color(
        .sRGB,
        red: Double(r) / 255,
        green: Double(g) / 255,
        blue:  Double(b) / 255,
        opacity: Double(a) / 255
      )
    }
  }
}

private extension Color {
  static var random: Color {
    var generator: RandomNumberGenerator = SystemRandomNumberGenerator()
    return random(using: &generator)
  }
  
  static func random(using generator: inout RandomNumberGenerator) -> Color {
    let red = Double.random(in: 0..<1, using: &generator)
    let green = Double.random(in: 0..<1, using: &generator)
    let blue = Double.random(in: 0..<1, using: &generator)
    return Color(red: red, green: green, blue: blue)
  }
}


extension Color {
  func contrastingColor() -> Color {
    return isDark() ? .white : .black
  }
  
  func forScheme(scheme: ColorScheme) -> Color {
    
#if os(macOS)
    let uiColor = NSColor(self)
#else
    let uiColor = UIColor(self)
#endif
    
    // Get the hue component
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    
    uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    return Color(hue: hue, saturation: saturation, brightness: scheme == .dark ? 0.8 : 0.6 )
  }
  func isDark() -> Bool {
    // Extract the RGB components
    
#if os(macOS)
    let uic = NSColor(self)
#else
    let uic = UIColor(self)
#endif
    
    
    let components = uic.cgColor.components
    
    
    let red = components?[0] ?? 0
    let green = components?[1] ?? 0
    let blue = components?[2] ?? 0
    
    // Calculate luminance
    let luminance = (0.299 * red + 0.587 * green + 0.114 * blue)
    
    // Return black or white based on luminance
    return luminance < 0.5
  }
  
}
