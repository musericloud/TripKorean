import SwiftUI
import PhotosUI
@preconcurrency import Translation
@preconcurrency import Vision

struct PhotoTranslateView: View {
    @State private var selectedImage: UIImage?
    @State private var recognizedText = ""
    @State private var translatedText = ""
    @State private var isKoreanToChinese = true
    @State private var isRecognizing = false
    @State private var isTranslating = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var configuration: TranslationSession.Configuration?
    @State private var showSavedToast = false

    let speechService: SpeechService
    let favoritesStore: FavoritesStore

    private var sourceLanguage: Locale.Language {
        isKoreanToChinese ? .init(identifier: "ko") : .init(identifier: "zh-Hans")
    }

    private var targetLanguage: Locale.Language {
        isKoreanToChinese ? .init(identifier: "zh-Hans") : .init(identifier: "ko")
    }

    private var recognizedSpeakLanguage: String {
        isKoreanToChinese ? "ko-KR" : "zh-CN"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TranslationDirectionToggle(isKoreanToChinese: $isKoreanToChinese) {
                    translatedText = ""
                    configuration = nil
                    if !recognizedText.isEmpty {
                        translateText()
                    }
                }
                imageSection

                if !recognizedText.isEmpty {
                    recognizedSection
                }

                if !translatedText.isEmpty {
                    TranslationResultPanel(
                        title: "翻译结果",
                        translatedText: translatedText,
                        emptyPlaceholder: nil,
                        resultSpeakLanguage: isKoreanToChinese ? "zh-CN" : "ko-KR",
                        speechService: speechService,
                        isFavorited: isFavorited,
                        onFavorite: saveFavorite
                    )
                }
            }
            .padding()
        }
        .navigationTitle("拍照翻译")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $selectedImage)
                .ignoresSafeArea()
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                }
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            if newImage != nil {
                recognizeText()
            }
        }
        .translationTask(configuration) { session in
            await performTranslation(session: session)
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

    private var imageSection: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 16) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("相册", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if isRecognizing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在识别文字...")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var recognizedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("识别的文字")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(recognizedText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

            RecognizedTextActionsRow(
                text: recognizedText,
                speakLanguage: recognizedSpeakLanguage,
                speechService: speechService,
                isTranslating: $isTranslating,
                onTranslate: translateText
            )
        }
    }

    private var koreanText: String {
        isKoreanToChinese ? recognizedText : translatedText
    }

    private var chineseText: String {
        isKoreanToChinese ? translatedText : recognizedText
    }

    private var isFavorited: Bool {
        favoritesStore.contains(korean: koreanText, chinese: chineseText)
    }

    private func saveFavorite() {
        guard !translatedText.isEmpty else { return }
        favoritesStore.add(korean: koreanText, chinese: chineseText)
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSavedToast = false }
        }
    }

    private func recognizeText() {
        guard let image = selectedImage, let cgImage = image.cgImage else { return }
        isRecognizing = true
        recognizedText = ""
        translatedText = ""

        let languages: [String] = isKoreanToChinese
            ? ["ko-KR", "zh-Hans"]
            : ["zh-Hans", "ko-KR"]

        Task.detached(priority: .userInitiated) { [languages] in
            let text = Self.performOCR(cgImage: cgImage, languages: languages)
            await MainActor.run {
                recognizedText = text
                isRecognizing = false
                if !text.isEmpty {
                    translateText()
                }
            }
        }
    }

    private nonisolated static func performOCR(cgImage: CGImage, languages: [String]) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private func translateText() {
        guard !recognizedText.isEmpty else { return }
        isTranslating = true

        if configuration == nil {
            configuration = .init(source: sourceLanguage, target: targetLanguage)
        } else {
            configuration?.source = sourceLanguage
            configuration?.target = targetLanguage
            configuration?.invalidate()
        }
    }

    private func performTranslation(session: TranslationSession) async {
        do {
            let response = try await session.translate(recognizedText)
            translatedText = response.targetText
        } catch {
            translatedText = "翻译失败：\(error.localizedDescription)"
        }
        isTranslating = false
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
