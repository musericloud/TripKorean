import SwiftUI
import Charts

struct ReceiptSummaryView: View {
    let receiptStore: ReceiptStore
    @State var trip: Trip

    @State private var rateText = ""
    @State private var showCopiedToast = false

    private var receipts: [Receipt] {
        receiptStore.receipts(in: trip)
    }

    private var spendingReceipts: [Receipt] {
        receipts.filter { $0.category.countsAsSpending }
    }

    private var krwTotal: Decimal {
        spendingReceipts.compactMap(\.totalInKRW).reduce(0, +)
    }

    private var usdTotal: Decimal {
        spendingReceipts.filter { $0.currency == "USD" }.compactMap(\.total).reduce(0, +)
    }

    private var refundedTotal: Decimal {
        receipts.compactMap { $0.refundStatus == .refundedImmediate ? $0.refundAmount : nil }.reduce(0, +)
    }

    private var pendingVouchers: [Receipt] {
        receipts.filter { $0.refundStatus == .voucherIssued }
    }

    private var maybeEligible: [Receipt] {
        receipts.filter { $0.refundStatus == .maybeEligible }
    }

    private var remainingLimit: Decimal? {
        receipts
            .filter { $0.remainingRefundLimit != nil }
            .sorted { $0.date ?? .distantPast > $1.date ?? .distantPast }
            .first?.remainingRefundLimit
    }

