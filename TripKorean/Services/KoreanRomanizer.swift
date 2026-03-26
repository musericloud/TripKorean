import Foundation

enum KoreanRomanizer {
    private static let initials = [
        "g", "kk", "n", "d", "tt", "r", "m", "b", "pp",
        "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h"
    ]

    private static let medials = [
        "a", "ae", "ya", "yae", "eo", "e", "yeo", "ye",
        "o", "wa", "wae", "oe", "yo", "u", "wo", "we",
        "wi", "yu", "eu", "ui", "i"
    ]

    private static let finals = [
        "", "k", "k", "k", "n", "n", "n", "t", "l",
        "l", "l", "l", "l", "l", "l", "l", "m", "p",
        "p", "t", "t", "ng", "t", "t", "k", "t", "p", "t"
    ]

    static func romanize(_ text: String) -> String {
        var result: [String] = []
        var currentSyllable: [String] = []

        for char in text {
            guard let scalar = char.unicodeScalars.first else {
                flushSyllable(&currentSyllable, into: &result)
                result.append(String(char))
                continue
            }

            let code = scalar.value

            guard code >= 0xAC00, code <= 0xD7A3 else {
                flushSyllable(&currentSyllable, into: &result)
                result.append(String(char))
                continue
            }

            let syllableIndex = Int(code - 0xAC00)
            let initialIndex = syllableIndex / (21 * 28)
            let medialIndex = (syllableIndex % (21 * 28)) / 28
            let finalIndex = syllableIndex % 28

            flushSyllable(&currentSyllable, into: &result)

            let initial = initials[initialIndex]
            let medial = medials[medialIndex]
            let final_ = finals[finalIndex]

            currentSyllable = [initial, medial, final_]
        }

        flushSyllable(&currentSyllable, into: &result)
        return result.joined()
    }

    private static func flushSyllable(_ syllable: inout [String], into result: inout [String]) {
        guard !syllable.isEmpty else { return }

        if !result.isEmpty {
            let last = result.last ?? ""
            if last.last?.isLetter == true && syllable[0].first?.isLetter == true {
                result.append("-")
            }
        }

        result.append(contentsOf: syllable)
        syllable = []
    }
}
