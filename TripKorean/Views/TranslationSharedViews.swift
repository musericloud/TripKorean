import SwiftUI

// MARK: - Direction

struct TranslationDirectionToggle: View {
    @Binding var isKoreanToChinese: Bool
    var onSwap: () -> Void

    var body: some View {
        HStack {
            Text(isKoreanToChinese ? "韩语" : "中文")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)

            Button {
                withAnimation {
                    isKoreanToChinese.toggle()
                    onSwap()
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.title)
            }

            Text(isKoreanToChinese ? "中文" : "韩语")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Translation result

struct TranslationResultPanel: View {
    let title: String
    let translatedText: String
    /// When non-nil and `translatedText` is empty, shows this placeholder instead of the result card.
    var emptyPlaceholder: String?
    let resultSpeakLanguage: String
    let speechService: SpeechService
    var isFavorited: Bool = false
    var showFavorite: Bool = true
    var onFavorite: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if translatedText.isEmpty {
                if let emptyPlaceholder {
                    Text(emptyPlaceholder)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Text(translatedText)
                    .font(.title3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                TranslationResultActionsRow(
                    text: translatedText,
                    speakLanguage: resultSpeakLanguage,
                    speechService: speechService,
                    showFavorite: showFavorite,
                    isFavorited: isFavorited,
                    onFavorite: onFavorite
                )
            }
        }
    }
}

struct TranslationResultActionsRow: View {
    let text: String
    let speakLanguage: String
    let speechService: SpeechService
    var showFavorite: Bool = true
    var isFavorited: Bool = false
    var onFavorite: () -> Void = {}

    var body: some View {
        HStack {
            Button {
                speechService.toggleSpeak(text, language: speakLanguage)
            } label: {
                Label(
                    speechService.isSpeaking(text) ? "停止" : "朗读",
                    systemImage: speechService.isSpeaking(text) ? "stop.fill" : "speaker.wave.2.fill"
                )
            }

            Spacer()

            Button {
                UIPasteboard.general.string = text
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }

            if showFavorite {
                Spacer()

                Button {
                    onFavorite()
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

struct RecognizedTextActionsRow: View {
    let text: String
    let speakLanguage: String
    let speechService: SpeechService
    @Binding var isTranslating: Bool
    var onTranslate: () -> Void

    var body: some View {
        HStack {
            Button {
                speechService.toggleSpeak(text, language: speakLanguage)
            } label: {
                Label(
                    speechService.isSpeaking(text) ? "停止" : "朗读",
                    systemImage: speechService.isSpeaking(text) ? "stop.fill" : "speaker.wave.2.fill"
                )
            }

            Spacer()

            Button {
                UIPasteboard.general.string = text
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }

            Spacer()

            Button {
                onTranslate()
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
            .disabled(isTranslating)
        }
    }
}
