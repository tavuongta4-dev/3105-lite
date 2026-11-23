import SwiftUI

struct ApplicationsView: View {
    @EnvironmentObject var app: AppState
    @State private var entries: [AppEntry] = []
    @State private var searchText = ""
    @State private var kind: AppEntryKind = .application

    private var filtered: [AppEntry] {
        let scoped = entries.filter { $0.kind == kind }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return scoped
        }
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return scoped.filter {
            $0.name.lowercased().contains(needle) || $0.bundleID.lowercased().contains(needle)
        }
    }

    var body: some View {
        List {
            Section {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Dữ liệu ứng dụng", systemImage: "app.badge")
                            .font(.headline)
                        Text("Liệt kê theo bundle identifier. Chọn một ứng dụng để duyệt dữ liệu và dùng làm path đích.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                Picker("Loại", selection: $kind) {
                    Text("Application").tag(AppEntryKind.application)
                    Text("App Group").tag(AppEntryKind.appGroup)
                }
                .pickerStyle(.segmented)

                TextField("Tìm ứng dụng", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("\(filtered.count) dữ liệu ứng dụng") {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "Không có dữ liệu",
                        systemImage: "magnifyingglass",
                        description: Text("Thử từ khóa khác hoặc làm mới danh sách.")
                    )
                }
                ForEach(filtered) { entry in
                    NavigationLink(value: entry) {
                        HStack(spacing: 12) {
                            Image(systemName: entry.kind == .appGroup ? "folder.badge.person.crop" : "app.badge")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(entry.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Ứng dụng")
        .toolbar {
            Button {
                entries = AppCatalog.load()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
        .navigationDestination(for: AppEntry.self) { entry in
            AppDetailView(entry: entry)
        }
        .task {
            if entries.isEmpty { entries = AppCatalog.load() }
        }
    }
}

struct AppDetailView: View {
    let entry: AppEntry
    @EnvironmentObject var app: AppState

    var body: some View {
        List {
            Section("Thông tin") {
                Label(entry.name, systemImage: "app.badge")
                Label(entry.bundleID, systemImage: "number")
                    .textSelection(.enabled)
                if entry.path.isEmpty {
                    Text("Không đọc được container của ứng dụng này trên thiết bị. Bạn vẫn có thể dán path đích thủ công ở tab Patch.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(entry.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if !entry.path.isEmpty {
                Section("Dữ liệu") {
                    NavigationLink(value: FileNode(
                        name: entry.name,
                        path: entry.path,
                        isDirectory: true,
                        size: 0
                    )) {
                        Label("Mở thư mục dữ liệu", systemImage: "folder")
                    }
                }
            }

            Section {
                Button {
                    if !entry.path.isEmpty { app.usePath(entry.path) }
                    app.selectedTab = 0
                } label: {
                    Label("Dùng làm path đích", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(entry.path.isEmpty)
            }
        }
        .navigationTitle(entry.name)
        .navigationDestination(for: FileNode.self) { node in
            FileFolderView(node: node)
        }
    }
}

struct FileFolderView: View {
    let node: FileNode
    @EnvironmentObject var app: AppState
    @State private var nodes: [FileNode] = []

    var body: some View {
        List {
            Section {
                Button {
                    app.usePath(node.path)
                    app.selectedTab = 0
                } label: {
                    Label("Dùng thư mục này làm path đích", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Section("\(nodes.count) mục") {
                ForEach(nodes) { child in
                    if child.isDirectory {
                        NavigationLink(value: child) { row(child) }
                    } else {
                        row(child)
                    }
                }
            }
        }
        .navigationTitle(node.name)
        .onAppear { nodes = FileBrowser.list(at: node.path) }
    }

    private func row(_ node: FileNode) -> some View {
        HStack(spacing: 10) {
            Image(systemName: node.isDirectory ? "folder" : "doc")
                .foregroundStyle(node.isDirectory ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.subheadline)
                if !node.isDirectory {
                    Text(formattedSize(Int(node.size)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
