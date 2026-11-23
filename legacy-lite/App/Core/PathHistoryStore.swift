import Foundation

struct PathRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var path: String
    var lastUsedAt: Date
    var useCount: Int
}

/// Persists the destination paths the user has already used, newest first.
enum PathHistoryStore {
    private static let fileName = "path-history.json"

    private static var fileURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(fileName, isDirectory: false)
    }

    static func load() -> [PathRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([PathRecord].self, from: data)
        else { return [] }
        return items.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    @discardableResult
    static func record(_ path: String) -> [PathRecord] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return load() }

        var items = load()
        if let index = items.firstIndex(where: { $0.path == trimmed }) {
            items[index].lastUsedAt = Date()
            items[index].useCount += 1
        } else {
            items.append(PathRecord(
                id: UUID(),
                path: trimmed,
                lastUsedAt: Date(),
                useCount: 1
            ))
        }
        save(items)
        return items.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    static func remove(id: UUID) {
        save(load().filter { $0.id != id })
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func save(_ items: [PathRecord]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
