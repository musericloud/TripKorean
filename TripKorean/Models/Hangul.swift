import SwiftUI

struct HangulLetter: Identifiable, Hashable {
    let id: String
    /// 字母本身，如 "ㅏ"
    let symbol: String
    /// 字母名称（辅音才有，如 "기역"）
    let name: String?
    /// 罗马音，如 "a"
    let roman: String
    /// 中文发音要领
    let hint: String
    /// 交给 TTS 朗读的音节，如 "아"、"가"
    let soundText: String
    /// 例词
    let exampleWord: String
    let exampleRoman: String
    let exampleMeaning: String
}

struct HangulGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let colorName: String
    let intro: String
    let letters: [HangulLetter]

    var color: Color {
        switch colorName {
        case "blue": .blue
        case "orange": .orange
        case "green": .green
        case "purple": .purple
        case "pink": .pink
        case "teal": .teal
        default: .blue
        }
    }
}

enum HangulData {
    static let groups: [HangulGroup] = [basicVowels, compoundVowels, basicConsonants, doubleConsonants, batchim]

    // MARK: - 基本元音

    static let basicVowels = HangulGroup(
        id: "basic-vowels",
        title: "基本元音",
        subtitle: "10 个",
        icon: "circle.grid.2x2.fill",
        colorName: "blue",
        intro: "韩语的 10 个基本元音由「天(·)、地(ㅡ)、人(ㅣ)」三个要素组合而成。元音不能单独成字，书写时需要加上不发音的辅音 ㅇ，例如 ㅏ 写作 아。",
        letters: [
            HangulLetter(id: "v-a", symbol: "ㅏ", name: nil, roman: "a", hint: "类似汉语「啊」，嘴自然张开", soundText: "아", exampleWord: "아이", exampleRoman: "a-i", exampleMeaning: "孩子"),
            HangulLetter(id: "v-ya", symbol: "ㅑ", name: nil, roman: "ya", hint: "类似汉语「呀」", soundText: "야", exampleWord: "야구", exampleRoman: "ya-gu", exampleMeaning: "棒球"),
            HangulLetter(id: "v-eo", symbol: "ㅓ", name: nil, roman: "eo", hint: "嘴张大发「哦」，介于「哦」和「饿」之间", soundText: "어", exampleWord: "어머니", exampleRoman: "eo-meo-ni", exampleMeaning: "妈妈"),
            HangulLetter(id: "v-yeo", symbol: "ㅕ", name: nil, roman: "yeo", hint: "在 ㅓ 前加 y，类似快速连读「哟哦」", soundText: "여", exampleWord: "여행", exampleRoman: "yeo-haeng", exampleMeaning: "旅行"),
            HangulLetter(id: "v-o", symbol: "ㅗ", name: nil, roman: "o", hint: "类似汉语「欧」，嘴唇收圆前突", soundText: "오", exampleWord: "오이", exampleRoman: "o-i", exampleMeaning: "黄瓜"),
            HangulLetter(id: "v-yo", symbol: "ㅛ", name: nil, roman: "yo", hint: "类似汉语「哟」，嘴唇收圆", soundText: "요", exampleWord: "요리", exampleRoman: "yo-ri", exampleMeaning: "料理"),
            HangulLetter(id: "v-u", symbol: "ㅜ", name: nil, roman: "u", hint: "类似汉语「乌」，嘴唇用力收圆", soundText: "우", exampleWord: "우유", exampleRoman: "u-yu", exampleMeaning: "牛奶"),
            HangulLetter(id: "v-yu", symbol: "ㅠ", name: nil, roman: "yu", hint: "类似汉语「优」", soundText: "유", exampleWord: "우유", exampleRoman: "u-yu", exampleMeaning: "牛奶"),
            HangulLetter(id: "v-eu", symbol: "ㅡ", name: nil, roman: "eu", hint: "类似「呃」，嘴角向两边拉平，不圆唇", soundText: "으", exampleWord: "그림", exampleRoman: "geu-rim", exampleMeaning: "图画"),
            HangulLetter(id: "v-i", symbol: "ㅣ", name: nil, roman: "i", hint: "类似汉语「衣」", soundText: "이", exampleWord: "이름", exampleRoman: "i-reum", exampleMeaning: "名字"),
        ]
    )

    // MARK: - 复合元音

