import Foundation
import AppIntents
import WidgetKit
import SwiftUI

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct StartRecording: AudioPlaybackIntent {
  
  @AppStorage("state") private var state = false
  static var title: LocalizedStringResource = "App Intent"
  static var description = IntentDescription("Description")
  
  func perform() async throws -> some IntentResult {
    
    let recorderPlayer = AudioRecorderPlayer()
    recorderPlayer.startRecordingAndPlaying()
    state.toggle()
    
    return .result()
  }
}
