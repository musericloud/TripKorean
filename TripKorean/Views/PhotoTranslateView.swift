import SwiftUI
import PhotosUI
import SafariServices
@preconcurrency import Translation
@preconcurrency import Vision

// MARK: - 识别块

struct RecognizedBlock: Identifiable, Equatable {
    let id = UUID()
    let text: String
    /// 归一化坐标（左上原点）
    let box: CGRect
    var translation: String = ""
}

struct DictionaryQuery: Identifiable {
    let id = UUID()
    let term: String

    var url: URL? {
        let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        return URL(string: "https://zh.dict.naver.com/#/search?query=\(encoded)")
    }
}

struct PhotoTranslateView: View {
    @State private var selectedImage: UIImage?
    @State private var blocks: [RecognizedBlock] = []
    @State private var selectedIDs: [UUID] = []
    @State private var isMultiSelect = false
    @State private var isKoreanToChinese = true
    @State private var isRecognizing = false
    @State private var isTranslating = false
    @State private var recognitionFailed = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var configuration: TranslationSession.Configuration?
    @State private var showSavedToast = false
    @State private var isListExpanded = false
    @State private var dictionaryQuery: DictionaryQuery?

    // 合并翻译
    @State private var mergedSource = ""
    @State private var mergedTranslation = ""
    @State private var isTranslatingMerged = false
    @State private var pendingMergedSource: String?

    // 图片缩放
    @State private var zoomScale: CGFloat = 1
    @State private var steadyZoom: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var steadyPan: CGSize = .zero

    let speechService: SpeechService
    let favoritesStore: FavoritesStore

    init(speechService: SpeechService, favoritesStore: FavoritesStore, initialImage: UIImage? = nil) {
        self.speechService = speechService
        self.favoritesStore = favoritesStore
        _selectedImage = State(initialValue: initialImage)
    }

    private var sourceLanguage: Locale.Language {
        isKoreanToChinese ? .init(identifier: "ko") : .init(identifier: "zh-Hans")
    }

    private var targetLanguage: Locale.Language {
        isKoreanToChinese ? .init(identifier: "zh-Hans") : .init(identifier: "ko")
    }

    private var sourceSpeakLanguage: String {
        isKoreanToChinese ? "ko-KR" : "zh-CN"
    }

    private var targetSpeakLanguage: String {
        isKoreanToChinese ? "zh-CN" : "ko-KR"
    }

    private var selectedBlocks: [RecognizedBlock] {
        blocks.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                TranslationDirectionToggle(isKoreanToChinese: $isKoreanToChinese) {
                    configuration = nil
                    clearSelection()
                    if selectedImage != nil {
                        recognizeText()
                    }
                }

                imageSection

                if selectedImage != nil && !blocks.isEmpty {
                    selectionModeBar
                }

                if !selectedIDs.isEmpty {
                    detailCard
                } else if !blocks.isEmpty {
                    Text("点击图中标注框查看对应翻译")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if recognitionFailed {
                    ContentUnavailableView(
                        "没有识别到文字",
                        systemImage: "text.magnifyingglass",
                        description: Text("请靠近拍摄，保持文字清晰、光线充足")
                    )
                    .frame(height: 160)
                }

                if !blocks.isEmpty {
                    listSection
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("拍照翻译")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $selectedImage)
                .ignoresSafeArea()
        }
        .sheet(item: $dictionaryQuery) { query in
            if let url = query.url {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
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
        .onAppear {
            if selectedImage != nil && blocks.isEmpty && !isRecognizing {
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

    // MARK: - 图片区（可缩放）

    private var imageSection: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                GeometryReader { geo in
                    let scale = min(geo.size.width / max(image.size.width, 1), geo.size.height / max(image.size.height, 1))
                    let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: fitted.width, height: fitted.height)
                        .overlay {
                            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                                blockHighlight(block: block, index: index, in: fitted)
                            }
                        }
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .gesture(zoomGestures(container: geo.size, fitted: fitted))
                }
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    if zoomScale > 1.01 {
                        Button {
                            withAnimation(.spring(duration: 0.3)) { resetZoom() }
                        } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.caption)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(8)
                    } else {
                        Text("双指缩放 · 双击放大")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(8)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "viewfinder.rectangular")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)
                    Text("拍下菜单、路牌或商品标签\n自动识别并逐条翻译")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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

    private func zoomGestures(container: CGSize, fitted: CGSize) -> some Gesture {
        let magnify = MagnifyGesture()
            .onChanged { value in
                zoomScale = min(max(steadyZoom * value.magnification, 1), 4)
            }
            .onEnded { _ in
                steadyZoom = zoomScale
                if zoomScale <= 1.01 { withAnimation(.spring(duration: 0.25)) { resetZoom() } }
                clampPan(container: container, fitted: fitted)
            }

        let pan = DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard steadyZoom > 1 else { return }
                panOffset = CGSize(
                    width: steadyPan.width + value.translation.width,
                    height: steadyPan.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard steadyZoom > 1 else { return }
                clampPan(container: container, fitted: fitted)
                steadyPan = panOffset
            }

        let doubleTap = TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring(duration: 0.3)) {
                    if zoomScale > 1.01 {
                        resetZoom()
                    } else {
                        zoomScale = 2.5
                        steadyZoom = 2.5
                    }
                }
            }

