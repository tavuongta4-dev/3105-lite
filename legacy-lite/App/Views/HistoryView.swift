import SwiftUI
import UIKit

struct HistoryView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        List {
            Section {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Lịch sử path", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                        Text("Mọi path đích đã dùng đều được lưu lại. Chạm để điền lại vào tab Patch.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if app.pathHistory.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Chưa có path nào",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Path bạn nhập khi áp dụng patch sẽ xuất hiện ở đây.")
                    )
                }
            } else {
                ForEach(app.pathHistory) { record in
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.path)
                                .font(.subheadline)
                                .lineLimit(2)
                                .textSelection(.enabled)
                            Text("Dùng \(record.useCount) lần · \(record.lastUsedAt, style: .relative)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            UIPasteboard.general.string = record.path
                            app.usePath(record.path)
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            app.removePath(record.id)
                        } label: {
                            Label("Xóa", systemImage: "trash")
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        app.clearPathHistory()
                    } label: {
                        Label("Xóa toàn bộ lịch sử path", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Path")
    }
}
