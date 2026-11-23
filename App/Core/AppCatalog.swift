import Foundation

enum AppEntryKind: String {
    case application
    case appGroup
}

struct AppEntry: Identifiable, Hashable {
    var id: String { "\(kind.rawValue)-\(bundleID)-\(path)" }
    let bundleID: String
    let name: String
    let path: String
    let kind: AppEntryKind
}

/// Lists app data containers the same way 3105 does: by bundle identifier instead of
/// the per-device container UUID. When the container root cannot be read (sandbox),
/// it falls back to the installed-app list so the UI is still useful.
enum AppCatalog {
    private static let applicationRoot = "/private/var/mobile/Containers/Data/Application"
    private static let appGroupRoot = "/private/var/mobile/Containers/Shared/AppGroup"
    private static let metadataName = ".com.apple.mobile_container_manager.metadata.plist"

    static func load() -> [AppEntry] {
        let names = installedAppNames()
        var entries: [AppEntry] = []

        if let uuids = try? FileManager.default.contentsOfDirectory(atPath: applicationRoot) {
            for uuid in uuids {
                let container = "\(applicationRoot)/\(uuid)"
                guard let bundleID = metadataIdentifier(at: container) else { continue }
                entries.append(AppEntry(
                    bundleID: bundleID,
                    name: names[bundleID] ?? bundleID,
                    path: container,
                    kind: .application
                ))
            }
        }

        if let groups = try? FileManager.default.contentsOfDirectory(atPath: appGroupRoot) {
            for group in groups {
                let container = "\(appGroupRoot)/\(group)"
                guard let bundleID = metadataIdentifier(at: container) else { continue }
                entries.append(AppEntry(
                    bundleID: bundleID,
                    name: bundleID,
                    path: container,
                    kind: .appGroup
                ))
            }
        }

        // Fallback: no container access — show installed apps with an empty path.
        if entries.isEmpty {
            for (bundleID, name) in names {
                entries.append(AppEntry(
                    bundleID: bundleID,
                    name: name,
                    path: "",
                    kind: .application
                ))
            }
        }

        return entries.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func metadataIdentifier(at container: String) -> String? {
        let plistPath = "\(container)/\(metadataName)"
        guard let dict = NSDictionary(contentsOfFile: plistPath) else { return nil }
        return dict["MCMMetadataIdentifier"] as? String
    }

    private static func installedAppNames() -> [String: String] {
        var result: [String: String] = [:]
        for app in workspaceApplications() {
            guard let bundleID = app.value(forKey: "bundleIdentifier") as? String,
                  !bundleID.isEmpty
            else { continue }
            let name = (app.value(forKey: "localizedName") as? String)
                ?? (app.value(forKey: "bundleDisplayName") as? String)
                ?? bundleID
            result[bundleID] = name
        }
        return result
    }

    private static func workspaceApplications() -> [NSObject] {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = workspaceClass
                .perform(NSSelectorFromString("defaultWorkspace"))?
                .takeUnretainedValue() as? NSObject,
              let apps = workspace
                .perform(NSSelectorFromString("allInstalledApplications"))?
                .takeUnretainedValue() as? [NSObject]
        else {
            return []
        }
        return apps
    }
}