    static let compoundVowels = HangulGroup(
        id: "compound-vowels",
        title: "复合元音",
        subtitle: "11 个",
        icon: "circle.hexagongrid.fill",
        colorName: "teal",
        intro: "复合元音由基本元音组合而成。其中 ㅐ/ㅔ、ㅙ/ㅚ/ㅞ 在现代口语中读音几乎相同，不必刻意区分。",
        letters: [
            HangulLetter(id: "cv-ae", symbol: "ㅐ", name: nil, roman: "ae", hint: "类似汉语「哎」，嘴张得稍大", soundText: "애", exampleWord: "개", exampleRoman: "gae", exampleMeaning: "狗"),
            HangulLetter(id: "cv-yae", symbol: "ㅒ", name: nil, roman: "yae", hint: "在 ㅐ 前加 y，类似「耶」", soundText: "얘", exampleWord: "얘기", exampleRoman: "yae-gi", exampleMeaning: "聊天、故事"),
            HangulLetter(id: "cv-e", symbol: "ㅔ", name: nil, roman: "e", hint: "类似汉语「诶」，与 ㅐ 读音基本相同", soundText: "에", exampleWord: "네", exampleRoman: "ne", exampleMeaning: "是的"),
            HangulLetter(id: "cv-ye", symbol: "ㅖ", name: nil, roman: "ye", hint: "类似汉语「耶」", soundText: "예", exampleWord: "예약", exampleRoman: "ye-yak", exampleMeaning: "预约"),
            HangulLetter(id: "cv-wa", symbol: "ㅘ", name: nil, roman: "wa", hint: "ㅗ+ㅏ 快速连读，类似「哇」", soundText: "와", exampleWord: "과일", exampleRoman: "gwa-il", exampleMeaning: "水果"),
            HangulLetter(id: "cv-wae", symbol: "ㅙ", name: nil, roman: "wae", hint: "ㅗ+ㅐ 连读，类似「歪」的韵母", soundText: "왜", exampleWord: "왜", exampleRoman: "wae", exampleMeaning: "为什么"),
            HangulLetter(id: "cv-oe", symbol: "ㅚ", name: nil, roman: "oe", hint: "现代口语读作「喂 we」", soundText: "외", exampleWord: "회사", exampleRoman: "hoe-sa", exampleMeaning: "公司"),
            HangulLetter(id: "cv-wo", symbol: "ㅝ", name: nil, roman: "wo", hint: "ㅜ+ㅓ 连读，类似「我」", soundText: "워", exampleWord: "원", exampleRoman: "won", exampleMeaning: "韩元"),
            HangulLetter(id: "cv-we", symbol: "ㅞ", name: nil, roman: "we", hint: "ㅜ+ㅔ 连读，类似「喂」", soundText: "웨", exampleWord: "웨이터", exampleRoman: "we-i-teo", exampleMeaning: "服务员"),
            HangulLetter(id: "cv-wi", symbol: "ㅟ", name: nil, roman: "wi", hint: "ㅜ+ㅣ 连读，类似「为」", soundText: "위", exampleWord: "귀", exampleRoman: "gwi", exampleMeaning: "耳朵"),
            HangulLetter(id: "cv-ui", symbol: "ㅢ", name: nil, roman: "ui", hint: "「呃+衣」快速连读", soundText: "의", exampleWord: "의사", exampleRoman: "ui-sa", exampleMeaning: "医生"),
        ]
    )

    // MARK: - 基本辅音

