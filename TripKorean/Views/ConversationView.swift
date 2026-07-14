import SwiftUI
@preconcurrency import Translation

// MARK: - 模型

struct ConversationMessage: Identifiable, Equatable {
    let id = UUID()
    /// 说话人是否说韩语（韩语 → 中文）
    let isKoreanSource: Bool
    var sourceText: String
    var translatedText: String = ""
    var isTranslating = true

    var koreanText: String { isKoreanSource ? sourceText : translatedText }
    var chineseText: String { isKoreanSource ? translatedText : sourceText }
}

// MARK: - 对话翻译

struct ConversationView: View {
    let speechService: SpeechService
    let favoritesStore: FavoritesStore

    @State private var messages: [ConversationMessage] = []
    @State private var recordingKorean: Bool?
    @State private var liveText = ""
    @State private var voiceError: String?
    @State private var zhToKoConfig: TranslationSession.Configuration?
    @State private var koToZhConfig: TranslationSession.Configuration?
    @State private var speechRecognition = SpeechRecognitionService()
    @AppStorage("conversationAutoSpeak") private var autoSpeak = true

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty && recordingKorean == nil {
                emptyState
            } else {
                messageList
            }

            if let error = voiceError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.bottom, 4)
            }

            recordButtons
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("对话翻译")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    autoSpeak.toggle()
                } label: {
                    Image(systemName: autoSpeak ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .help("自动朗读译文")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { messages.removeAll() }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(messages.isEmpty)
            }
        }
        .translationTask(zhToKoConfig) { session in
            await translatePending(session: session, koreanSource: false)
        }
        .translationTask(koToZhConfig) { session in
            await translatePending(session: session, koreanSource: true)
        }
        .onAppear {
            setupSpeechCallbacks()
        }
        .onDisappear {
            speechRecognition.stopRecording()
        }
    }

    // MARK: 视图

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.line.dotted.person.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("面对面对话")
                .font(.title3)
                .fontWeight(.semibold)
            Text("你按住左边说中文，对方按住右边说韩语\n松手后自动翻译并朗读")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ConversationBubble(
                            message: message,
                            speechService: speechService,
                            favoritesStore: favoritesStore
                        )
                        .id(message.id)
                    }

                    if let recordingKorean {
                        listeningBubble(isKorean: recordingKorean)
                            .id("listening")
                    }
                }
                .padding()
            }
            .onChange(of: messages) {
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: liveText) {
                proxy.scrollTo("listening", anchor: .bottom)
            }
            .onChange(of: recordingKorean) {
                if recordingKorean != nil {
                    withAnimation { proxy.scrollTo("listening", anchor: .bottom) }
                }
            }
        }
    }

    private func listeningBubble(isKorean: Bool) -> some View {
        HStack {
            if !isKorean { Spacer(minLength: 48) }
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor, isActive: true)
                Text(liveText.isEmpty ? "正在听..." : liveText)
            }
            .font(.body)
            .foregroundStyle(.white)
            .padding(12)
            .background(
                isKorean ? Color.orange.opacity(0.85) : Color.blue.opacity(0.85),
                in: RoundedRectangle(cornerRadius: 16)
            )
            if isKorean { Spacer(minLength: 48) }
        }
    }

    private var recordButtons: some View {
        HStack(spacing: 12) {
            holdToTalkButton(
                isKorean: false,
                title: "按住 说中文",
                subtitle: "中文 → 한국어",
                color: .blue
            )
            holdToTalkButton(
                isKorean: true,
                title: "한국어로 말하기",
                subtitle: "韩语 → 中文",
                color: .orange
            )
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func holdToTalkButton(isKorean: Bool, title: String, subtitle: String, color: Color) -> some View {
        let isActive = recordingKorean == isKorean
        let isOtherActive = recordingKorean != nil && !isActive

        return VStack(spacing: 4) {
            Image(systemName: isActive ? "waveform" : "mic.fill")
                .font(.title3)
                .symbolEffect(.variableColor, isActive: isActive)
            Text(isActive ? "松手翻译" : title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.caption2)
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(isActive ? Color.red : color, in: RoundedRectangle(cornerRadius: 18))
        .scaleEffect(isActive ? 1.03 : 1)
        .opacity(isOtherActive ? 0.4 : 1)
        .animation(.spring(duration: 0.25), value: recordingKorean)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    beginRecording(korean: isKorean)
                }
                .onEnded { _ in
                    endRecording()
                }
        )
    }

    // MARK: 录音

    private func setupSpeechCallbacks() {
        speechRecognition.onTextChanged = { text in
            if !text.isEmpty {
                liveText = text
            }
        }
        speechRecognition.onRecordingStopped = {
            finishRecording()
        }
        speechRecognition.onError = { message in
            recordingKorean = nil
            liveText = ""
            voiceError = message
        }
    }

    private func beginRecording(korean: Bool) {
        guard recordingKorean == nil else { return }
        speechService.stop()
        recordingKorean = korean
        liveText = ""
        voiceError = nil
        speechRecognition.startRecording(language: korean ? "ko-KR" : "zh-CN")
    }

    private func endRecording() {
        guard recordingKorean != nil else { return }
        speechRecognition.stopRecording()
    }

    private func finishRecording() {
        guard let korean = recordingKorean else { return }
        recordingKorean = nil

        let text = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        liveText = ""
        guard !text.isEmpty else { return }

        withAnimation(.spring(duration: 0.3)) {
            messages.append(ConversationMessage(isKoreanSource: korean, sourceText: text))
        }
        triggerTranslation(koreanSource: korean)
    }

    // MARK: 翻译

    private func triggerTranslation(koreanSource: Bool) {
        if koreanSource {
            if koToZhConfig == nil {
                koToZhConfig = .init(
                    source: .init(identifier: "ko"),
                    target: .init(identifier: "zh-Hans")
                )
            } else {
                koToZhConfig?.invalidate()
            }
        } else {
            if zhToKoConfig == nil {
                zhToKoConfig = .init(
                    source: .init(identifier: "zh-Hans"),
                    target: .init(identifier: "ko")
                )
            } else {
                zhToKoConfig?.invalidate()
            }
        }
    }

    private func translatePending(session: TranslationSession, koreanSource: Bool) async {
        for index in messages.indices where messages[index].isKoreanSource == koreanSource && messages[index].isTranslating {
            do {
                let response = try await session.translate(messages[index].sourceText)
                messages[index].translatedText = response.targetText
            } catch {
                messages[index].translatedText = "翻译失败：\(error.localizedDescription)"
            }
            messages[index].isTranslating = false

            if autoSpeak, !messages[index].translatedText.hasPrefix("翻译失败") {
                speechService.speak(
                    messages[index].translatedText,
                    language: koreanSource ? "zh-CN" : "ko-KR"
                )
            }
        }
    }
}

