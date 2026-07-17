import Foundation
import CoreGraphics
@preconcurrency import Vision

// MARK: - 解析结果

struct ParsedReceipt {
    var store = ""
    var storeChinese = ""
    var date: Date?
    var currency = "KRW"
    var total: Decimal?
    var tax: Decimal?
    var paymentMethod = ""
    var category: ReceiptCategory = .other
    var items: [ReceiptItem] = []
    var refundStatus: RefundStatus = .notApplicable
    var refundAmount: Decimal?
    var remainingRefundLimit: Decimal?
    var rawText = ""
}

/// 解析器协议：本地规则实现打底，后续可接 LLM 实现
protocol ReceiptParsing {
    func parse(lines: [String]) async throws -> ParsedReceipt
}

// MARK: - OCR

enum ReceiptOCR {
    /// 识别小票文字，按行坐标聚类合并（小票是分栏排版：品名在左、金额在右，
    /// Vision 会拆成独立块，需要按 Y 带合并成完整行），返回从上到下的行
    nonisolated static func recognizeLines(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "zh-Hans", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try? handler.perform([request])

        struct Fragment {
            let text: String
            let box: CGRect
            var midY: CGFloat { box.midY }
        }

        let fragments = (request.results ?? []).compactMap { obs -> Fragment? in
            guard let text = obs.topCandidates(1).first?.string,
                  !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return Fragment(text: text, box: obs.boundingBox)
        }
        .sorted { $0.midY > $1.midY }  // Vision 原点在左下，先按 Y 从上到下

        var rows: [[Fragment]] = []
        for fragment in fragments {
            let tolerance = max(fragment.box.height * 0.6, 0.004)
            if var last = rows.last, let anchor = last.first,
               abs(anchor.midY - fragment.midY) < max(tolerance, anchor.box.height * 0.6) {
                last.append(fragment)
                rows[rows.count - 1] = last
            } else {
                rows.append([fragment])
            }
        }

        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }
                .map(\.text)
                .joined(separator: " ")
        }
    }
}

// MARK: - 本地规则解析器

struct LocalReceiptParser: ReceiptParsing {

    func parse(lines: [String]) async throws -> ParsedReceipt {
        Self.parse(lines: lines)
    }

    // MARK: 主流程

    nonisolated static func parse(lines: [String]) -> ParsedReceipt {
        var result = ParsedReceipt()
        result.rawText = lines.joined(separator: "\n")
        let normalized = lines.map { normalize($0) }
        let fullNormalized = normalized.joined(separator: "\n")

        result.date = detectDate(lines: lines)
        result.category = detectCategory(fullNormalized: fullNormalized)
        (result.store, result.storeChinese) = detectStore(lines: lines, normalized: normalized, fullNormalized: fullNormalized)
        (result.total, result.currency) = detectTotal(lines: lines, normalized: normalized, category: result.category)
        result.tax = amountOnLines(keyword: "부가세", lines: lines, normalized: normalized)
            ?? amountOnLines(keyword: "V.A.T", lines: lines, normalized: normalized)
        result.paymentMethod = detectPayment(fullNormalized: fullNormalized)
        result.items = detectItems(lines: lines, normalized: normalized)

        let refund = detectRefund(
            fullNormalized: fullNormalized,
            lines: lines,
            normalized: normalized,
            category: result.category,
            total: result.total,
            currency: result.currency
        )
        result.refundStatus = refund.status
        result.refundAmount = refund.amount
        result.remainingRefundLimit = refund.remainingLimit

        return result
    }

    // MARK: 工具

    /// 去空格，便于匹配被 OCR 拆开的关键词（如 "결 제 금 액"）
    nonisolated private static func normalize(_ line: String) -> String {
        line.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\t", with: "")
    }

    /// 提取一行里的所有金额（要求千分位逗号格式或带原/₩/$，避免误抓电话号、单号）
    nonisolated static func amounts(in line: String, allowPlain: Bool = false) -> [Decimal] {
        let pattern = allowPlain
            ? #"-?[0-9]{1,3}(?:,[0-9]{3})+|-?[0-9]+(?=원)|(?<=[₩$])-?[0-9,]+|-?[0-9]{2,9}"#
            : #"-?[0-9]{1,3}(?:,[0-9]{3})+|-?[0-9]+(?=원)|(?<=[₩$])-?[0-9,]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = line as NSString
        return regex.matches(in: line, range: NSRange(location: 0, length: ns.length)).compactMap {
            Decimal(string: ns.substring(with: $0.range).replacingOccurrences(of: ",", with: ""))
        }
    }

