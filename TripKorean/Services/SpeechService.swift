import AVFoundation

@Observable
class SpeechService: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var currentText: String?

    private var speechRate: Float {
        Float(UserDefaults.standard.double(forKey: "speechRate")).clamped(to: 0.3...1.0)
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func isSpeaking(_ text: String) -> Bool {
        currentText == text
    }

    func speak(_ text: String, language: String = "ko-KR") {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRate
        utterance.pitchMultiplier = 1.0

        currentText = text
        synthesizer.speak(utterance)
    }

    func toggleSpeak(_ text: String, language: String = "ko-KR") {
        if isSpeaking(text) {
            stop()
        } else {
            speak(text, language: language)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        currentText = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.currentText = nil }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.currentText = nil }
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        if self == 0 { return 0.85 }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