// MARK: - 气泡

struct ConversationBubble: View {
    let message: ConversationMessage
    let speechService: SpeechService
    let favoritesStore: FavoritesStore
    @AppStorage("showPronunciation") private var showPronunciation = true

    /// 韩语说话人靠左（对方），中文说话人靠右（自己）
    private var alignLeft: Bool { message.isKoreanSource }
    private var color: Color { message.isKoreanSource ? .orange : .blue }

    private var isFavorited: Bool {
        favoritesStore.contains(korean: message.koreanText, chinese: message.chineseText)
    }

    var body: some View {
        HStack {
            if !alignLeft { Spacer(minLength: 48) }

            VStack(alignment: .leading, spacing: 6) {
                Label(
                    message.isKoreanSource ? "한국어 · 韩语" : "中文",
                    systemImage: message.isKoreanSource ? "person.fill" : "person.crop.circle.fill"
                )
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))

                Text(message.sourceText)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                if message.isKoreanSource && showPronunciation {
                    Text(KoreanRomanizer.romanize(message.sourceText))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Divider()
                    .overlay(.white.opacity(0.4))

                if message.isTranslating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .tint(.white)
                        Text("翻译中...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    Text(message.translatedText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    if !message.isKoreanSource && showPronunciation {
                        Text(KoreanRomanizer.romanize(message.translatedText))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    HStack(spacing: 16) {
                        Button {
                            speechService.toggleSpeak(
                                message.translatedText,
                                language: message.isKoreanSource ? "zh-CN" : "ko-KR"
                            )
                        } label: {
                            Image(systemName: speechService.isSpeaking(message.translatedText) ? "stop.fill" : "speaker.wave.2.fill")
                        }

                        Button {
                            UIPasteboard.general.string = message.translatedText
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }

                        Button {
                            favoritesStore.add(korean: message.koreanText, chinese: message.chineseText)
                        } label: {
                            Image(systemName: isFavorited ? "star.fill" : "star")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 18))

            if alignLeft { Spacer(minLength: 48) }
        }
    }
}
