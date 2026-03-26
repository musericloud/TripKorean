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
                directionToggle

                VStack(spacing: 16) {
                    inputSection
                    voiceInputButton
                    translationResult
                }
                .padding()

                Spacer()
            }
            .navigationTitle("翻译")
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
            inputText = text
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

    private var directionToggle: some View {
        HStack {
            Text(isKoreanToChinese ? "韩语" : "中文")
                .font(.headline)
                .frame(maxWidth: .infinity)

            Button {
                withAnimation {
                    isKoreanToChinese.toggle()
                    inputText = ""
                    translatedText = ""
                    configuration = nil
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.title2)
            }

            Text(isKoreanToChinese ? "中文" : "韩语")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.ultraThinMaterial)
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
                        speechService.speak(inputText, language: sourceLocaleId)
                    }
                } label: {
                    Label("朗读", systemImage: "speaker.wave.2.fill")
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
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isRecording {
                                isRecording = true
                                voiceError = nil
                                speechRecognition.startRecording(language: sourceLocaleId)
                            }
                        }
                        .onEnded { _ in
                            speechRecognition.stopRecording()
                        }
                )

            if let error = voiceError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var translationResult: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("翻译结果")
                .font(.caption)
                .foregroundStyle(.secondary)

            if translatedText.isEmpty {
                Text("输入文本或按住说话")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text(translatedText)
                    .font(.title3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                HStack {
                    Button {
                        let lang = isKoreanToChinese ? "zh-CN" : "ko-KR"
                        speechService.speak(translatedText, language: lang)
                    } label: {
                        Label("朗读", systemImage: "speaker.wave.2.fill")
                    }

                    Spacer()

                    Button {
                        UIPasteboard.general.string = translatedText
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }

                    Spacer()

                    Button {
                        saveFavorite()
                    } label: {
                        Label(
                            isFavorited ? "已收藏" : "收藏",
                            systemImage: isFavorited ? "star.fill" : "star"
                        )
                        .foregroundStyle(isFavorited ? .yellow : .blue)
                    }
                }
            }
        }
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
