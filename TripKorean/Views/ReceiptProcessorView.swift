import SwiftUI
@preconcurrency import Translation

// MARK: - 识别处理流程：OCR → 规则解析 → 立即入库 → 异步补翻译

struct ReceiptProcessorView: View {
    let images: [UIImage]
    let trip: Trip
    let receiptStore: ReceiptStore

    @Environment(\.dismiss) private var dismiss
    @State private var results: [ProcessResult] = []
    @State private var isRecognizing = true
    @State private var isTranslating = false
    @State private var configuration: TranslationSession.Configuration?
    @State private var savedIDs: [UUID] = []

    struct ProcessResult: Identifiable {
        let id = UUID()
        var store: String
        var total: String
        var refund: RefundStatus
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if isRecognizing {
                    ProgressView()
                    Text("正在识别 \(images.count) 张小票...")
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("已录入 \(results.count) 张小票")
                        .font(.headline)
                    if isTranslating {
                        Text("品名翻译进行中，稍后自动更新")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !results.isEmpty {
                    List(results) { result in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.store.isEmpty ? "未识别店铺" : result.store)
                                    .font(.subheadline)
                                Label(result.refund.rawValue, systemImage: result.refund.icon)
                                    .font(.caption2)
                                    .foregroundStyle(result.refund.badgeColor)
                            }
                            Spacer()
                            Text(result.total)
                                .fontWeight(.medium)
                        }
                    }
                    .listStyle(.plain)
                }

                if !isRecognizing {
                    Button {
                        dismiss()
                    } label: {
                        Text("完成")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .navigationTitle("识别小票")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await recognizeAndSaveAll()
        }
        .translationTask(configuration) { session in
            await translateSaved(session: session)
        }
    }

    // MARK: 识别 + 入库

    private func recognizeAndSaveAll() async {
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let parsed = await Task.detached(priority: .userInitiated) {
                let lines = ReceiptOCR.recognizeLines(cgImage: cgImage, orientation: orientation)
                return LocalReceiptParser.parse(lines: lines)
            }.value

            let receipt = buildReceipt(image: image, parsed: parsed)
            receiptStore.add(receipt)
            savedIDs.append(receipt.id)
            results.append(ProcessResult(
                store: receipt.displayStore,
                total: ReceiptFormat.money(receipt.total, currency: receipt.currency),
                refund: receipt.refundStatus
            ))
        }
        isRecognizing = false

        // 有需要翻译的内容才启动翻译
        let needsTranslation = receiptStore.receipts.contains { receipt in
            savedIDs.contains(receipt.id) && (
                (receipt.storeChinese.isEmpty && containsKorean(receipt.store))
                    || receipt.items.contains { $0.nameChinese.isEmpty && containsKorean($0.nameOriginal) }
            )
        }
        if needsTranslation {
            isTranslating = true
            configuration = .init(
                source: .init(identifier: "ko"),
                target: .init(identifier: "zh-Hans")
            )
        }
    }

    // MARK: 异步补翻译（失败静默保留原文）

    private func translateSaved(session: TranslationSession) async {
        for id in savedIDs {
            guard var receipt = receiptStore.receipts.first(where: { $0.id == id }) else { continue }
            var changed = false

            if receipt.storeChinese.isEmpty && containsKorean(receipt.store),
               let translated = try? await session.translate(receipt.store).targetText {
                receipt.storeChinese = translated
                changed = true
            }
            for index in receipt.items.indices
            where receipt.items[index].nameChinese.isEmpty && containsKorean(receipt.items[index].nameOriginal) {
                if let translated = try? await session.translate(receipt.items[index].nameOriginal).targetText {
                    receipt.items[index].nameChinese = translated
                    changed = true
                }
            }
            if changed {
                receiptStore.update(receipt)
                if let row = results.firstIndex(where: { $0.store == receipt.store || $0.store == receipt.displayStore }) {
                    results[row].store = receipt.displayStore
                }
            }
        }
        isTranslating = false
    }

    private func buildReceipt(image: UIImage, parsed: ParsedReceipt) -> Receipt {
        var receipt = Receipt(
            tripID: trip.id,
            imageFileName: ReceiptStore.saveImage(image) ?? ""
        )
        receipt.store = parsed.store
        receipt.storeChinese = parsed.storeChinese
        receipt.date = parsed.date
        receipt.currency = parsed.currency
        receipt.total = parsed.total
        receipt.tax = parsed.tax
        receipt.paymentMethod = parsed.paymentMethod
        receipt.category = parsed.category
        receipt.items = parsed.items
        receipt.refundStatus = parsed.refundStatus
        receipt.refundAmount = parsed.refundAmount
        receipt.remainingRefundLimit = parsed.remainingRefundLimit
        receipt.rawText = parsed.rawText
        return receipt
    }

    private func containsKorean(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
    }
}
