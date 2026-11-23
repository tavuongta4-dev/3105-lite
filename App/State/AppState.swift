import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var importedData: Data?
    @Published var importedFileName: String = ""
    @Published var summary: PatchPackageSummary?
    @Published var decoded: DecodedPatch?
    @Published var needsPassword = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var basePath: String = ""
    @Published var pathHistory: [PathRecord] = PathHistoryStore.load()
    @Published var transactions: [PatchTransaction] = PatchFileEngine.loadTransactions()
    @Published var lastRestoreDuration: TimeInterval?
    @Published var importDiagnostic: String?
    @Published var selectedTab = 0

    // MARK: Messages

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func clearAll() {
        importedData = nil
        importedFileName = ""
        summary = nil
        decoded = nil
        needsPassword = false
        importDiagnostic = nil
        clearMessages()
    }

    // MARK: Import / unlock

    func importFile(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            importPackage(data: data, fileName: url.lastPathComponent)
        } catch {
            errorMessage = "Không đọc được tệp: \(error.localizedDescription)"
        }
    }

    func importPackage(data: Data, fileName: String) {
        clearMessages()
        clearAll()
        clearMessages()

        do {
            let inspected = try PatchPackageCodec.inspect(data)
            importedData = data
            importedFileName = fileName
            summary = inspected

            if !inspected.isPasswordProtected {
                try finishDecode(data, password: nil, cachedHint: "")
            } else if let cachedKey = KeychainStore.load(for: inspected.packageID),
                      let unlocked = try? PatchPackageCodec.decode(data, contentKey: cachedKey) {
                decoded = unlocked
                successMessage = "Đã mở '\(unlocked.project.name)' bằng khóa đã lưu."
            } else {
                needsPassword = true
            }
        } catch {
            let magic = data.prefix(10).map { String(format: "%02x", $0) }.joined()
            importDiagnostic = "Tệp: \(fileName) · \(data.count) bytes · đuôi: \((fileName as NSString).pathExtension) · 10 byte đầu: \(magic)"
            errorMessage = error.localizedDescription
        }
    }

    func submitPassword(_ password: String) {
        guard let data = importedData else { return }
        clearMessages()
        do {
            try finishDecode(data, password: password, cachedHint: "Mở patch thành công")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishDecode(_ data: Data, password: String?, cachedHint: String) throws {
        let unlocked = try PatchPackageCodec.decode(data, password: password)
        decoded = unlocked
        needsPassword = false
        if let inspected = summary {
            KeychainStore.save(unlocked.contentKey, for: inspected.packageID)
        }
        if !cachedHint.isEmpty {
            successMessage = "\(cachedHint): \(unlocked.project.name)."
        }
    }

    // MARK: Apply / restore

    func applyPatch() {
        guard let project = decoded?.project else {
            errorMessage = "Chưa mở patch nào."
            return
        }
        clearMessages()
        do {
            let transaction = try PatchFileEngine.apply(project: project, basePath: basePath)
            pathHistory = PathHistoryStore.record(basePath)
            transactions = PatchFileEngine.loadTransactions()
            successMessage = "Đã áp dụng \(transaction.entries.count) file vào \(transaction.basePath)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore(_ transaction: PatchTransaction) {
        clearMessages()
        lastRestoreDuration = nil
        do {
            let elapsed = try PatchFileEngine.restore(transaction: transaction)
            transactions = PatchFileEngine.loadTransactions()
            lastRestoreDuration = elapsed
            successMessage = String(format: "Khôi phục hoàn tất trong %.3f giây.", elapsed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func discardRecord(_ transaction: PatchTransaction) {
        PatchFileEngine.discardRecord(transaction)
        transactions = PatchFileEngine.loadTransactions()
    }

    // MARK: Path history

    func usePath(_ path: String) {
        basePath = path
        pathHistory = PathHistoryStore.record(path)
    }

    func removePath(_ id: UUID) {
        PathHistoryStore.remove(id: id)
        pathHistory = PathHistoryStore.load()
    }

    func clearPathHistory() {
        PathHistoryStore.clear()
        pathHistory = []
    }

    func forgetSavedKey() {
        guard let id = summary?.packageID else { return }
        KeychainStore.delete(for: id)
        decoded = nil
        needsPassword = true
        successMessage = "Đã xóa khóa đã lưu. Nhập lại mật khẩu để mở patch."
    }
}
