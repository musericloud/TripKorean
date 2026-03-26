import SwiftUI

struct FavoritesView: View {
    let favoritesStore: FavoritesStore
    let speechService: SpeechService

    var body: some View {
        NavigationStack {
            Group {
                if favoritesStore.favorites.isEmpty {
                    ContentUnavailableView(
                        "还没有收藏",
                        systemImage: "star.slash",
                        description: Text("在翻译页面点击收藏按钮保存常用韩语")
                    )
                } else {
                    List {
                        ForEach(favoritesStore.favorites) { favorite in
                            FavoriteRow(favorite: favorite, speechService: speechService)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                favoritesStore.remove(favoritesStore.favorites[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("收藏")
            .toolbar {
                if !favoritesStore.favorites.isEmpty {
                    EditButton()
                }
            }
        }
    }
}

struct FavoriteRow: View {
    let favorite: Favorite
    let speechService: SpeechService
    @AppStorage("showPronunciation") private var showPronunciation = true
    @State private var isExpanded = false

    private static let favoriteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(favorite.korean)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(favorite.chinese)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    speechService.toggleSpeak(favorite.korean)
                } label: {
                    Image(systemName: speechService.isSpeaking(favorite.korean) ? "stop.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if showPronunciation {
                        Label(favorite.pronunciation, systemImage: "character.phonetic")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    Text(formatDate(favorite.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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

    private func formatDate(_ date: Date) -> String {
        "收藏于 \(Self.favoriteDateFormatter.string(from: date))"
    }
}
