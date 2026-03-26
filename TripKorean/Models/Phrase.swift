import Foundation

struct Phrase: Identifiable, Codable {
    let id: String
    let korean: String
    let pronunciation: String
    let chinese: String
    let english: String
    let note: String?
}

struct PhraseCategory: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let phrases: [Phrase]
}

struct DialogueLine: Identifiable, Codable {
    let id: String
    let speaker: String
    let korean: String
    let pronunciation: String
    let chinese: String
}

struct Dialogue: Identifiable, Codable {
    let id: String
    let title: String
    let icon: String
    let scene: String
    let lines: [DialogueLine]
}

struct PhraseData: Codable {
    let categories: [PhraseCategory]
    let dialogues: [Dialogue]
}
