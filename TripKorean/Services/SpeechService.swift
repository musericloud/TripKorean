import AVFoundation

@Observable
class SpeechService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private(set) var currentText: String?

    private var speechRate: Float {
        Float(UserDefaults.standard.double(forKey: "speechRate")).clamped(to: 0.3...1.0)
    }

    override init() {
        super.init()
        // 走系统朗读通道，避免录音会话的 .measurement 模式劣化音质
        synthesizer.usesApplicationAudioSession = false
        synthesizer.delegate = self
    }

    // MARK: - 语音选择

    /// 某语言已安装的可用语音（排除 Eloquence 玩具音色），按质量从高到低排序
    static func installedVoices(for language: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language && !$0.identifier.contains("eloquence") }
            .sorted { rank($0) > rank($1) }
    }

    /// 质量优先级：premium > enhanced > default；同级优先 super-compact（Siri 朗读同款）
    private static func rank(_ voice: AVSpeechSynthesisVoice) -> (Int, Int) {
        (voice.quality.rawValue, voice.identifier.contains("super-compact") ? 1 : 0)
    }

    static func qualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: "高级"
        case .enhanced: "增强"
        default: "标准"
        }
    }

    /// 用户手动选择的语音（设置页），空字符串表示自动
    static func storageKey(for language: String) -> String {
        "voiceId.\(language)"
    }

    private func resolvedVoice(for language: String) -> AVSpeechSynthesisVoice? {
        if let id = UserDefaults.standard.string(forKey: Self.storageKey(for: language)),
           !id.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        return Self.installedVoices(for: language).first ?? AVSpeechSynthesisVoice(language: language)
    }

    // MARK: - 朗读

    func isSpeaking(_ text: String) -> Bool {
        currentText == text
    }

    func speak(_ text: String, language: String = "ko-KR") {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = resolvedVoice(for: language)
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
        audioPlayer?.stop()
        audioPlayer = nil
        currentText = nil
    }

    // MARK: - 韩文字母/音节（优先真人级预生成音频，缺失时回退 TTS）

    /// 发音学习页专用：播放打包的 SunHi 神经语音音频
    func speakHangul(_ text: String) {
        stop()

        guard let url = Self.bundledAudioURL(for: text) else {
            speak(text)
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            audioPlayer = player
            currentText = text
            player.play()
        } catch {
            speak(text)
        }
    }

    func toggleSpeakHangul(_ text: String) {
        if isSpeaking(text) {
            stop()
        } else {
            speakHangul(text)
        }
    }

    /// 文件名为字符 Unicode 码点（十六进制）用 - 连接，如 아 → C544.mp3
    static func bundledAudioURL(for text: String) -> URL? {
        let name = text.unicodeScalars.map { String(format: "%X", $0.value) }.joined(separator: "-")
        return Bundle.main.url(forResource: name, withExtension: "mp3")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "HangulAudio")
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.currentText = nil }
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