    private var categoryTotals: [(category: ReceiptCategory, total: Decimal)] {
        Dictionary(grouping: spendingReceipts.filter { $0.totalInKRW != nil }, by: \.category)
            .map { (category: $0.key, total: $0.value.compactMap(\.totalInKRW).reduce(0, +)) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    private var dayTotals: [(day: Date, total: Decimal)] {
        Dictionary(grouping: spendingReceipts.filter { $0.date != nil && $0.totalInKRW != nil }) {
            Calendar.current.startOfDay(for: $0.date!)
        }
        .map { (day: $0.key, total: $0.value.compactMap(\.totalInKRW).reduce(0, +)) }
        .sorted { $0.day < $1.day }
    }

    var body: some View {
        List {
            totalSection
            refundSection

            if !categoryTotals.isEmpty {
                categoryChartSection
            }
            if dayTotals.count >= 2 {
                dayChartSection
            }

            exchangeRateSection
            exportSection
        }
        .navigationTitle("行程汇总")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rateText = String(format: "%.0f", trip.krwPerCny)
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                Text("已复制 Markdown 表格")
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: 总额

    private var totalSection: some View {
        Section("消费总额") {
            LabeledContent("韩元消费") {
                Text(ReceiptFormat.money(krwTotal))
                    .font(.headline)
            }
            LabeledContent("约合人民币") {
                Text(ReceiptFormat.money(ReceiptFormat.cny(fromKRW: krwTotal, rate: trip.krwPerCny), currency: "CNY"))
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            if usdTotal > 0 {
                LabeledContent("美元消费（免税店等）") {
                    Text(ReceiptFormat.money(usdTotal, currency: "USD"))
                }
            }
            LabeledContent("小票数量") {
                Text("\(receipts.count) 张")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 退税

    private var refundSection: some View {
        Section("退税") {
            LabeledContent("已退税（即时）") {
                Text(ReceiptFormat.money(refundedTotal))
                    .foregroundStyle(.green)
            }
            if !pendingVouchers.isEmpty {
                LabeledContent("待办退税凭证") {
                    Text("\(pendingVouchers.count) 张")
                        .foregroundStyle(.yellow)
                }
                Text("离境前记得在机场/市区退税点办理")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !maybeEligible.isEmpty {
                LabeledContent("可能可退但未办") {
                    Text("\(maybeEligible.count) 张")
                        .foregroundStyle(.blue)
                }
            }
            if let remaining = remainingLimit {
                LabeledContent("即时退税剩余额度") {
                    Text(ReceiptFormat.money(remaining))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: 图表

    private var categoryChartSection: some View {
        Section("分类占比") {
            Chart(categoryTotals, id: \.category) { entry in
                SectorMark(
                    angle: .value("金额", NSDecimalNumber(decimal: entry.total).doubleValue),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .foregroundStyle(entry.category.color)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .padding(.vertical, 6)

            ForEach(categoryTotals, id: \.category) { entry in
                HStack {
                    Label(entry.category.rawValue, systemImage: entry.category.icon)
                        .font(.caption)
                        .foregroundStyle(entry.category.color)
                    Spacer()
                    Text(ReceiptFormat.money(entry.total))
                        .font(.caption)
                }
            }
        }
    }

    private var dayChartSection: some View {
        Section("每日消费") {
            Chart(dayTotals, id: \.day) { entry in
                BarMark(
                    x: .value("日期", entry.day, unit: .day),
                    y: .value("金额", NSDecimalNumber(decimal: entry.total).doubleValue)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
                }
            }
            .frame(height: 160)
            .padding(.vertical, 6)
        }
    }

    // MARK: 汇率

    private var exchangeRateSection: some View {
        Section {
            LabeledContent("1 人民币 ≈") {
                HStack(spacing: 4) {
                    TextField("190", text: $rateText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: rateText) {
                            if let rate = Double(rateText), rate > 0 {
                                trip.krwPerCny = rate
                                receiptStore.updateTrip(trip)
                            }
                        }
                    Text("韩元")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("汇率设置")
        } footer: {
            Text("用于人民币估算，可参考换汇小票上的实际汇率")
        }
    }

    // MARK: 导出

    private var exportSection: some View {
        Section("导出") {
            ShareLink(item: csvFileURL()) {
                Label("导出 CSV（Excel 可打开）", systemImage: "tablecells")
            }
            Button {
                UIPasteboard.general.string = markdownTable()
                withAnimation { showCopiedToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showCopiedToast = false }
                }
            } label: {
                Label("复制 Markdown 表格", systemImage: "doc.on.doc")
            }
        }
    }

    private func csvFileURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var csv = "日期,店铺,类别,币种,金额,税,支付方式,退税状态,退税额,商品明细,备注\n"
        for receipt in receipts.sorted(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }) {
            let items = receipt.items
                .map { "\($0.displayName)x\($0.quantity)" }
                .joined(separator: "；")
            let dateText: String = receipt.date.map { formatter.string(from: $0) } ?? ""
            let totalText: String = receipt.total.map { "\($0)" } ?? ""
            let taxText: String = receipt.tax.map { "\($0)" } ?? ""
            let refundText: String = receipt.refundAmount.map { "\($0)" } ?? ""
            var fields: [String] = [dateText, receipt.displayStore, receipt.category.rawValue]
            fields += [receipt.currency, totalText, taxText, receipt.paymentMethod]
            fields += [receipt.refundStatus.rawValue, refundText, items, receipt.note]
            csv += fields.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") + "\n"
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(trip.name)-小票.csv")
        // 加 BOM 让 Excel 正确识别 UTF-8 中文
        let bom = Data([0xEF, 0xBB, 0xBF])
        try? (bom + Data(csv.utf8)).write(to: url)
        return url
    }

    private func markdownTable() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"

        var md = "# \(trip.name) 消费记录\n\n"
        md += "| 日期 | 店铺 | 类别 | 金额 | 退税 |\n|---|---|---|---|---|\n"
        let sorted = receipts.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        for receipt in sorted {
            let date = receipt.date.map { formatter.string(from: $0) } ?? "-"
            let money = ReceiptFormat.money(receipt.total, currency: receipt.currency)
            let row = "| \(date) | \(receipt.displayStore) | \(receipt.category.rawValue) | \(money) | \(receipt.refundStatus.rawValue) |\n"
            md += row
        }
        let totalKRW = ReceiptFormat.money(krwTotal)
        let totalCNY = ReceiptFormat.money(ReceiptFormat.cny(fromKRW: krwTotal, rate: trip.krwPerCny), currency: "CNY")
        md += "\n**合计：" + totalKRW + " ≈ " + totalCNY + "**"
        if refundedTotal > 0 {
            md += "，已退税 " + ReceiptFormat.money(refundedTotal)
        }
        md += "\n"
        return md
    }
}
