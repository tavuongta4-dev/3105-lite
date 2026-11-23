import SwiftUI

struct AboutView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.orange)
                    Text("3105 Lite").font(.title2.weight(.bold))
                    Text("Patch manager gọn nhẹ cho iOS · SwiftUI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("Khả năng") {
                Label("Đọc patch .3105 / .3106 schema v1, v2, v3", systemImage: "checkmark.circle")
                Label("Patch có mật khẩu hoặc không có mật khẩu", systemImage: "checkmark.circle")
                Label("Dán path đích, tự ghép relativePath + tên file", systemImage: "checkmark.circle")
                Label("Sao lưu file gốc và khôi phục cực nhanh", systemImage: "checkmark.circle")
                Label("Lưu lịch sử path đã dùng", systemImage: "checkmark.circle")
                Label("Duyệt Application / App Group theo bundle ID", systemImage: "checkmark.circle")
                Label("Nhận patch qua Share sheet từ app khác", systemImage: "checkmark.circle")
            }
            .font(.subheadline)

            Section("Định dạng .3105") {
                Text("Tệp gồm magic \"3105PATCH\\0\" + binary plist Envelope. Payload được mã hóa AES-256-GCM; mật khẩu dùng PBKDF2-HMAC-SHA256 (100.000–1.000.000 vòng). Khóa đã mở được lưu trong Keychain.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Lưu ý") {
                Text("Chỉ dùng trên thiết bị và dữ liệu bạn sở hữu. Luôn sao lưu trước khi áp dụng patch. App không chứa exploit hay jailbreak, vì vậy một số container hệ thống có thể không truy cập được nếu thiếu entitlements phù hợp.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Quên khóa patch đã lưu") { app.forgetSavedKey() }
            }
        }
        .navigationTitle("Thông tin")
    }
}
