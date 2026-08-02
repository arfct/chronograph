import Foundation
import AppIntents
import WidgetKit
import SwiftUI
//
//@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
//struct StartRecording: AudioPlaybackIntent {
//
//  @AppStorage("state") private var state = false
//  static var title: LocalizedStringResource = "App Intent"
//  static var description = IntentDescription("Description")
//
//  func perform() async throws -> some IntentResult {
//
//    let recorderPlayer = AudioRecorderPlayer()
//    recorderPlayer.startRecordingAndPlaying()
//    state.toggle()
//
//    return .result()
//  }
//}


@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SetDefault: AppIntent {

  @Parameter(title: "Value")
  var value: String?

  @Parameter(title: "Key")
  var key: String?
  
  @Parameter(title: "Suite")
  var suite: String?
  
  static var title: LocalizedStringResource = "Set Defaults Value"
  static var description = IntentDescription("Assigns a value in the shared group defaults.")
  
  init(_ value: String?, for key: String?, in suite: String? = nil) {
    print("INIT: Set Defaults Value: \(value ?? "nil") for key: \(key ?? "nil")")
    self.value = value
    self.key = key
    self.suite = suite
  }
  
  init() {}
  
  func perform() async throws -> some IntentResult {
    print("Set Defaults Value: \(value ?? "nil") for key: \(key ?? "nil")")
    if let key = key {
        UserDefaults(suiteName: suite)?.set(value, forKey: key)
    }
    return .result()
  }
}
