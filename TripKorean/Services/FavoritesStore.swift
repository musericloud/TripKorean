import Foundation
import UIKit

@MainActor
@Observable
final class FavoritesStore {
    var favorites: [Favorite] = []

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("favorites.json")
    }()

    private var saveDebounceTask: Task<Void, Never>?
    /// Observed from `deinit` (nonisolated); unregister must not touch other actor state.
    nonisolated(unsafe) private var resignObserver: NSObjectProtocol?

    init() {
        load()
        resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.flushPendingSave()
            }
        }
    }

    deinit {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
    }

    func add(korean: String, chinese: String) {
        guard !favorites.contains(where: { $0.korean == korean && $0.chinese == chinese }) else {
            return
        }
        let favorite = Favorite(korean: korean, chinese: chinese)
        favorites.insert(favorite, at: 0)
        scheduleSave()
    }

    func remove(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        scheduleSave()
    }

    func contains(korean: String, chinese: String) -> Bool {
        favorites.contains { $0.korean == korean && $0.chinese == chinese }
    }

    private func scheduleSave() {
        saveDebounceTask?.cancel()
        saveDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            performSave()
        }
    }

    private func flushPendingSave() {
        saveDebounceTask?.cancel()
        saveDebounceTask = nil
        performSave()
    }

    private func performSave() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Favorite].self, from: data)
        else { return }
        favorites = decoded
    }
}
