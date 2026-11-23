import SwiftUI

struct RestoreView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        List {
            Section {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Khôi phục nhanh", systemImage: "bolt.horizontal.circle")
                            .font(.headline)
                        Text("Chạm để trả lại file gốc đã được sao lưu. Không cần mở lại patch hay nhập mật khẩu.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if let message = app.errorMessage {
                Section { StatusBanner(message: message, isError: true) }
            }
            if let message = app.successMessage {
                Section { StatusBanner(message: message, isError: false) }
            }

            if app.transactions.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Chưa có patch nào được áp dụng",
                        systemImage: "arrow.uturn.backward",
                        description: Text("Áp dụng một patch ở tab Patch để tạo bản sao lưu có thể khôi phục.")
                    )
                }
            } else {
                Section("Đã áp dụng (\(app.transactions.count))") {
                    ForEach(app.transactions) { transaction in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.zipper")
                                Text(transaction.patchName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(transaction.appliedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(transaction.basePath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            Text("\(transaction.entries.count) file · \(transaction.createdDirectories.count) thư mục mới")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

                            HStack {
                                Button {
                                    app.restore(transaction)
                                } label: {
                                    Label("Khôi phục ngay", systemImage: "arrow.uturn.backward")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                Button(role: .destructive) {
                                    app.discardRecord(transaction)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Khôi phục")
    }
}
