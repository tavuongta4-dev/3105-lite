import Foundation

struct FileNode: Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
}

enum FileBrowser {
    static func list(at path: String) -> [FileNode] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return []
        }
        let fileManager = FileManager.default
        var nodes: [FileNode] = []
        for name in names {
            let fullPath = (path as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory)
            let size = (try? fileManager.attributesOfItem(atPath: fullPath)[.size] as? NSNumber)?
                .int64Value ?? 0
            nodes.append(FileNode(
                name: name,
                path: fullPath,
                isDirectory: exists && isDirectory.boolValue,
                size: size
            ))
        }
        return nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
