import SwiftUI

struct WeatherSettingsView: View {
  @AppStorage(Keys.tokenizeParens, store: UserDefaults(suiteName: Keys.suiteName))
  private var tokenize = false
  @AppStorage(Keys.compactTime, store: UserDefaults(suiteName: Keys.suiteName))
  private var compactTime = true
  @AppStorage(Keys.weatherUseCurrentLocation, store: UserDefaults(suiteName: Keys.suiteName))
  private var useCurrentLocation = true
  @AppStorage(Keys.weatherZipCode, store: UserDefaults(suiteName: Keys.suiteName))
  private var zipCode = ""
  @State private var zipCodeDraft = ""

  var body: some View {
    Form {
      Section {
        Toggle("Use Current Location", isOn: $useCurrentLocation)
        if !useCurrentLocation {
          // Draft + commit-on-submit so each keystroke doesn't trigger a
          // geocode and forecast fetch.
          TextField("Zip Code", text: $zipCodeDraft)
            .onAppear { zipCodeDraft = zipCode }
            .onSubmit { zipCode = zipCodeDraft.trimmingCharacters(in: .whitespaces) }
            .onDisappear { zipCode = zipCodeDraft.trimmingCharacters(in: .whitespaces) }
#if os(iOS)
            .keyboardType(.numbersAndPunctuation)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .submitLabel(.done)
#endif
        }
      } header: {
        Text("Location")
      } footer: {
        Text("Applies to this preview. Each widget can choose its own location when editing the widget.")
      }

      Section(header: Text("Display Options")) {
        Toggle("Compact Time", isOn: $compactTime)
        Toggle("Wrap Parentheses", isOn: $tokenize)
      }
    }
  }
}

#Preview {
  WeatherSettingsView()
}
