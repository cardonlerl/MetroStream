import Foundation

struct MemoryStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [UserMemory] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let memories = try? decoder.decode([UserMemory].self, from: data)
        else {
            return []
        }
        return memories
    }

    func save(ride: RideSession) {
        let ownEntries = ride.publishedEntries.filter(\.isMine)
        guard !ownEntries.isEmpty else { return }

        var memories = load()
        memories.append(
            UserMemory(
                route: ride.route,
                startedAt: ride.startedAt,
                entries: ownEntries
            )
        )
        save(memories: memories)
    }

    func save(memories: [UserMemory]) {
        guard let data = try? encoder.encode(memories) else { return }
        let folderURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: [.atomic])
    }

    private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("sardine-memories.json")
    }
}
