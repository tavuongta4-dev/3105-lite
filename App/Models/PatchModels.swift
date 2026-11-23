import Foundation

// MARK: - Patch project (compatible with the .3105 v1 payload)

struct PatchRule: Codable, Identifiable, Hashable {
    var id: UUID
    var bundleID: String
    var relativePath: String
    var replacementFilename: String
    var replacementData: Data

    init(
        id: UUID = UUID(),
        bundleID: String,
        relativePath: String,
        replacementFilename: String,
        replacementData: Data
    ) {
        self.id = id
        self.bundleID = bundleID
        self.relativePath = relativePath
        self.replacementFilename = replacementFilename
        self.replacementData = replacementData
    }

    private enum CodingKeys: String, CodingKey {
        case id, bundleID, relativePath, replacementFilename, replacementData
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bundleID = try c.decodeIfPresent(String.self, forKey: .bundleID) ?? ""
        relativePath = try c.decodeIfPresent(String.self, forKey: .relativePath) ?? ""
        replacementFilename = try c.decodeIfPresent(String.self, forKey: .replacementFilename) ?? ""
        replacementData = try c.decodeIfPresent(Data.self, forKey: .replacementData) ?? Data()
    }
}

struct PatchDirectory: Codable, Identifiable, Hashable {
    var id: UUID
    var bundleID: String
    var relativePath: String

    init(id: UUID = UUID(), bundleID: String, relativePath: String) {
        self.id = id
        self.bundleID = bundleID
        self.relativePath = relativePath
    }

    private enum CodingKeys: String, CodingKey {
        case id, bundleID, relativePath
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bundleID = try c.decodeIfPresent(String.self, forKey: .bundleID) ?? ""
        relativePath = try c.decodeIfPresent(String.self, forKey: .relativePath) ?? ""
    }
}

struct PatchProject: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var bundleIdentifiers: [String]
    var directories: [PatchDirectory]
    var rules: [PatchRule]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        bundleIdentifiers: [String] = [],
        directories: [PatchDirectory] = [],
        rules: [PatchRule]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.bundleIdentifiers = bundleIdentifiers
        self.directories = directories
        self.rules = rules
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, updatedAt, bundleIdentifiers, directories, rules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Không tên"
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        bundleIdentifiers = try c.decodeIfPresent([String].self, forKey: .bundleIdentifiers) ?? []
        directories = try c.decodeIfPresent([PatchDirectory].self, forKey: .directories) ?? []
        rules = try c.decodeIfPresent([PatchRule].self, forKey: .rules) ?? []
    }

    var allBundleIdentifiers: [String] {
        var seen = Set<String>()
        return (bundleIdentifiers + directories.map(\.bundleID) + rules.map(\.bundleID))
            .filter { seen.insert($0).inserted }
    }
}

// MARK: - Package level types

struct PatchPackageSummary: Identifiable, Equatable {
    var id: UUID { packageID }
    let packageID: UUID
    let schemaVersion: Int
    let isPasswordProtected: Bool
}

struct DecodedPatch {
    let project: PatchProject
    let contentKey: Data
}

enum PatchError: LocalizedError, Equatable {
    case unsupportedFormat
    case unsupportedVersion
    case invalidPasswordOrCorrupted
    case keyDerivationFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Đây không phải tệp patch .3105 hợp lệ (sai magic header)."
        case .unsupportedVersion:
            return "Phiên bản patch không được hỗ trợ (hỗ trợ schema v1, v2 và v3)."
        case .invalidPasswordOrCorrupted:
            return "Sai mật khẩu hoặc tệp patch bị hỏng."
        case .keyDerivationFailed:
            return "Không thể tạo khóa từ mật khẩu."
        }
    }
}
