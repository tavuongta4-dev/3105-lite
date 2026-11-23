import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PatchView: View {
    @EnvironmentObject var app: AppState
    @State private var showingImporter = false
    @State private var showingPassword = false

    var body: some View {
        List {
            Section {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Trình quản lý patch .3105", systemImage: "square.stack.3d.up.fill")
                            .font(.headline)
                        Text("Mở patch legacy v1 (có hoặc không có mật khẩu), dán path đích và áp dụng. Khôi phục luôn sẵn sàng trong một chạm.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                Button {
                    showingImporter = true
                } label: {
                    Label("Chọn tệp .3105", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if !app.importedFileName.isEmpty {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(app.importedFileName)
                            .lineLimit(1)
                        Spacer()
                        Button("Xóa") { app.clearAll() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            if let message = app.errorMessage {
                Section { StatusBanner(message: message, isError: true) }
            }
            if let message = app.successMessage {
                Section { StatusBanner(message: message, isError: false) }
            }

            if let summary = app.summary {
                Section("Thông tin gói") {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            detailRow("Schema", "v\(summary.schemaVersion)\(summary.schemaVersion == 1 ? " (legacy)" : "")")
                            detailRow("Mật khẩu", summary.isPasswordProtected ? "Có" : "Không")
                            detailRow("Package ID", summary.packageID.uuidString)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            if app.needsPassword {
                Section {
                    Button {
                        showingPassword = true
                    } label: {
                        Label("Nhập mật khẩu để mở patch", systemImage: "lock")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let decoded = app.decoded {
                Section("Quy tắc (\(decoded.project.rules.count))") {
                    if decoded.project.rules.isEmpty {
                        Text("Gói không có file thay thế.").foregroundStyle(.secondary)
                    }
                    ForEach(decoded.project.rules) { rule in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.replacementFilename)
                                .font(.subheadline.weight(.semibold))
                            Text("\(rule.bundleID) · \(rule.relativePath)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formattedSize(rule.replacementData.count))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Path đích") {
                    TextField("Dán thư mục gốc, ví dụ /var/mobile/Containers/.../Data", text: $app.basePath)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline)

                    HStack {
                        Button {
                            app.basePath = UIPasteboard.general.string ?? app.basePath
                        } label: {
                            Label("Dán", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)

                        Button("Dùng path gần nhất") {
                            if let first = app.pathHistory.first { app.usePath(first.path) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(app.pathHistory.isEmpty)
                    }

                    if !app.pathHistory.isEmpty {
                        ForEach(app.pathHistory.prefix(4)) { record in
                            Button {
                                app.usePath(record.path)
                            } label: {
                                HStack {
                                    Image(systemName: "clock")
                                    Text(record.path)
                                        .lineLimit(1)
                                        .font(.caption)
                                    Spacer()
                                    Text("\(record.useCount)x")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        app.applyPatch()
                    } label: {
                        Label("Áp dụng patch", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(app.basePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Mỗi quy tắc được ghi vào <path đích>/<relativePath>/<tên file>. File gốc được sao lưu trước khi ghi đè.")
                }
            }
        }
        .navigationTitle("3105 Lite")
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [UTType(filenameExtension: "3105") ?? .data, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
                        app.importPackage(data: data, fileName: url.lastPathComponent)
                    } else {
                        app.errorMessage = "Không đọc được tệp đã chọn."
                    }
                } else {
                    app.errorMessage = "Không truy cập được tệp đã chọn."
                }
            case .failure(let error):
                app.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingPassword) {
            PasswordSheet { password in
                app.submitPassword(password)
            }
        }
    }

    private func detailRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).textSelection(.enabled)
        }
        .font(.subheadline)
    }
}
