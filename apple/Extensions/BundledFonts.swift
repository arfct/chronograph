import CoreText
import Foundation

/// Registers the fonts shipped in the bundle for this process.
///
/// iOS and watchOS do this from `UIAppFonts`. macOS reads
/// `ATSApplicationFontsPath` instead, and only for app bundles, so the Mac
/// widget extension has to register its copy itself or the Ishihara
/// obfuscation style silently falls back to the system font.
enum BundledFonts {
  private static let registered: Bool = {
#if os(macOS)
    for url in Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [] {
      // Already-registered is the common, harmless failure here.
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
#endif
    return true
  }()

  /// Idempotent; cheap to call from any entry point.
  static func registerIfNeeded() {
    _ = registered
  }
}
