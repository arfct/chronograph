import Foundation
import AVFoundation

class AudioRecorderPlayer: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {

    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    var timer: Timer?

    func startRecordingAndPlaying() {
        // Request permission to record audio
      AVAudioApplication.requestRecordPermission { granted in
            if granted {
                self.setupAudioSession()
                self.startRecording()
            } else {
                print("Permission to record not granted")
            }
        }
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .mixWithOthers)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session")
        }
    }

    private func startRecording() {
      print("start recording")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let url = getDocumentsDirectory().appendingPathComponent("recording.m4a")

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            // Stop recording after 5 seconds
            timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(stopRecording), userInfo: nil, repeats: false)
        } catch {
            print("Failed to start recording")
        }
    }

    @objc func stopRecording() {
      print("stop recording")
        audioRecorder?.stop()
        timer?.invalidate()
        playRecording()
    }

    private func playRecording() {
        let url = getDocumentsDirectory().appendingPathComponent("recording.m4a")
      print("play", url)
        do {
          try AVAudioSession.sharedInstance().setCategory(.playback)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("Failed to play recording")
        }
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    // MARK: - AVAudioRecorderDelegate methods
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            stopRecording()
        }
    }

    // MARK: - AVAudioPlayerDelegate methods
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Handle completion of playback if needed
    }
}
