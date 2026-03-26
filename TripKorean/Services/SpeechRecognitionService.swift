@preconcurrency import Speech
@preconcurrency import AVFoundation

final class SpeechRecognitionService: @unchecked Sendable {
    var onTextChanged: (@MainActor (String) -> Void)?
    var onRecordingStopped: (@MainActor () -> Void)?
    var onError: (@MainActor (String) -> Void)?

    private let audioQueue = DispatchQueue(label: "com.tripkorean.audio")
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var authorized: Bool?

    func startRecording(language: String) {
        if authorized == true {
            audioQueue.async { [self] in beginSession(language: language) }
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }
            self.authorized = (status == .authorized)
            if status == .authorized {
                self.audioQueue.async { self.beginSession(language: language) }
            } else {
                Task { @MainActor in self.onError?("请在设置中允许语音识别权限") }
            }
        }
    }

    func stopRecording() {
        audioQueue.async { [self] in tearDown() }
    }

    private func beginSession(language: String) {
        tearDown()

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)),
              recognizer.isAvailable else {
            Task { @MainActor in self.onError?("语音识别不可用") }
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            Task { @MainActor in self.onError?("音频会话配置失败") }
            return
        }

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let format = engine.inputNode.outputFormat(forBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            Task { @MainActor in self.onError?("录音启动失败") }
            return
        }

        self.audioEngine = engine
        self.recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in self.onTextChanged?(text) }
                if result.isFinal {
                    self.audioQueue.async { self.tearDown() }
                    Task { @MainActor in self.onRecordingStopped?() }
                }
            }
            if error != nil {
                self.audioQueue.async { self.tearDown() }
                Task { @MainActor in self.onRecordingStopped?() }
            }
        }
    }

    private func tearDown() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
