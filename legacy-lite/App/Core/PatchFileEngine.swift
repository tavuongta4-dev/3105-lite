import Foundation

struct BackupEntry: Codable, Hashable {
    /// Path of the patched file, relative to the destination base path.
    let relativePath: String
    /// Name of the original-file copy inside the transaction backup folder.
    let backupFileName: String?
    /// False means the patch created a new file; restore removes it.
    let hadOriginal: Bool
}

struct PatchTransaction: Codable, Identifiable, Hashable {
    let id: UUID
    let packageID: UUID
    let patchName: String
    let basePath: String
    let appliedAt: Date
    let entries: [BackupEntry]
    /// Directories created by this apply, removed on restore if they end up empty.
    let createdDirectories: [String]
}

enum PatchEngineError: LocalizedError {
    case emptyBasePath
    case baseNotDirectory
    case unsafePath
    case nothingToApply
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyBasePath:
            return "Chưa nhập path đích."
        case .baseNotDirectory:
            return "Path đích không tồn tại hoặc không phải thư mục."
        case .unsafePath:
            return "Đường dẫn không an toàn (chứa '..', đường dẫn tuyệt đối hoặc ký tự không hợp lệ)."
        case .nothingToApply:
            return "Patch không có quy tắc nào để áp dụng."
        case .restoreFailed(let detail):
            return "Khôi phục thất bại: \(detail)"
        }
    }
}

/// Applies patched files into a user-supplied destination directory and restores them
/// from local copies. Restore only touches recorded files and never re-decrypts the
/// package, so it completes in well under a second for typical patches.
enum PatchFileEngine {
    private static var root: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let url = base.appendingPathComponent("PatchEngine", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var backupsRoot: URL {
        let url = root.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var transactionsURL: URL {
        root.appendingPathComponent("transactions.json", isDirectory: false)
    }

    // MARK: Read / write transaction index

    static func loadTransactions() -> [PatchTransaction] {
        guard let data = try? Data(contentsOf: transactionsURL),
              let items = try? JSONDecoder().decode([PatchTransaction].self, from: data)
        else { return [] }
        return items.sorted { $0.appliedAt > $1.appliedAt }
    }

    private static func saveTransactions(_ items: [PatchTransaction]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: transactionsURL, options: [.atomic, .completeFileProtection])
    }

    // MARK: Apply

    @discardableResult
    static func apply(project: PatchProject, basePath: String) throws -> PatchTransaction {
        let trimmed = basePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PatchEngineError.emptyBasePath }

        let expanded = NSString(string: trimmed).expandingTildeInPath
        let base = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: base.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw PatchEngineError.baseNotDirectory
        }
        guard !project.rules.isEmpty || !project.directories.isEmpty else {
            throw PatchEngineError.nothingToApply
        }

