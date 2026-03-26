import SwiftUI

struct PhrasesView: View {
    let store: PhraseStore
    let speechService: SpeechService

    var body: some View {
        NavigationStack {
            List(store.categories) { category in
                NavigationLink {
                    PhraseListView(
                        category: category,
                        speechService: speechService
                    )
                } label: {
                    Label(category.name, systemImage: category.icon)
                        .font(.body)
                }
            }
            .navigationTitle("旅行短语")
        }
    }
}

struct PhraseListView: View {
    let category: PhraseCategory
    let speechService: SpeechService

    var body: some View {
        List(category.phrases) { phrase in
            PhraseRow(phrase: phrase, speechService: speechService)
        }
        .navigationTitle(category.name)
    }
}

struct PhraseRow: View {
    let phrase: Phrase
    let speechService: SpeechService
    @AppStorage("showPronunciation") private var showPronunciation = true
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phrase.korean)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(phrase.chinese)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    speechService.toggleSpeak(phrase.korean)
                } label: {
                    Image(systemName: speechService.isSpeaking(phrase.korean) ? "stop.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if showPronunciation {
                        Label(phrase.pronunciation, systemImage: "character.phonetic")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    Text(phrase.english)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let note = phrase.note {
                        Label(note, systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .padding(.top, 2)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}