    static let basicConsonants = HangulGroup(
        id: "basic-consonants",
        title: "基本辅音",
        subtitle: "14 个",
        icon: "square.grid.3x3.fill",
        colorName: "orange",
        intro: "14 个基本辅音相当于音节的声母。ㄱㄷㅂㅈ 在词首读得接近清音(k/t/p/ch)，在词中读浊音(g/d/b/j)。点击卡片可听「辅音+ㅏ」的读音。",
        letters: [
            HangulLetter(id: "c-g", symbol: "ㄱ", name: "기역 gi-yeok", roman: "g / k", hint: "类似「哥」的声母，词首更接近 k", soundText: "가", exampleWord: "가방", exampleRoman: "ga-bang", exampleMeaning: "包"),
            HangulLetter(id: "c-n", symbol: "ㄴ", name: "니은 ni-eun", roman: "n", hint: "类似「呢」的声母", soundText: "나", exampleWord: "나무", exampleRoman: "na-mu", exampleMeaning: "树"),
            HangulLetter(id: "c-d", symbol: "ㄷ", name: "디귿 di-geut", roman: "d / t", hint: "类似「的」的声母，词首更接近 t", soundText: "다", exampleWord: "다리", exampleRoman: "da-ri", exampleMeaning: "腿、桥"),
            HangulLetter(id: "c-r", symbol: "ㄹ", name: "리을 ri-eul", roman: "r / l", hint: "舌尖轻弹上颚，介于 r 和 l 之间", soundText: "라", exampleWord: "라면", exampleRoman: "ra-myeon", exampleMeaning: "拉面"),
            HangulLetter(id: "c-m", symbol: "ㅁ", name: "미음 mi-eum", roman: "m", hint: "类似「妈」的声母", soundText: "마", exampleWord: "머리", exampleRoman: "meo-ri", exampleMeaning: "头"),
            HangulLetter(id: "c-b", symbol: "ㅂ", name: "비읍 bi-eup", roman: "b / p", hint: "类似「爸」的声母，词首更接近 p", soundText: "바", exampleWord: "바다", exampleRoman: "ba-da", exampleMeaning: "大海"),
            HangulLetter(id: "c-s", symbol: "ㅅ", name: "시옷 si-ot", roman: "s", hint: "类似「斯」的声母，遇 ㅣ 读「西」", soundText: "사", exampleWord: "사과", exampleRoman: "sa-gwa", exampleMeaning: "苹果"),
            HangulLetter(id: "c-ng", symbol: "ㅇ", name: "이응 i-eung", roman: "- / ng", hint: "在音节开头不发音，作收音时读 ng", soundText: "아", exampleWord: "아이", exampleRoman: "a-i", exampleMeaning: "孩子"),
            HangulLetter(id: "c-j", symbol: "ㅈ", name: "지읒 ji-eut", roman: "j", hint: "类似「机」的声母，词中略带浊音", soundText: "자", exampleWord: "자다", exampleRoman: "ja-da", exampleMeaning: "睡觉"),
            HangulLetter(id: "c-ch", symbol: "ㅊ", name: "치읓 chi-eut", roman: "ch", hint: "ㅈ 的送气音，类似「疵」", soundText: "차", exampleWord: "차", exampleRoman: "cha", exampleMeaning: "车、茶"),
            HangulLetter(id: "c-k", symbol: "ㅋ", name: "키읔 ki-euk", roman: "k", hint: "ㄱ 的送气音，类似「棵」", soundText: "카", exampleWord: "커피", exampleRoman: "keo-pi", exampleMeaning: "咖啡"),
            HangulLetter(id: "c-t", symbol: "ㅌ", name: "티읕 ti-eut", roman: "t", hint: "ㄷ 的送气音，类似「特」", soundText: "타", exampleWord: "토요일", exampleRoman: "to-yo-il", exampleMeaning: "星期六"),
            HangulLetter(id: "c-p", symbol: "ㅍ", name: "피읖 pi-eup", roman: "p", hint: "ㅂ 的送气音，类似「泼」", soundText: "파", exampleWord: "포도", exampleRoman: "po-do", exampleMeaning: "葡萄"),
            HangulLetter(id: "c-h", symbol: "ㅎ", name: "히읗 hi-eut", roman: "h", hint: "类似「喝」的声母", soundText: "하", exampleWord: "하나", exampleRoman: "ha-na", exampleMeaning: "一（个）"),
        ]
    )

    // MARK: - 双辅音（紧音）

    static let doubleConsonants = HangulGroup(
        id: "double-consonants",
        title: "双辅音·紧音",
        subtitle: "5 个",
        icon: "square.grid.2x2.fill",
        colorName: "purple",
        intro: "5 个双辅音是「紧音」：发音时喉咙绷紧、完全不送气，声音又短又硬。可以把手掌放在嘴前，感觉不到气流即为正确。",
        letters: [
            HangulLetter(id: "dc-kk", symbol: "ㄲ", name: "쌍기역 ssang-gi-yeok", roman: "kk", hint: "比「嘎」更紧更硬，不送气", soundText: "까", exampleWord: "꼬리", exampleRoman: "kko-ri", exampleMeaning: "尾巴"),
            HangulLetter(id: "dc-tt", symbol: "ㄸ", name: "쌍디귿 ssang-di-geut", roman: "tt", hint: "比「嗒」更紧更硬，不送气", soundText: "따", exampleWord: "딸기", exampleRoman: "ttal-gi", exampleMeaning: "草莓"),
            HangulLetter(id: "dc-pp", symbol: "ㅃ", name: "쌍비읍 ssang-bi-eup", roman: "pp", hint: "比「爸」更紧更硬，不送气", soundText: "빠", exampleWord: "빵", exampleRoman: "ppang", exampleMeaning: "面包"),
            HangulLetter(id: "dc-ss", symbol: "ㅆ", name: "쌍시옷 ssang-si-ot", roman: "ss", hint: "比「嘶」更紧，气流强而集中", soundText: "싸", exampleWord: "싸다", exampleRoman: "ssa-da", exampleMeaning: "便宜"),
            HangulLetter(id: "dc-jj", symbol: "ㅉ", name: "쌍지읒 ssang-ji-eut", roman: "jj", hint: "比「渣」更紧更硬，不送气", soundText: "짜", exampleWord: "짜다", exampleRoman: "jja-da", exampleMeaning: "咸"),
        ]
    )

