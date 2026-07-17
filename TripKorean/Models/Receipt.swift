import Foundation
import SwiftUI

// MARK: - 行程

struct Trip: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    /// 韩元 → 人民币 汇率（1 CNY = ? KRW），如 196
    var krwPerCny: Double = 190
    var createdAt = Date()
}

// MARK: - 小票

/// 单据类别
enum ReceiptCategory: String, Codable, CaseIterable, Identifiable {
    case shopping = "购物"
    case beauty = "美妆"
    case dining = "餐饮"
    case cafe = "咖啡甜品"
    case dutyFree = "免税店"
    case transport = "交通"
    case lodging = "住宿"
    case exchange = "换汇"
    case refundSlip = "退税凭证"
    case other = "其他"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .shopping: "bag.fill"
        case .beauty: "sparkles"
        case .dining: "fork.knife"
        case .cafe: "cup.and.saucer.fill"
        case .dutyFree: "airplane"
        case .transport: "tram.fill"
        case .lodging: "bed.double.fill"
        case .exchange: "wonsign.arrow.trianglehead.counterclockwise.rotate.90"
        case .refundSlip: "percent"
        case .other: "doc.text"
        }
    }

    var color: Color {
        switch self {
        case .shopping: .blue
        case .beauty: .pink
        case .dining: .orange
        case .cafe: .brown
        case .dutyFree: .indigo
        case .transport: .green
        case .lodging: .teal
        case .exchange: .gray
        case .refundSlip: .purple
        case .other: .secondary
        }
    }

    /// 是否计入消费统计（换汇、退税凭证不算消费）
    var countsAsSpending: Bool {
        switch self {
        case .exchange, .refundSlip: false
        default: true
        }
    }
}

/// 退税状态
enum RefundStatus: String, Codable, CaseIterable, Identifiable {
    case refundedImmediate = "已退税·即时"
    case voucherIssued = "已开退税单"
    case maybeEligible = "可能可退"
    case notApplicable = "不适用"

    var id: String { rawValue }

    var badgeColor: Color {
        switch self {
        case .refundedImmediate: .green
        case .voucherIssued: .yellow
        case .maybeEligible: .blue
        case .notApplicable: .gray
        }
    }

    var icon: String {
        switch self {
        case .refundedImmediate: "checkmark.seal.fill"
        case .voucherIssued: "clock.badge.exclamationmark"
        case .maybeEligible: "questionmark.circle"
        case .notApplicable: "minus.circle"
        }
    }

    var guidance: String {
        switch self {
        case .refundedImmediate: "结账时已即时退税，离境时无需重复办理"
        case .voucherIssued: "已开退税凭证，离境前在机场/市区退税点办理"
        case .maybeEligible: "金额满 ₩15,000 且为商品消费，结账时出示护照询问 Tax Free 即可退税"
        case .notApplicable: "餐饮/服务/免税店/不足 ₩15,000 等情形不适用退税"
        }
    }
}

struct ReceiptItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var nameOriginal: String
    var nameChinese: String = ""
    var quantity: Int = 1
    var amount: Decimal?

    var displayName: String {
        nameChinese.isEmpty ? nameOriginal : nameChinese
    }
}

struct Receipt: Identifiable, Codable, Hashable {
    var id = UUID()
    var tripID: UUID
    /// 原图文件名（存于 Documents/Receipts/）
    var imageFileName: String
    var store: String = ""
    var storeChinese: String = ""
    var date: Date?
    /// 货币代码：KRW / USD / CNY
    var currency: String = "KRW"
    var total: Decimal?
    var tax: Decimal?
    var paymentMethod: String = ""
    var category: ReceiptCategory = .other
    var items: [ReceiptItem] = []
    var refundStatus: RefundStatus = .notApplicable
    /// 检测到的退税金额（韩元）
    var refundAmount: Decimal?
    /// 小票上印的即时退税剩余额度（若有）
    var remainingRefundLimit: Decimal?
    var rawText: String = ""
    var note: String = ""
    var createdAt = Date()

    var displayStore: String {
        storeChinese.isEmpty ? (store.isEmpty ? "未识别店铺" : store) : storeChinese
    }

    /// 以韩元计的金额（美元单据按 0 处理，统计时单列）
    var totalInKRW: Decimal? {
        currency == "KRW" ? total : nil
    }
}
