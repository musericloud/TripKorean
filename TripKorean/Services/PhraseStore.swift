import Foundation

@MainActor
@Observable
final class PhraseStore {
    var categories: [PhraseCategory] = []
    var dialogues: [Dialogue] = []

    init() {
        Task {
            guard let url = Bundle.main.url(forResource: "phrases", withExtension: "json") else { return }
            let decoded: PhraseData? = await Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: url),
                      let phraseData = try? JSONDecoder().decode(PhraseData.self, from: data) else { return nil }
                return phraseData
            }.value
            if let decoded {
                categories = decoded.categories
                dialogues = decoded.dialogues
            }
        }
    }
}
