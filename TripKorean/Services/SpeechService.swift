import AVFoundation

@Observable
class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking = false

    private var speechRate: Float {
        Float(UserDefaults.standard.double(forKey: "speechRate")).clamped(to: 0.3...1.0)
    }

    func speak(_ text: String, language: String = "ko-KR") {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRate
        utterance.pitchMultiplier = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        if self == 0 { return 0.85 }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
