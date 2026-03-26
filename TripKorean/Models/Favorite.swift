import Foundation

struct Favorite: Identifiable, Codable, Equatable {
    let id: UUID
    let korean: String
    let chinese: String
    let pronunciation: String
    let createdAt: Date

    init(korean: String, chinese: String, pronunciation: String? = nil) {
        self.id = UUID()
        self.korean = korean
        self.chinese = chinese
        self.pronunciation = pronunciation ?? KoreanRomanizer.romanize(korean)
        self.createdAt = Date()
    }
}