    // MARK: - 收音（받침）

    static let batchim = HangulGroup(
        id: "batchim",
        title: "收音·받침",
        subtitle: "7 种代表音",
        icon: "arrow.down.square.fill",
        colorName: "green",
        intro: "写在音节最下方的辅音叫「收音」(받침)。虽然很多辅音都能作收音，但实际只有 7 种代表读音，全部短促不爆破。",
        letters: [
            HangulLetter(id: "b-k", symbol: "ㄱ", name: "含 ㅋ ㄲ", roman: "-k", hint: "舌根抵住软腭堵住气流，短促不爆破", soundText: "악", exampleWord: "책", exampleRoman: "chaek", exampleMeaning: "书"),
            HangulLetter(id: "b-n", symbol: "ㄴ", name: nil, roman: "-n", hint: "舌尖抵上齿龈，类似「安」的尾音", soundText: "안", exampleWord: "눈", exampleRoman: "nun", exampleMeaning: "眼睛、雪"),
            HangulLetter(id: "b-t", symbol: "ㄷ", name: "含 ㅅ ㅆ ㅈ ㅊ ㅌ ㅎ", roman: "-t", hint: "舌尖抵住齿龈堵住气流，不爆破", soundText: "앋", exampleWord: "옷", exampleRoman: "ot", exampleMeaning: "衣服"),
            HangulLetter(id: "b-l", symbol: "ㄹ", name: nil, roman: "-l", hint: "舌尖卷起抵住上颚，类似英语的 l", soundText: "알", exampleWord: "물", exampleRoman: "mul", exampleMeaning: "水"),
            HangulLetter(id: "b-m", symbol: "ㅁ", name: nil, roman: "-m", hint: "双唇闭合，类似闭口的「暗」", soundText: "암", exampleWord: "몸", exampleRoman: "mom", exampleMeaning: "身体"),
            HangulLetter(id: "b-p", symbol: "ㅂ", name: "含 ㅍ", roman: "-p", hint: "双唇闭合堵住气流，不爆破", soundText: "압", exampleWord: "밥", exampleRoman: "bap", exampleMeaning: "米饭"),
            HangulLetter(id: "b-ng", symbol: "ㅇ", name: nil, roman: "-ng", hint: "类似「昂」的鼻音，气流从鼻腔出", soundText: "앙", exampleWord: "가방", exampleRoman: "ga-bang", exampleMeaning: "包"),
        ]
    )

    // MARK: - 音节拼读表

    /// 拼读表行：14 个基本辅音（Unicode 声母索引）
    static let chartInitials: [(symbol: String, index: Int, roman: String)] = [
        ("ㄱ", 0, "g"), ("ㄴ", 2, "n"), ("ㄷ", 3, "d"), ("ㄹ", 5, "r"),
        ("ㅁ", 6, "m"), ("ㅂ", 7, "b"), ("ㅅ", 9, "s"), ("ㅇ", 11, ""),
        ("ㅈ", 12, "j"), ("ㅊ", 14, "ch"), ("ㅋ", 15, "k"), ("ㅌ", 16, "t"),
        ("ㅍ", 17, "p"), ("ㅎ", 18, "h"),
    ]

    /// 拼读表列：10 个基本元音（Unicode 韵母索引）
    static let chartMedials: [(symbol: String, index: Int, roman: String)] = [
        ("ㅏ", 0, "a"), ("ㅑ", 2, "ya"), ("ㅓ", 4, "eo"), ("ㅕ", 6, "yeo"),
        ("ㅗ", 8, "o"), ("ㅛ", 12, "yo"), ("ㅜ", 13, "u"), ("ㅠ", 17, "yu"),
        ("ㅡ", 18, "eu"), ("ㅣ", 20, "i"),
    ]

    /// 由声母/韵母索引合成一个韩文音节
    static func syllable(initial: Int, medial: Int) -> String {
        guard let scalar = UnicodeScalar(0xAC00 + (initial * 21 + medial) * 28) else { return "" }
        return String(Character(scalar))
    }
}
