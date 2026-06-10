import Foundation

/// JSON persistence in Application Support. The repository seam:
/// `AppModel` only ever talks to `SnapshotPersisting`, so a Firestore-backed
/// implementation can replace this class without touching features.
protocol SnapshotPersisting: Sendable {
    func load() -> AppSnapshot?
    func save(_ snapshot: AppSnapshot)
}

final class LocalStore: SnapshotPersisting, @unchecked Sendable {

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.bricksinabag.planr.store", qos: .utility)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileName: String = "planr-state.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("Planr", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent(fileName)

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Synchronous load at launch — the state file is small and local.
    func load() -> AppSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(AppSnapshot.self, from: data)
    }

    /// Writes happen off the main thread on a serial queue, last write wins.
    func save(_ snapshot: AppSnapshot) {
        queue.async { [encoder, fileURL] in
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
