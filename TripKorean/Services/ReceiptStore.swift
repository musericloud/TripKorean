import Foundation
import UIKit

@MainActor
@Observable
final class ReceiptStore {
    var trips: [Trip] = []
    var receipts: [Receipt] = []

    private static let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let dataURL = docs.appendingPathComponent("receipts.json")
    private static let imagesDir = docs.appendingPathComponent("Receipts", isDirectory: true)

    private struct Payload: Codable {
        var trips: [Trip]
        var receipts: [Receipt]
    }

    init() {
        try? FileManager.default.createDirectory(at: Self.imagesDir, withIntermediateDirectories: true)
        load()
        if trips.isEmpty {
            trips = [Trip(name: "我的韩国之旅")]
            save()
        }
    }

    // MARK: - 行程

    func addTrip(name: String) -> Trip {
        let trip = Trip(name: name)
        trips.append(trip)
        save()
        return trip
    }

    func updateTrip(_ trip: Trip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            save()
        }
    }

    func deleteTrip(_ trip: Trip) {
        for receipt in receipts where receipt.tripID == trip.id {
            deleteImage(named: receipt.imageFileName)
        }
        receipts.removeAll { $0.tripID == trip.id }
        trips.removeAll { $0.id == trip.id }
        save()
    }

    func receipts(in trip: Trip) -> [Receipt] {
        receipts
            .filter { $0.tripID == trip.id }
            .sorted { ($0.date ?? $0.createdAt) > ($1.date ?? $1.createdAt) }
    }

    // MARK: - 小票

    func add(_ receipt: Receipt) {
        receipts.append(receipt)
        save()
    }

    func update(_ receipt: Receipt) {
        if let index = receipts.firstIndex(where: { $0.id == receipt.id }) {
            receipts[index] = receipt
            save()
        }
    }

    func delete(_ receipt: Receipt) {
        deleteImage(named: receipt.imageFileName)
        receipts.removeAll { $0.id == receipt.id }
        save()
    }

    // MARK: - 图片文件

    /// 保存图片（压缩为 JPEG），返回文件名
    static func saveImage(_ image: UIImage) -> String? {
        let name = UUID().uuidString + ".jpg"
        guard let data = image.jpegData(compressionQuality: 0.75) else { return nil }
        do {
            try data.write(to: imagesDir.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func loadImage(named name: String) -> UIImage? {
        UIImage(contentsOfFile: imagesDir.appendingPathComponent(name).path)
    }

    private func deleteImage(named name: String) {
        try? FileManager.default.removeItem(at: Self.imagesDir.appendingPathComponent(name))
    }

    // MARK: - 持久化

    private func save() {
        let payload = Payload(trips: trips, receipts: receipts)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: dataURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: dataURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        trips = payload.trips
        receipts = payload.receipts
    }
}
