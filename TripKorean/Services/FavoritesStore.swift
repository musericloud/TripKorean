import Foundation

@Observable
class FavoritesStore {
    var favorites: [Favorite] = []

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("favorites.json")
    }()

    init() {
        load()
    }

    func add(korean: String, chinese: String) {
        guard !favorites.contains(where: { $0.korean == korean && $0.chinese == chinese }) else {
            return
        }
        let favorite = Favorite(korean: korean, chinese: chinese)
        favorites.insert(favorite, at: 0)
        save()
    }

    func remove(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        save()
    }

    func contains(korean: String, chinese: String) -> Bool {
        favorites.contains { $0.korean == korean && $0.chinese == chinese }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        try? data.write(to: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Favorite].self, from: data)
        else { return }
        favorites = decoded
    }
}
