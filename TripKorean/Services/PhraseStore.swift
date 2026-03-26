import Foundation

@Observable
class PhraseStore {
    var categories: [PhraseCategory] = []
    var dialogues: [Dialogue] = []

    init() {
        loadPhrases()
    }

    private func loadPhrases() {
        guard let url = Bundle.main.url(forResource: "phrases", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let phraseData = try? JSONDecoder().decode(PhraseData.self, from: data)
        else {
            return
        }
        categories = phraseData.categories
        dialogues = phraseData.dialogues
    }
}