        return doubleTap.simultaneously(with: magnify).simultaneously(with: pan)
    }

    private func resetZoom() {
        zoomScale = 1
        steadyZoom = 1
        panOffset = .zero
        steadyPan = .zero
    }

    private func clampPan(container: CGSize, fitted: CGSize) {
        let maxX = max((fitted.width * zoomScale - container.width) / 2, 0) + 40
        let maxY = max((fitted.height * zoomScale - container.height) / 2, 0) + 40
        withAnimation(.spring(duration: 0.25)) {
            panOffset.width = min(max(panOffset.width, -maxX), maxX)
            panOffset.height = min(max(panOffset.height, -maxY), maxY)
        }
    }

    private func blockHighlight(block: RecognizedBlock, index: Int, in size: CGSize) -> some View {
        let rect = CGRect(
            x: block.box.minX * size.width,
            y: block.box.minY * size.height,
            width: block.box.width * size.width,
            height: block.box.height * size.height
        )
        let isSelected = selectedIDs.contains(block.id)

        return RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color.yellow.opacity(0.35) : Color.accentColor.opacity(0.18))
            .stroke(isSelected ? Color.yellow : Color.accentColor, lineWidth: isSelected ? 2 : 1.2)
            .overlay(alignment: .topLeading) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(isSelected ? Color.yellow : Color.accentColor, in: Circle())
                    .offset(x: -6, y: -6)
            }
            .frame(width: max(rect.width, 12), height: max(rect.height, 12))
            .position(x: rect.midX, y: rect.midY)
            .contentShape(Rectangle().inset(by: -8))
            .onTapGesture {
                withAnimation(.spring(duration: 0.25)) {
                    tapBlock(block)
                }
            }
    }

    private func tapBlock(_ block: RecognizedBlock) {
        clearMerged()
        if isMultiSelect {
            if let existing = selectedIDs.firstIndex(of: block.id) {
                selectedIDs.remove(at: existing)
            } else {
                selectedIDs.append(block.id)
            }
        } else {
            selectedIDs = selectedIDs == [block.id] ? [] : [block.id]
        }
    }

    // MARK: - 多选模式栏

    private var selectionModeBar: some View {
        HStack {
            Toggle(isOn: $isMultiSelect.animation()) {
                Label("多选合并", systemImage: "square.on.square.dashed")
                    .font(.subheadline)
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .onChange(of: isMultiSelect) {
                clearSelection()
            }

            Text(isMultiSelect ? "点选多个框，合并成一段翻译更准确" : "")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if !selectedIDs.isEmpty {
                Button("清除") {
                    withAnimation { clearSelection() }
                }
                .font(.caption)
            }
        }
    }

    // MARK: - 详情卡片

    @ViewBuilder
    private var detailCard: some View {
        if selectedIDs.count == 1, let block = selectedBlocks.first,
           let index = blocks.firstIndex(where: { $0.id == block.id }) {
            singleDetailCard(block: block, index: index)
        } else if selectedIDs.count >= 2 {
            mergedDetailCard
        }
    }

    private func singleDetailCard(block: RecognizedBlock, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    step(from: index, by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 28)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .opacity(index == 0 ? 0.35 : 1)

                Spacer()

                Text("第 \(index + 1) / \(blocks.count) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    step(from: index, by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 28)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(index == blocks.count - 1)
                .opacity(index == blocks.count - 1 ? 0.35 : 1)
            }

            HStack(alignment: .top) {
                Text(block.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Spacer()
                speakButton(text: block.text, language: sourceSpeakLanguage)
            }

            Divider()

            if block.translation.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("翻译中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(alignment: .top) {
                    Text(block.translation)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)
                    Spacer()
                    speakButton(text: block.translation, language: targetSpeakLanguage)
                }
            }

            HStack {
                Button {
                    dictionaryQuery = DictionaryQuery(term: koreanText(of: block))
                } label: {
                    Label("词典·多义参考", systemImage: "character.book.closed")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(koreanText(of: block).isEmpty)

                Spacer()

                Button {
                    saveFavorite(korean: koreanText(of: block), chinese: chineseText(of: block))
                } label: {
                    Label(
                        isFavorited(korean: koreanText(of: block), chinese: chineseText(of: block)) ? "已收藏" : "收藏",
                        systemImage: isFavorited(korean: koreanText(of: block), chinese: chineseText(of: block)) ? "star.fill" : "star"
                    )
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(block.translation.isEmpty)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.yellow.opacity(0.6), lineWidth: 1.5)
        )
    }

    private var mergedDetailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("已选 \(selectedIDs.count) 条", systemImage: "square.on.square.dashed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    translateMergedSelection()
                } label: {
                    if isTranslatingMerged {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("合并翻译", systemImage: "arrow.triangle.merge")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isTranslatingMerged)
            }

            HStack(alignment: .top) {
                Text(selectedBlocks.map(\.text).joined(separator: " "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Spacer()
                speakButton(text: selectedBlocks.map(\.text).joined(separator: ", "), language: sourceSpeakLanguage)
            }

            if !mergedTranslation.isEmpty {
                Divider()
                HStack(alignment: .top) {
                    Text(mergedTranslation)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)
                    Spacer()
                    speakButton(text: mergedTranslation, language: targetSpeakLanguage)
                }

                HStack {
                    Text("合并后按整段上下文翻译，通常更准确")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button {
                        let korean = isKoreanToChinese ? mergedSource : mergedTranslation
                        let chinese = isKoreanToChinese ? mergedTranslation : mergedSource
                        saveFavorite(korean: korean, chinese: chinese)
                    } label: {
                        Label("收藏", systemImage: "star")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else if !isTranslatingMerged {
                Text("继续点选图中其他框，然后点「合并翻译」")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.yellow.opacity(0.6), lineWidth: 1.5)
        )
    }

    private func step(from index: Int, by delta: Int) {
        let next = index + delta
        guard blocks.indices.contains(next) else { return }
        withAnimation(.spring(duration: 0.25)) {
            selectedIDs = [blocks[next].id]
        }
    }

    private func speakButton(text: String, language: String) -> some View {
        Button {
            speechService.toggleSpeak(text, language: language)
        } label: {
            Image(systemName: speechService.isSpeaking(text) ? "stop.fill" : "speaker.wave.2.fill")
                .font(.subheadline)
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 对照列表（默认折叠）

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    withAnimation { isListExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isListExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                        Text("全部对照（\(blocks.count) 条）")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if isTranslating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        UIPasteboard.general.string = blocks
                            .map { "\($0.text)  →  \($0.translation)" }
                            .joined(separator: "\n")
                    } label: {
                        Label("复制全部", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                }
            }

            if isListExpanded {
                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    BlockComparisonRow(
                        block: block,
                        index: index,
                        isSelected: selectedIDs.contains(block.id),
                        sourceSpeakLanguage: sourceSpeakLanguage,
                        targetSpeakLanguage: targetSpeakLanguage,
                        speechService: speechService,
                        isFavorited: isFavorited(korean: koreanText(of: block), chinese: chineseText(of: block)),
                        onFavorite: { saveFavorite(korean: koreanText(of: block), chinese: chineseText(of: block)) },
                        onTap: {
                            withAnimation(.spring(duration: 0.25)) {
                                tapBlock(block)
                            }
                        }
                    )
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 收藏

    private func koreanText(of block: RecognizedBlock) -> String {
        isKoreanToChinese ? block.text : block.translation
    }

    private func chineseText(of block: RecognizedBlock) -> String {
        isKoreanToChinese ? block.translation : block.text
    }

    private func isFavorited(korean: String, chinese: String) -> Bool {
        guard !korean.isEmpty, !chinese.isEmpty else { return false }
        return favoritesStore.contains(korean: korean, chinese: chinese)
    }

    private func saveFavorite(korean: String, chinese: String) {
        guard !korean.isEmpty, !chinese.isEmpty else { return }
        favoritesStore.add(korean: korean, chinese: chinese)
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSavedToast = false }
        }
    }

    private func clearSelection() {
        selectedIDs = []
        clearMerged()
    }

    private func clearMerged() {
        mergedSource = ""
        mergedTranslation = ""
        isTranslatingMerged = false
        pendingMergedSource = nil
    }

    // MARK: - OCR

    private func recognizeText() {
        guard let image = selectedImage, let cgImage = image.cgImage else { return }
        isRecognizing = true
        recognitionFailed = false
        blocks = []
        clearSelection()
        isListExpanded = false
        resetZoom()

        let languages: [String] = isKoreanToChinese
            ? ["ko-KR", "zh-Hans"]
            : ["zh-Hans", "ko-KR"]
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        Task.detached(priority: .userInitiated) { [languages] in
            let result = Self.performOCR(cgImage: cgImage, orientation: orientation, languages: languages)
            await MainActor.run {
                blocks = result
                isRecognizing = false
                recognitionFailed = result.isEmpty
                if !result.isEmpty {
                    translateBlocks()
                }
            }
        }
    }

    private nonisolated static func performOCR(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        languages: [String]
    ) -> [RecognizedBlock] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try? handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first,
                  !candidate.string.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let box = observation.boundingBox
            // Vision 使用左下原点，转换为左上原点
            let converted = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
            return RecognizedBlock(text: candidate.string, box: converted)
        }
    }

    // MARK: - 翻译

    private func translateBlocks() {
        guard !blocks.isEmpty else { return }
        isTranslating = true
        triggerTranslationTask()
    }

    private func translateMergedSelection() {
        let selected = selectedBlocks
        guard selected.count >= 2 else { return }
        mergedSource = selected.map(\.text).joined(separator: "\n")
        pendingMergedSource = mergedSource
        mergedTranslation = ""
        isTranslatingMerged = true
        triggerTranslationTask()
    }

    private func triggerTranslationTask() {
        if configuration == nil {
            configuration = .init(source: sourceLanguage, target: targetLanguage)
        } else {
            configuration?.source = sourceLanguage
            configuration?.target = targetLanguage
            configuration?.invalidate()
        }
    }

    private func performTranslation(session: TranslationSession) async {
        for index in blocks.indices where blocks[index].translation.isEmpty {
            do {
                let response = try await session.translate(blocks[index].text)
                blocks[index].translation = response.targetText
            } catch {
                blocks[index].translation = "翻译失败"
            }
        }
        isTranslating = false

        if let source = pendingMergedSource {
            pendingMergedSource = nil
            do {
                let response = try await session.translate(source)
                mergedTranslation = response.targetText.replacingOccurrences(of: "\n", with: " ")
            } catch {
                mergedTranslation = "翻译失败：\(error.localizedDescription)"
            }
            isTranslatingMerged = false
        }
    }
}

// MARK: - 对照行

struct BlockComparisonRow: View {
    let block: RecognizedBlock
    let index: Int
    let isSelected: Bool
    let sourceSpeakLanguage: String
    let targetSpeakLanguage: String
    let speechService: SpeechService
    let isFavorited: Bool
    let onFavorite: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(isSelected ? Color.yellow : Color.accentColor, in: Circle())
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(block.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Spacer()
                    speakButton(text: block.text, language: sourceSpeakLanguage)
                }

                if block.translation.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    HStack {
                        Text(block.translation)
                            .font(.body)
                            .fontWeight(.medium)
                            .textSelection(.enabled)
                        Spacer()
                        speakButton(text: block.translation, language: targetSpeakLanguage)

                        Button(action: onFavorite) {
                            Image(systemName: isFavorited ? "star.fill" : "star")
                                .font(.subheadline)
                                .foregroundStyle(isFavorited ? .yellow : .blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(
            isSelected ? Color.yellow.opacity(0.12) : Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.yellow : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func speakButton(text: String, language: String) -> some View {
        Button {
            speechService.toggleSpeak(text, language: language)
        } label: {
            Image(systemName: speechService.isSpeaking(text) ? "stop.fill" : "speaker.wave.2.fill")
                .font(.subheadline)
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Safari

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
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

// MARK: - 方向转换

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
