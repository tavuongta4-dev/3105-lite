import SwiftUI

struct PasswordSheet: View {
    let onSubmit: (String) -> Void
    @State private var password = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Mật khẩu patch", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Gói patch được mã hóa. Khóa đã mở sẽ được lưu lại để những lần khôi phục sau không cần nhập lại mật khẩu.")
                }
                Section {
                    Button("Mở") {
                        onSubmit(password)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(password.isEmpty)
                }
            }
            .navigationTitle("Mật khẩu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