    /// 干扰行：额度/汇率/卡号等，金额提取时全局排除
    nonisolated private static let noiseLineKeywords = ["한도", "잔여", "LIMIT", "환율", "EXCHANGERATE", "카드번호", "승인번호", "REMAINING"]

    nonisolated private static func isNoiseLine(_ normalizedUpper: String) -> Bool {
        noiseLineKeywords.contains { normalizedUpper.contains(normalize($0).uppercased()) }
    }

    /// 在含关键词的行上找金额；优先关键词位于行首的行（避免匹配到说明文字），支持金额在下一行
    nonisolated private static func amountOnLines(
        keyword: String,
        lines: [String],
        normalized: [String],
        excluding: [String] = [],
        skipNoise: Bool = true
    ) -> Decimal? {
        let key = normalize(keyword).uppercased()
        var fallback: Decimal?
        for (index, norm) in normalized.enumerated() {
            let upper = norm.uppercased()
            guard upper.contains(key), !excluding.contains(where: { upper.contains(normalize($0).uppercased()) }) else { continue }
            if skipNoise && isNoiseLine(upper) { continue }

            var found: Decimal?
            if let best = amounts(in: lines[index]).max(by: { abs($0) < abs($1) }) {
                found = best
            } else if index + 1 < lines.count,
                      !(skipNoise && isNoiseLine(normalized[index + 1].uppercased())),
                      let next = amounts(in: lines[index + 1]).max(by: { abs($0) < abs($1) }) {
                found = next
            }
            guard let found else { continue }

            let startsWithKey = upper.trimmingCharacters(in: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: key))).hasPrefix(key)
                || upper.hasPrefix(key) || upper.hasPrefix("*" + key) || upper.hasPrefix("[" + key)
            if startsWithKey {
                return found
            }
            if fallback == nil { fallback = found }
        }
        return fallback
    }

    // MARK: 字段识别

    nonisolated private static func detectDate(lines: [String]) -> Date? {
        let labelKeywords = ["판매일", "거래일", "계산일", "일시", "날짜", "DATE", "DAY/TIME", "승인일"]
        var labeled: Date?
        var first: Date?
        for line in lines {
            guard let date = parseDate(from: line) else { continue }
            if first == nil { first = date }
            let norm = normalize(line).uppercased()
            if labelKeywords.contains(where: { norm.contains(normalize($0).uppercased()) }) {
                labeled = date
                break
            }
        }
        return labeled ?? first
    }

    nonisolated private static func parseDate(from line: String) -> Date? {
        let pattern = #"(20\d{2})[-./](\d{1,2})[-./](\d{1,2})(?:[^\d]{0,3}(\d{1,2}):(\d{2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var comps = DateComponents()
        comps.year = Int(ns.substring(with: match.range(at: 1)))
        comps.month = Int(ns.substring(with: match.range(at: 2)))
        comps.day = Int(ns.substring(with: match.range(at: 3)))
        if match.range(at: 4).location != NSNotFound {
            comps.hour = Int(ns.substring(with: match.range(at: 4)))
            comps.minute = Int(ns.substring(with: match.range(at: 5)))
        }
        guard let month = comps.month, let day = comps.day, (1...12).contains(month), (1...31).contains(day) else { return nil }
        return Calendar.current.date(from: comps)
    }

    nonisolated private static func detectCategory(fullNormalized full: String) -> ReceiptCategory {
        let upper = full.uppercased()
        // 独立退税凭证（头部即为退税单据）
        let head = String(upper.prefix(120))
        if head.contains("GLOBALTAXFREE") || head.contains("TAXREFUND") || head.contains("즉시환급") {
            return .refundSlip
        }
        if upper.contains("면세점") || upper.contains("DUTYFREE") { return .dutyFree }
        let dining = ["구이", "식당", "고기", "국밥", "치킨", "삼겹", "횟집", "포차", "김밥", "분식", "족발", "냉면", "갈비"]
        if dining.contains(where: { full.contains($0) }) { return .dining }
        let cafe = ["카페", "커피", "CAFE", "COFFEE", "베이커리", "요거트", "디저트", "빙수", "베이글", "도넛"]
        if cafe.contains(where: { upper.contains(normalize($0).uppercased()) }) { return .cafe }
        if upper.contains("올리브영") || upper.contains("OLIVEYOUNG") || full.contains("화장품") { return .beauty }
        if upper.contains("환전") || upper.contains("외화") || upper.contains("은행") || upper.contains("BANK") { return .exchange }
        let transport = ["택시", "TAXI", "KORAIL", "고속버스", "지하철"]
        if transport.contains(where: { upper.contains($0) }) { return .transport }
        let lodging = ["호텔", "HOTEL", "모텔", "리조트", "게스트하우스"]
        if lodging.contains(where: { upper.contains($0) }) { return .lodging }
        return .shopping
    }

    /// 知名品牌映射（韩文/英文 → 中文名）
    nonisolated private static let knownStores: [(keys: [String], name: String, chinese: String)] = [
        (["올리브영", "OLIVEYOUNG"], "OLIVE YOUNG", "Olive Young"),
        (["신세계면세점", "SHINSEGAEDUTYFREE", "SHINSEGAE"], "SHINSEGAE Duty Free", "新世界免税店"),
        (["롯데면세점", "LOTTEDUTYFREE"], "LOTTE Duty Free", "乐天免税店"),
        (["하나은행", "HANABANK"], "Hana Bank", "韩亚银行"),
        (["무신사"], "무신사 스탠다드", "Musinsa Standard"),
        (["다이소", "DAISO"], "DAISO", "大创"),
        (["스타벅스", "STARBUCKS"], "STARBUCKS", "星巴克"),
        (["GS25"], "GS25", "GS25 便利店"),
        (["CU편의점"], "CU", "CU 便利店"),
        (["세븐일레븐", "7-ELEVEN"], "7-ELEVEN", "7-11 便利店"),
        (["이마트", "EMART"], "emart", "易买得超市"),
        (["글로벌택스프리", "GLOBALTAXFREE"], "GLOBAL TAXFREE", "Global Taxfree 退税"),
    ]

    nonisolated private static func detectStore(lines: [String], normalized: [String], fullNormalized full: String) -> (String, String) {
        let upper = full.uppercased()
        for entry in knownStores where entry.keys.contains(where: { upper.contains(normalize($0).uppercased()) }) {
            return (entry.name, entry.chinese)
        }
        // 标签行：매장명/상호/가맹점명
        let labels = ["매장명", "상호", "가맹점명", "점포명"]
        for (index, norm) in normalized.enumerated() {
            for label in labels where norm.contains(label) {
                let raw = lines[index]
                if let colon = raw.range(of: ":") ?? raw.range(of: "：") {
                    let name = raw[colon.upperBound...].trimmingCharacters(in: .whitespaces)
                    if name.count >= 2 { return (name, "") }
                }
            }
        }
        // 兜底：头部第一行像名字的（不含金额/日期/电话）
        for line in lines.prefix(4) {
            let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: " []【】-=*"))
            if trimmed.count >= 2 && trimmed.count <= 30 && amounts(in: trimmed).isEmpty
                && !trimmed.contains("영수증") && !trimmed.uppercased().contains("RECEIPT") {
                return (trimmed, "")
            }
        }
        return ("", "")
    }

    nonisolated private static func detectTotal(lines: [String], normalized: [String], category: ReceiptCategory) -> (Decimal?, String) {
        // 关键词按优先级；排除易混淆的合计变体
        let keywords: [(String, [String])] = [
            ("실결제금액", []),
            ("결제금액", ["카드결제금액"]),
            ("매출합계", []),
            ("받을금액", []),
            ("합계", ["과세합계", "면세합계", "부가세합계", "세액합계"]),
            ("총액", []),
            ("TOTAL", ["SUBTOTAL"]),
        ]
        let policyWords = ["EXCEED", "초과", "GUIDE", "HTTPS"]
        for (keyword, excluding) in keywords {
            let key = normalize(keyword).uppercased()
            // 找到关键词所在的具体行，检查是否美元计价
            for (index, norm) in normalized.enumerated() {
                let upper = norm.uppercased()
                guard upper.contains(key),
                      !excluding.contains(where: { upper.contains(normalize($0).uppercased()) }),
                      !policyWords.contains(where: { upper.contains($0) }),
                      !isNoiseLine(upper) else { continue }
                let line = lines[index]
                if line.contains("$"), let usd = dollarAmount(in: line) {
                    return (usd, "USD")
                }
                if let amount = amounts(in: line).filter({ $0 > 0 }).max() {
                    return (amount, "KRW")
                }
                if index + 1 < lines.count,
                   let next = amounts(in: lines[index + 1]).filter({ $0 > 0 }).max() {
                    return (next, "KRW")
                }
            }
        }
        // 兜底：全文最大的千分位金额（排除干扰行与政策说明行）
        let all = zip(lines, normalized).flatMap { line, norm -> [Decimal] in
            let upper = norm.uppercased()
            guard !isNoiseLine(upper), !policyWords.contains(where: { upper.contains($0) }) else { return [] }
            return amounts(in: line).filter { $0 > 0 }
        }
        return (all.max(), "KRW")
    }

    nonisolated private static func detectPayment(fullNormalized full: String) -> String {
        let upper = full.uppercased()
        if upper.contains("WECHAT") || upper.contains("위챗") { return "微信支付" }
        if upper.contains("ALIPAY") || upper.contains("알리페이") { return "支付宝" }
        if upper.contains("현금") || upper.contains("CASH") {
            if upper.contains("카드") || upper.contains("CARD") { return "银行卡" }
            return "现金"
        }
        if upper.contains("하나카드") { return "韩亚卡" }
        if upper.contains("VISA") { return "VISA 卡" }
        if upper.contains("MASTER") { return "万事达卡" }
        if upper.contains("카드") || upper.contains("CARD") || upper.contains("신용승인") { return "银行卡" }
        return ""
    }

    /// 商品行启发式：文本 + 尾随金额，排除统计/支付关键词行
    nonisolated private static func detectItems(lines: [String], normalized: [String]) -> [ReceiptItem] {
        let blacklist = [
            "합계", "부가세", "할인", "결제", "카드", "승인", "면세", "봉사료", "과세", "공급가액",
            "총", "TOTAL", "환급", "REFUND", "환율", "EXCHANGE", "잔액", "포인트", "적립",
            "전화", "TEL", "사업자", "대표", "주소", "금액", "수량", "단가", "품명", "번호",
            "일시", "날짜", "DATE", "V.A.T", "AMOUNT", "받을", "거스름", "매출", "취소",
            "이용권", "쿠폰", "증정", "EXCEED", "한도", "잔여", "LIMIT", "행사", "혜택",
        ]
        var items: [ReceiptItem] = []
        for (index, line) in lines.enumerated() {
            let norm = normalized[index].uppercased()
            guard norm.count >= 3,
                  !blacklist.contains(where: { norm.contains(normalize($0).uppercased()) }) else { continue }

            let lineAmounts = amounts(in: line)
            guard let amount = lineAmounts.last, amount >= 100, amount <= 10_000_000 else { continue }

            // 行首需要有非数字文本（品名）
            guard let amountRange = line.range(of: "\(amount)".count > 3 ? formatComma(amount) : "\(amount)") else { continue }
            let namePart = String(line[line.startIndex..<amountRange.lowerBound])
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t[]*·"))
            // 韩国小票品名必含韩文/中日韩字符，排除英文说明文字误判
            let nameHasCJK = namePart.unicodeScalars.contains {
                (0xAC00...0xD7A3).contains($0.value) || (0x4E00...0x9FFF).contains($0.value)
            }
            guard nameHasCJK, namePart.count >= 2 else { continue }

            // 数量：金额前若有 1~2 位小整数视为数量
            var quantity = 1
            if lineAmounts.count >= 2, let qty = lineAmounts.dropLast().last, qty >= 1, qty <= 99,
               qty == Decimal(Int(truncating: qty as NSNumber)) {
                quantity = Int(truncating: qty as NSNumber)
            }

            var name = namePart
            // 去掉尾部残留的数量/单价数字
            while let last = name.split(separator: " ").last, Decimal(string: last.replacingOccurrences(of: ",", with: "")) != nil {
                name = name.split(separator: " ").dropLast().joined(separator: " ")
            }
            guard name.count >= 2 else { continue }

            items.append(ReceiptItem(nameOriginal: name, quantity: quantity, amount: amount))
            if items.count >= 20 { break }
        }
        return items
    }

    /// 提取 $ 后面的金额
    nonisolated private static func dollarAmount(in line: String) -> Decimal? {
        guard let regex = try? NSRegularExpression(pattern: #"\$\s?([0-9][0-9,]*(?:\.[0-9]+)?)"#) else { return nil }
        let ns = line as NSString
        return regex.matches(in: line, range: NSRange(location: 0, length: ns.length)).compactMap {
            Decimal(string: ns.substring(with: $0.range(at: 1)).replacingOccurrences(of: ",", with: ""))
        }.max()
    }

    nonisolated private static func formatComma(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: value as NSNumber) ?? "\(value)"
    }

    // MARK: 退税判定（2026 年规则：单笔 ≥₩15,000 可退；即时退税单笔 ≤₩100万、行程累计 ≤₩500万）

    nonisolated private static func detectRefund(
        fullNormalized full: String,
        lines: [String],
        normalized: [String],
        category: ReceiptCategory,
        total: Decimal?,
        currency: String
    ) -> (status: RefundStatus, amount: Decimal?, remainingLimit: Decimal?) {
        let upper = full.uppercased()

        // 小票上印的即时退税剩余额度
        var remaining: Decimal?
        if upper.contains("잔여한도") || upper.contains("REMAININGIMMEDIATE") {
            remaining = amountOnLines(keyword: "잔여한도", lines: lines, normalized: normalized)
                ?? amountOnLines(keyword: "Remaining", lines: lines, normalized: normalized)
        }

        // 退税金额
        let refundAmount = amountOnLines(keyword: "환급액", lines: lines, normalized: normalized)
            ?? amountOnLines(keyword: "즉시환급", lines: lines, normalized: normalized, excluding: ["잔여한도", "한도"])
            ?? amountOnLines(keyword: "Refund", lines: lines, normalized: normalized, excluding: ["Remaining", "한도", "Purchase", "구매"])
            ?? taxFreeDeduction(lines: lines, normalized: normalized)

        switch category {
        case .exchange, .transport, .lodging:
            return (.notApplicable, nil, remaining)
        case .dutyFree:
            return (.notApplicable, nil, remaining)
        case .refundSlip:
            let immediate = upper.contains("즉시환급") || upper.contains("IMMEDIATE")
            return (immediate ? .refundedImmediate : .voucherIssued, refundAmount, remaining)
        default:
            break
        }

        // 显式退税证据优先于类别推断
        let hasImmediate = upper.contains("즉시환급") || upper.contains("IMMEDIATETAXREFUND")
            || taxFreeDeduction(lines: lines, normalized: normalized) != nil
        if hasImmediate {
            return (.refundedImmediate, refundAmount, remaining)
        }
        let hasVoucher = upper.contains("환급전표") || upper.contains("TFFNO") || upper.contains("TAXREFUND")
            || (upper.contains("TAXFREE") && refundAmount != nil)
        if hasVoucher {
            return (.voucherIssued, refundAmount, remaining)
        }

        // 餐饮/咖啡为服务消费，不可退税
        if category == .dining || category == .cafe {
            return (.notApplicable, nil, remaining)
        }
        // 零售商品且达 ₩15,000 门槛（2026 年规则）→ 可能可退
        if currency == "KRW", let total, total >= 15_000 {
            return (.maybeEligible, nil, remaining)
        }
        return (.notApplicable, nil, remaining)
    }

    /// 明细中 [TAX FREE] 负数抵扣行（即时退税已在收银台扣除）
    nonisolated private static func taxFreeDeduction(lines: [String], normalized: [String]) -> Decimal? {
        for (index, norm) in normalized.enumerated() {
            let upper = norm.uppercased()
            guard upper.contains("TAXFREE") else { continue }
            let negatives = amounts(in: lines[index]).filter { $0 < 0 }
            if let deduction = negatives.min() {
                return abs(deduction)
            }
            if index + 1 < lines.count, let next = amounts(in: lines[index + 1]).filter({ $0 < 0 }).min() {
                return abs(next)
            }
        }
        return nil
    }
}
