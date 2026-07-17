import SwiftUI

struct ReceiptDetailView: View {
    let receiptStore: ReceiptStore
    @State var receipt: Receipt

    @Environment(\.dismiss) private var dismiss
    @State private var showFullImage = false
    @State private var showRefundRules = false
    @State private var totalText = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            imageSection
            basicSection
            refundSection
            itemsSection
            noteSection
            rawTextSection

            Section {
                Button("删除这张小票", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle(receipt.displayStore)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            totalText = receipt.total.map { "\($0)" } ?? ""
        }
        .onChange(of: receipt) {
            receiptStore.update(receipt)
        }
        .sheet(isPresented: $showRefundRules) {
            RefundRulesView()
        }
        .fullScreenCover(isPresented: $showFullImage) {
            fullImageViewer
        }
        .confirmationDialog("确定删除这张小票？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                receiptStore.delete(receipt)
                dismiss()
            }
        }
    }

    // MARK: 图片

    private var imageSection: some View {
        Section {
            if let image = ReceiptStore.loadImage(named: receipt.imageFileName) {
                Button {
                    showFullImage = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("点击查看大图")
        }
    }

    private var fullImageViewer: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    showFullImage = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.white.opacity(0.15), in: Circle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            if let image = ReceiptStore.loadImage(named: receipt.imageFileName) {
                GeometryReader { geo in
                    let scale = min(geo.size.width / max(image.size.width, 1), geo.size.height / max(image.size.height, 1))
                    ZoomableContainer(
                        contentSize: CGSize(width: image.size.width * scale, height: image.size.height * scale),
                        resetToken: receipt.imageFileName
                    ) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: image.size.width * scale, height: image.size.height * scale)
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: 基本信息

    private var basicSection: some View {
        Section("基本信息") {
            LabeledContent("店铺") {
                TextField("中文店名", text: $receipt.storeChinese)
                    .multilineTextAlignment(.trailing)
            }
            if !receipt.store.isEmpty && receipt.store != receipt.storeChinese {
                LabeledContent("原文") {
                    Text(receipt.store)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            DatePicker(
                "日期",
                selection: Binding(
                    get: { receipt.date ?? receipt.createdAt },
                    set: { receipt.date = $0 }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            Picker("类别", selection: $receipt.category) {
                ForEach(ReceiptCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.icon).tag(category)
                }
            }
            LabeledContent("金额") {
                HStack(spacing: 4) {
                    Picker("", selection: $receipt.currency) {
                        Text("₩").tag("KRW")
                        Text("$").tag("USD")
                        Text("¥").tag("CNY")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()

                    TextField("0", text: $totalText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .onChange(of: totalText) {
                            receipt.total = Decimal(string: totalText.replacingOccurrences(of: ",", with: ""))
                        }
                }
            }
            if let tax = receipt.tax {
                LabeledContent("含税(VAT)") {
                    Text(ReceiptFormat.money(tax, currency: receipt.currency))
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("支付方式") {
                TextField("如：银行卡", text: $receipt.paymentMethod)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: 退税

    private var refundSection: some View {
        Section {
            Picker("退税状态", selection: $receipt.refundStatus) {
                ForEach(RefundStatus.allCases) { status in
                    Label(status.rawValue, systemImage: status.icon).tag(status)
                }
            }

            if receipt.refundStatus == .refundedImmediate || receipt.refundStatus == .voucherIssued {
                LabeledContent("退税金额") {
                    Text(ReceiptFormat.money(receipt.refundAmount))
                        .foregroundStyle(.green)
                }
            }
            if let remaining = receipt.remainingRefundLimit {
                LabeledContent("即时退税剩余额度") {
                    Text(ReceiptFormat.money(remaining))
                        .foregroundStyle(.secondary)
                }
            }

            Label(receipt.refundStatus.guidance, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showRefundRules = true
            } label: {
                Label("查看退税规则", systemImage: "book")
                    .font(.caption)
            }
        } header: {
            Text("退税")
        }
    }

    // MARK: 商品明细

    private var itemsSection: some View {
        Section("商品明细（\(receipt.items.count)）") {
            ForEach($receipt.items) { $item in
                VStack(alignment: .leading, spacing: 4) {
                    TextField("中文品名", text: $item.nameChinese, prompt: Text(item.nameOriginal))
                    HStack {
                        Text(item.nameOriginal)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                        Spacer()
                        Text("x\(item.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ReceiptFormat.money(item.amount, currency: receipt.currency))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            .onDelete { indexSet in
                receipt.items.remove(atOffsets: indexSet)
            }

            Button {
                receipt.items.append(ReceiptItem(nameOriginal: "", nameChinese: "新条目"))
            } label: {
                Label("添加条目", systemImage: "plus")
                    .font(.caption)
            }
        }
    }

    private var noteSection: some View {
        Section("备注") {
            TextField("买了什么、给谁的、心得...", text: $receipt.note, axis: .vertical)
                .lineLimit(1...4)
        }
    }

    private var rawTextSection: some View {
        Section {
            DisclosureGroup("识别原文") {
                Text(receipt.rawText.isEmpty ? "无" : receipt.rawText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - 退税规则

struct RefundRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("基本条件") {
                    Label("单笔消费满 ₩15,000 即可退税", systemImage: "wonsign.circle")
                    Label("购买后 3 个月内携带商品离境", systemImage: "airplane.departure")
                    Label("商品需未使用（可能开箱查验）", systemImage: "shippingbox")
                }
                Section("即时退税（结账时直接减免）") {
                    Label("单笔上限 ₩1,000,000", systemImage: "1.circle")
                    Label("整个行程累计上限 ₩5,000,000", systemImage: "5.circle")
                    Label("结账时出示护照原件，说 Tax Free 即可", systemImage: "person.text.rectangle")
                }
                Section("不适用退税") {
                    Label("餐厅、咖啡厅等服务消费", systemImage: "fork.knife")
                    Label("免税店购物（本身已免税）", systemImage: "airplane")
                    Label("交通、住宿费用", systemImage: "tram")
                }
                Section {
                    Text("实际退税约为金额的 5~8%（扣除手续费）。规则为 2026 年现行版本，以商家和海关现场为准。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("韩国购物退税规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
