import SwiftUI

struct PhrasesView: View {
    let store: PhraseStore
    let speechService: SpeechService
    @State private var searchText = ""

    private static let palette: [Color] = [
        .blue, .orange, .green, .purple, .pink, .teal, .red, .indigo, .brown, .cyan, .mint, .yellow,
    ]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var searchResults: [(category: PhraseCategory, phrase: Phrase)] {
        guard !searchText.isEmpty else { return [] }
        return store.categories.flatMap { category in
            category.phrases
                .filter {
                    $0.korean.localizedCaseInsensitiveContains(searchText)
                        || $0.chinese.localizedCaseInsensitiveContains(searchText)
                        || $0.pronunciation.localizedCaseInsensitiveContains(searchText)
                }
                .map { (category, $0) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    categoryGrid
                } else {
                    searchResultList
                }
            }
            .navigationTitle("旅行短语")
            .searchable(text: $searchText, prompt: "搜索中文、韩语或罗马音")
        }
    }

    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(store.categories.enumerated()), id: \.element.id) { index, category in
                    NavigationLink {
                        PhraseListView(
                            category: category,
                            speechService: speechService
                        )
                    } label: {
                        CategoryCard(
                            category: category,
                            color: Self.palette[index % Self.palette.count]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var searchResultList: some View {
        List {
            if searchResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(searchResults, id: \.phrase.id) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        PhraseRow(phrase: result.phrase, speechService: speechService)
                        Text(result.category.name)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

struct CategoryCard: View {
    let category: PhraseCategory
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 11))
                Spacer()
                Text("\(category.phrases.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            Text(category.name)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
