import SwiftUI
import WidgetKit

/// App-wide Default Size. Widgets whose Font Size is Default, and the app's
/// previews, use it; widgets set to a specific size keep their own.
struct DefaultFontSizePicker: View {
  @AppStorage(Keys.defaultFontSize, store: UserDefaults(suiteName: Keys.suiteName))
  private var defaultFontSize: FontSize = .medium

  var body: some View {
    Picker("Default Size", selection: $defaultFontSize) {
      ForEach(FontSize.sizes, id: \.self) { size in
        Text(FontSize.caseDisplayRepresentations[size]?.title ?? "\(size.rawValue)")
          .tag(size)
      }
    }
    .onChange(of: defaultFontSize) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
