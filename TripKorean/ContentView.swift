import SwiftUI

struct ContentView: View {
    @State private var store = PhraseStore()
    @State private var speechService = SpeechService()
    @State private var favoritesStore = FavoritesStore()

    var body: some View {
        TabView {
            Tab("发音", systemImage: "waveform") {
                HangulHomeView(speechService: speechService)
            }

            Tab("短语", systemImage: "text.book.closed.fill") {
                PhrasesView(store: store, speechService: speechService)
            }

            Tab("对话", systemImage: "bubble.left.and.bubble.right.fill") {
                DialogueListView(
                    store: store,
                    speechService: speechService,
                    favoritesStore: favoritesStore
                )
            }

            Tab("翻译", systemImage: "character.book.closed.fill") {
                TranslateView(speechService: speechService, favoritesStore: favoritesStore)
            }

            Tab("收藏", systemImage: "star.fill") {
                FavoritesView(favoritesStore: favoritesStore, speechService: speechService)
            }
        }
    }
}