        let transactionID = UUID()
        let backupDir = backupsRoot.appendingPathComponent(transactionID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        var entries: [BackupEntry] = []
        var createdDirectories: Set<String> = []

        do {
            for directory in project.directories {
                let target = try resolvedURL(base: base, relative: directory.relativePath, filename: nil)
                var made: [String] = []
                try ensureParentDirectory(for: target, base: base, created: &made)
                createdDirectories.formUnion(made)
                if !FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                    createdDirectories.insert(target.path)
                }
            }

            for (index, rule) in project.rules.enumerated() {
                let target = try resolvedURL(
                    base: base,
                    relative: rule.relativePath,
                    filename: rule.replacementFilename
                )
                var made: [String] = []
                try ensureParentDirectory(for: target, base: base, created: &made)
                createdDirectories.formUnion(made)

                var hadOriginal = false
                var backupName: String? = nil
                if FileManager.default.fileExists(atPath: target.path) {
                    let name = String(index)
                    try FileManager.default.copyItem(at: target, to: backupDir.appendingPathComponent(name))
                    hadOriginal = true
                    backupName = name
                }

                try rule.replacementData.write(to: target, options: .atomic)
                entries.append(BackupEntry(
                    relativePath: joined(relative: rule.relativePath, filename: rule.replacementFilename),
                    backupFileName: backupName,
                    hadOriginal: hadOriginal
                ))
            }

            let transaction = PatchTransaction(
                id: transactionID,
                packageID: project.id,
                patchName: project.name,
                basePath: expanded,
                appliedAt: Date(),
                entries: entries,
                createdDirectories: createdDirectories.sorted()
            )
            var all = loadTransactions()
            all.insert(transaction, at: 0)
            saveTransactions(all)
            return transaction
        } catch {
            try? FileManager.default.removeItem(at: backupDir)
            throw error
        }
    }

    // MARK: Restore

    @discardableResult
    static func restore(transaction: PatchTransaction) throws -> TimeInterval {
        let startedAt = Date()
        let fileManager = FileManager.default
        let base = URL(fileURLWithPath: transaction.basePath, isDirectory: true).standardizedFileURL
        let backupDir = backupsRoot.appendingPathComponent(transaction.id.uuidString, isDirectory: true)

        for entry in transaction.entries.reversed() {
            let target = base.appendingPathComponent(entry.relativePath, isDirectory: false)
                .standardizedFileURL
            guard target.path.hasPrefix(base.path + "/") else {
                throw PatchEngineError.unsafePath
            }

            if entry.hadOriginal, let name = entry.backupFileName {
                let backup = backupDir.appendingPathComponent(name, isDirectory: false)
                guard fileManager.fileExists(atPath: backup.path) else {
                    throw PatchEngineError.restoreFailed("thiếu bản sao lưu \(name)")
                }
                if fileManager.fileExists(atPath: target.path) {
                    try? fileManager.removeItem(at: target)
                }
                do {
                    try fileManager.copyItem(at: backup, to: target)
                } catch {
                    throw PatchEngineError.restoreFailed(error.localizedDescription)
                }
            } else if fileManager.fileExists(atPath: target.path) {
                try? fileManager.removeItem(at: target)
            }
        }

        // Remove only directories this apply created, deepest first, and only if empty.
        for path in transaction.createdDirectories.sorted(by: { $0.count > $1.count }) {
            guard path.hasPrefix(base.path + "/") else { continue }
            if let contents = try? fileManager.contentsOfDirectory(atPath: path), contents.isEmpty {
                try? fileManager.removeItem(atPath: path)
            }
        }

        try? fileManager.removeItem(at: backupDir)
        saveTransactions(loadTransactions().filter { $0.id != transaction.id })
        return Date().timeIntervalSince(startedAt)
    }

    static func discardRecord(_ transaction: PatchTransaction) {
        try? FileManager.default.removeItem(
            at: backupsRoot.appendingPathComponent(transaction.id.uuidString, isDirectory: true)
        )
        saveTransactions(loadTransactions().filter { $0.id != transaction.id })
    }

    // MARK: Path helpers

    private static func joined(relative: String, filename: String) -> String {
        [relative.trimmingCharacters(in: .whitespacesAndNewlines), filename]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    private static func resolvedURL(base: URL, relative: String, filename: String?) throws -> URL {
        let trimmed = relative.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("/"),
              !trimmed.contains("\\"),
              !trimmed.contains("//")
        else {
            throw PatchEngineError.unsafePath
        }

        let components = trimmed.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw PatchEngineError.unsafePath
        }

        var url = base
        for component in components {
            url = url.appendingPathComponent(component, isDirectory: true)
        }
        if let filename {
            guard !filename.isEmpty,
                  filename != ".",
                  filename != "..",
                  !filename.contains("/"),
                  !filename.contains("\\")
            else {
                throw PatchEngineError.unsafePath
            }
            url = url.appendingPathComponent(filename, isDirectory: false)
        }

        let result = url.standardizedFileURL
        guard result.path.hasPrefix(base.path + "/") else {
            throw PatchEngineError.unsafePath
        }
        return result
    }

    private static func ensureParentDirectory(
        for url: URL,
        base: URL,
        created: inout [String]
    ) throws {
        let parent = url.deletingLastPathComponent()
        var current = parent
        var missing: [String] = []
        while current.path != base.path {
            if !FileManager.default.fileExists(atPath: current.path) {
                missing.append(current.path)
            }
            let upper = current.deletingLastPathComponent()
            if upper.path == current.path { break }
            current = upper
        }
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        created.append(contentsOf: missing)
    }
}
