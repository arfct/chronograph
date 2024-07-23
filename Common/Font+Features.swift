import SwiftUI

#if os(macOS)
  import Cocoa
typealias UIFontDescriptor = NSFontDescriptor

#endif

import SwiftUI

extension UIFont {
  static func customFont(with attributes: [UIFontDescriptor.AttributeName: Any]) -> UIFont? {
    let descriptor = UIFontDescriptor(fontAttributes: attributes)
    return UIFont(descriptor: descriptor, size: 16)
  }
}

import CoreText

extension Font {
  static func customFont(with attributes: [UIFontDescriptor.AttributeName: Any]) -> Font?{
    if let uiFont = UIFont.customFont(with: attributes) {
      return Font(uiFont as CTFont)
    }
    return nil
  }
}

extension Font {
  func withCustomFeatures(_ attributes: [UIFontDescriptor.AttributeName: Any]) -> Font {
    if let font = Font.customFont(with: attributes) {
      return font
    }
    return self
  }
}

//
//
//extension UIFont {
//    
//    /// Watch [WWDC Session](https://developer.apple.com/videos/play/wwdc2015/804/).
//    /// [Font Feature Registry](https://developer.apple.com/fonts/TrueType-Reference-Manual/RM09/AppendixF.html)
//    /// - Parameters:
//    ///   - size: The size (in points) to which the font is scaled. This value must be greater than 0.0.
//    ///   - weight: The weight of the font, specified as a font weight constant.
//    ///   - features: Font features supported by SFPro
//    ///   - italic: Italic variant of the font.
//    public static func systemFont(
//        ofSize size: CGFloat,
//        weight: Weight = .regular,
//        features: [Feature] = [],
//        italic: Bool = false
//    ) -> UIFont {
//        let key = Key(size: size, weight: weight, features: features, italic: italic)
//        if let font = cache[key] { return font }
//        let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
//        let font = UIFont(
//            descriptor: descriptor
//                .addingAttributes([.featureSettings: features.map { $0.setting }])
//                .withSymbolicTraits(descriptor
//                    .symbolicTraits
//                    .union(italic ? .traitExpanded : .init(rawValue: 0))
//                ) ?? descriptor,
//            size: size
//        )
//        cache[key] = font
//        return font
//    }
//    
//    public struct Feature: Hashable {
//        private let type: Int
//        private let selector: Int
//        fileprivate var setting: [UIFontDescriptor.FeatureKey : Int] { [.featureIdentifier: type, .typeIdentifier: selector] }
//        
//        public static let straightSidedSixAndNine = Feature(type: kStylisticAlternativesType, selector: kStylisticAltOneOnSelector)
//        public static let openFour = Feature(type: kStylisticAlternativesType, selector: kStylisticAltTwoOnSelector)
//        public static let verticallyAlignedColon = Feature(type: kStylisticAlternativesType, selector: kStylisticAltThreeOnSelector)
//        public static let highLegibility = Feature(type: kStylisticAlternativesType, selector: kStylisticAltSixOnSelector)
//        public static let oneStoreyA = Feature(type: kStylisticAlternativesType, selector: kStylisticAltSixOnSelector)
//        public static let monospacedNumbers = Feature(type: kNumberSpacingType, selector: kMonospacedNumbersSelector)
//        public static let diagonalFractions = Feature(type: kFractionsType, selector: kDiagonalFractionsSelector)
//        public static let loverCaseSmallCaps = Feature(type: kLowerCaseType, selector: kLowerCaseSmallCapsSelector)
//        public static let upperCaseSmallCaps = Feature(type: kUpperCaseType, selector: kUpperCaseSmallCapsSelector)
//    }
//    
//    // For performance reasons fonts are cached
//    private static var cache = [Key: UIFont]()
//    
//    private struct Key: Hashable {
//        let size: CGFloat
//        let weight: Weight
//        let features: [Feature]
//        let italic: Bool
//    }
//
//}
