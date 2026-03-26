import SwiftUI
@preconcurrency import Translation

struct TranslateView: View {
    @State private var inputText = ""
    @State private var translatedText = ""
    @State private var isKoreanToChinese = false
    @State private var isTranslating = false
    @State private var isRecording = false
    @State private var voiceError: String?
    @State private var configuration: TranslationSession.Configuration?
    @State private var showSavedToast = false
    let speechService: SpeechService
    let favoritesStore: FavoritesStore

    @State private var speechRecognition = SpeechRecognitionService()

    private var sourceLanguage: Locale.Language {
        isKoreanToChinese ? .init(identifier: "ko") : .init(identifier: "zh-Hans")
    }

    private var targetLanguage: Locale.Language {
        isKoreanToChinese ? .init(identifier: "zh-Hans") : .init(identifier: "ko")
    }

    private var sourceLocaleId: String {
        isKoreanToChinese ? "ko-KR" : "zh-CN"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TranslationDirectionToggle(isKoreanToChinese: $isKoreanToChinese) {
                    inputText = ""
                    translatedText = ""
                    configuration = nil
                }

                VStack(spacing: 16) {
                    inputSection
                    voiceInputButton
                    TranslationResultPanel(
                        title: "翻译结果",
                        translatedText: translatedText,
                        emptyPlaceholder: "输入文本或按住说话",
                        resultSpeakLanguage: isKoreanToChinese ? "zh-CN" : "ko-KR",
                        speechService: speechService,
                        isFavorited: isFavorited,
                        onFavorite: saveFavorite
                    )
                }
                .padding()

                Spacer()
            }
            .navigationTitle("翻译")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        PhotoTranslateView(speechService: speechService, favoritesStore: favoritesStore)
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .overlay(alignment: .top) {
                if showSavedToast {
                    Text("已收藏 ★")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
        }
        .translationTask(configuration) { session in
            await performTranslation(session: session)
        }
        .onAppear {
            setupSpeechCallbacks()
        }
    }

    private func setupSpeechCallbacks() {
        speechRecognition.onTextChanged = { text in
            if !text.isEmpty {
                inputText = text
            }
        }
        speechRecognition.onRecordingStopped = {
            isRecording = false
            if !inputText.isEmpty {
                translateText()
            }
        }
        speechRecognition.onError = { message in
            isRecording = false
            voiceError = message
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("输入文本")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $inputText)
                .frame(minHeight: 100, maxHeight: 150)
                .padding(8)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

            HStack {
                Button {
                    if !inputText.isEmpty {
                        speechService.toggleSpeak(inputText, language: sourceLocaleId)
                    }
                } label: {
                    Label(
                        speechService.isSpeaking(inputText) ? "停止" : "朗读",
                        systemImage: speechService.isSpeaking(inputText) ? "stop.fill" : "speaker.wave.2.fill"
                    )
                }
                .disabled(inputText.isEmpty)

                Spacer()

                Button {
                    translateText()
                } label: {
                    if isTranslating {
                        ProgressView()
                            .padding(.horizontal, 8)
                    } else {
                        Label("翻译", systemImage: "arrow.right.circle.fill")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.isEmpty || isTranslating)
            }
        }
    }

    private var voiceInputButton: some View {
        VStack(spacing: 6) {
            Text(isRecording ? "松手结束" : "按住说话")
                .font(.caption)
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 16)
                .fill(isRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                .frame(height: 56)
                .overlay {
                    HStack(spacing: 8) {
                        Image(systemName: isRecording ? "waveform" : "mic.fill")
                            .font(.title2)
                            .foregroundStyle(isRecording ? .red : .blue)
                            .symbolEffect(.variableColor, isActive: isRecording)

                        if isRecording {
                            Text("正在听...")
                                .foregroundStyle(.red)
                                .fontWeight(.medium)
                        } else {
                            Text("语音输入")
                                .foregroundStyle(.blue)
                                .fontWeight(.medium)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isRecording ? Color.red.opacity(0.3) : Color.blue.opacity(0.2), lineWidth: 1.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            beginVoiceInputIfNeeded()
                        }
                        .onEnded { _ in
                            endVoiceInputIfNeeded()
                        }
                )

            if let error = voiceError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func beginVoiceInputIfNeeded() {
        guard !isRecording else { return }
        isRecording = true
        voiceError = nil
        speechRecognition.startRecording(language: sourceLocaleId)
    }

    private func endVoiceInputIfNeeded() {
        guard isRecording else { return }
        speechRecognition.stopRecording()
    }

    private var koreanText: String {
        isKoreanToChinese ? inputText : translatedText
    }

    private var chineseText: String {
        isKoreanToChinese ? translatedText : inputText
    }

    private var isFavorited: Bool {
        favoritesStore.contains(korean: koreanText, chinese: chineseText)
    }

    private func saveFavorite() {
        guard !translatedText.isEmpty else { return }
        favoritesStore.add(korean: koreanText, chinese: chineseText)
        withAnimation {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSavedToast = false
            }
        }
    }

    private func translateText() {
        guard !inputText.isEmpty else { return }
        isTranslating = true

        if configuration == nil {
            configuration = .init(
                source: sourceLanguage,
                target: targetLanguage
            )
        } else {
            configuration?.source = sourceLanguage
            configuration?.target = targetLanguage
            configuration?.invalidate()
        }
    }

    private func performTranslation(session: TranslationSession) async {
        do {
            let response = try await session.translate(inputText)
            translatedText = response.targetText
        } catch {
            translatedText = "翻译失败：\(error.localizedDescription)"
        }
        isTranslating = false
    }
}
