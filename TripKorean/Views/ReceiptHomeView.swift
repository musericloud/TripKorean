import SwiftUI
import PhotosUI

// MARK: - 金额格式化

enum ReceiptFormat {
    static func money(_ value: Decimal?, currency: String = "KRW") -> String {
        guard let value else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency == "KRW" ? 0 : 2
        let number = formatter.string(from: value as NSNumber) ?? "\(value)"
        switch currency {
        case "KRW": return "₩\(number)"
        case "USD": return "$\(number)"
        case "CNY": return "¥\(number)"
        default: return "\(number) \(currency)"
        }
    }

    static func cny(fromKRW krw: Decimal, rate: Double) -> Decimal {
        guard rate > 0 else { return 0 }
        return krw / Decimal(rate)
    }
}

// MARK: - 小票首页

struct ReceiptHomeView: View {
    let receiptStore: ReceiptStore
    let speechService: SpeechService

    @AppStorage("selectedTripID") private var selectedTripIDString = ""
    @State private var showCamera = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pendingImages: [UIImage] = []
    @State private var showProcessor = false
    @State private var showTripManager = false
    @State private var cameraImage: UIImage?

    private var selectedTrip: Trip {
        if let id = UUID(uuidString: selectedTripIDString),
           let trip = receiptStore.trips.first(where: { $0.id == id }) {
            return trip
        }
        return receiptStore.trips.first ?? Trip(name: "我的韩国之旅")
    }

    private var tripReceipts: [Receipt] {
        receiptStore.receipts(in: selectedTrip)
    }

    /// 按天分组
    private var dayGroups: [(day: String, receipts: [Receipt])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        let grouped = Dictionary(grouping: tripReceipts) { receipt in
            receipt.date.map { formatter.string(from: Calendar.current.startOfDay(for: $0)) } ?? "未识别日期"
        }
        return grouped
            .map { (day: $0.key, receipts: $0.value) }
            .sorted { $0.receipts.first?.date ?? .distantPast > $1.receipts.first?.date ?? .distantPast }
    }

    var body: some View {
        Group {
            if tripReceipts.isEmpty {
                emptyState
            } else {
                receiptList
            }
        }
        .navigationTitle(selectedTrip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(receiptStore.trips) { trip in
                        Button {
                            selectedTripIDString = trip.id.uuidString
                        } label: {
                            if trip.id == selectedTrip.id {
                                Label(trip.name, systemImage: "checkmark")
                            } else {
                                Text(trip.name)
                            }
                        }
                    }
                    Divider()
                    Button {
                        showTripManager = true
                    } label: {
                        Label("管理行程", systemImage: "folder.badge.gearshape")
                    }
                } label: {
                    Image(systemName: "suitcase.fill")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍小票", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                    Label("相册导入", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $cameraImage)
                .ignoresSafeArea()
        }
        .onChange(of: cameraImage) { _, newImage in
            if let newImage {
                pendingImages = [newImage]
                cameraImage = nil
                showProcessor = true
            }
        }
        .onChange(of: photoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                photoItems = []
                if !images.isEmpty {
                    pendingImages = images
                    showProcessor = true
                }
            }
        }
        .sheet(isPresented: $showProcessor) {
            ReceiptProcessorView(
                images: pendingImages,
                trip: selectedTrip,
                receiptStore: receiptStore
            )
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showTripManager) {
            TripManagerView(receiptStore: receiptStore, selectedTripIDString: $selectedTripIDString)
        }
    }

    // MARK: 列表

    private var receiptList: some View {
        List {
            Section {
                NavigationLink {
                    ReceiptSummaryView(receiptStore: receiptStore, trip: selectedTrip)
                } label: {
                    summaryCard
                }
            }

            ForEach(dayGroups, id: \.day) { group in
                Section(group.day) {
                    ForEach(group.receipts) { receipt in
                        NavigationLink {
                            ReceiptDetailView(receiptStore: receiptStore, receipt: receipt)
                        } label: {
                            ReceiptRow(receipt: receipt)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            receiptStore.delete(group.receipts[index])
                        }
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        let spending = tripReceipts.filter { $0.category.countsAsSpending }
        let krwTotal = spending.compactMap(\.totalInKRW).reduce(0, +)
        let refunded = tripReceipts.compactMap { $0.refundStatus == .refundedImmediate ? $0.refundAmount : nil }.reduce(0, +)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("行程汇总", systemImage: "chart.pie.fill")
                    .font(.headline)
                Spacer()
                Text("\(tripReceipts.count) 张小票")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ReceiptFormat.money(krwTotal))
                    .font(.title2)
                    .fontWeight(.bold)
                Text("≈ " + ReceiptFormat.money(ReceiptFormat.cny(fromKRW: krwTotal, rate: selectedTrip.krwPerCny), currency: "CNY"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if refunded > 0 {
                Text("已退税 " + ReceiptFormat.money(refunded))
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有小票", systemImage: "doc.text.viewfinder")
        } description: {
            Text("购物后拍下小票，自动识别店铺、金额、商品\n并标记能不能退税\n\n拍摄时一次拍一张，小票尽量充满画面")
        }
    }
}

// MARK: - 小票行

struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.displayStore)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 6) {
                    Label(receipt.category.rawValue, systemImage: receipt.category.icon)
                        .foregroundStyle(receipt.category.color)
                    Label(receipt.refundStatus.rawValue, systemImage: receipt.refundStatus.icon)
                        .foregroundStyle(receipt.refundStatus.badgeColor)
                }
                .font(.caption2)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: 8)

            Text(ReceiptFormat.money(receipt.total, currency: receipt.currency))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(receipt.category.countsAsSpending ? .primary : .secondary)
                .layoutPriority(1)
        }
    }

    private var thumbnail: some View {
        Group {
            if let image = ReceiptStore.loadImage(named: receipt.imageFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.text")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 44, height: 44)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 行程管理

struct TripManagerView: View {
    let receiptStore: ReceiptStore
    @Binding var selectedTripIDString: String
    @Environment(\.dismiss) private var dismiss
    @State private var newTripName = ""
    @State private var showAddAlert = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(receiptStore.trips) { trip in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.name)
                            Text("\(receiptStore.receipts(in: trip).count) 张小票 · 汇率 1¥≈₩\(String(format: "%.0f", trip.krwPerCny))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if trip.id.uuidString == selectedTripIDString {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTripIDString = trip.id.uuidString
                        dismiss()
                    }
                }
                .onDelete { indexSet in
                    guard receiptStore.trips.count > 1 else { return }
                    for index in indexSet {
                        receiptStore.deleteTrip(receiptStore.trips[index])
                    }
                }
            }
            .navigationTitle("行程管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("新建行程", isPresented: $showAddAlert) {
                TextField("行程名称，如：2026春节釜山", text: $newTripName)
                Button("创建") {
                    let name = newTripName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        let trip = receiptStore.addTrip(name: name)
                        selectedTripIDString = trip.id.uuidString
                    }
                    newTripName = ""
                }
                Button("取消", role: .cancel) { newTripName = "" }
            }
        }
    }
}
