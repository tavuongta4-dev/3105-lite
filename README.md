# 3105 Lite

App iOS (SwiftUI) quản lý patch `.3105` theo hướng tối giản, lấy cảm hứng từ [3105](https://github.com/YangJiiii/3105) (GPL-3.0). Tập trung đúng 5 yêu cầu:

1. Đọc tệp `.3105` legacy **schema v1** (có hoặc không có mật khẩu; cũng hỗ trợ v2).
2. Dán **path đích** để áp patch.
3. **Khôi phục file gốc cực nhanh** (thường < 0,1 giây; hiển thị thời gian thực tế).
4. **Lưu lịch sử path** đã dùng.
5. Build IPA **trên GitHub Actions**, bạn chỉ việc push bằng GitHub Desktop.

> ⚠️ Chỉ dùng trên thiết bị và dữ liệu bạn sở hữu. Luôn sao lưu trước khi áp patch. App không chứa exploit/jailbreak; một số container hệ thống có thể không ghi được nếu thiếu entitlements.

---

## 1. Cấu trúc dự án

```
.
├── .github/workflows/build-ipa.yml   # GitHub Actions → unsigned IPA
├── project.yml                       # XcodeGen spec (không cần commit .xcodeproj)
├── App/
│   ├── 3105LiteApp.swift
│   ├── Info.plist
│   ├── Assets.xcassets/
│   ├── Models/PatchModels.swift
│   ├── Core/
│   │   ├── PatchPackageCodec.swift   # giải mã .3105 v1/v2 + mật khẩu
│   │   ├── KeychainStore.swift       # lưu content key → restore không cần nhập lại pass
│   │   ├── PathHistoryStore.swift    # lịch sử path
│   │   └── PatchFileEngine.swift     # apply / backup / restore
│   ├── State/AppState.swift
│   └── Views/*.swift
└── Tools/make_sample_patch.swift      # tạo .3105 v1 để test (chạy trên macOS)
```

### Cách hoạt động của path đích

Mỗi quy tắc trong patch có `bundleID`, `relativePath` và `replacementFilename`. App ghép:

```
<path đích bạn dán> / <relativePath> / <replacementFilename>
```

Ví dụ: dán `/private/var/mobile/Containers/Data/Application/XXXX/Documents` rồi patch có `relativePath = "config"` và file `settings.json` → ghi vào `.../Documents/config/settings.json`.

- Trước khi ghi, app **copy file gốc** vào `Application Support/PatchEngine/Backups/<transaction>/`.
- Nhấn **Khôi phục ngay** → copy các bản sao về đúng chỗ, xóa file patch thêm mới, dọn thư mục rỗng do patch tạo. Không giải mã lại gói, không nhập lại mật khẩu.

---

## 2. Push dự án lên GitHub bằng GitHub Desktop

1. Vào [github.com/new](https://github.com/new) → tạo repo mới, ví dụ `3105-lite`.
   - Chọn **Public** hoặc **Private** đều được.
   - **Không** tick “Add a README file” (repo phải trống).
2. Mở **GitHub Desktop** → `File → Add Local Repository…` → chọn thư mục này (nếu Desktop báo “not a Git repository”, bấm **Create a repository** tại đây).
3. Ở khung **Summary** gõ `Initial 3105 Lite source` → bấm **Commit to main**.
4. Bấm **Publish repository** → chọn đúng owner/name `3105-lite` → **Publish**.
   - Nếu repo đã tạo trên web: bấm **Publish repository** rồi chọn repo đó; hoặc dùng `git remote add origin https://github.com/<you>/3105-lite.git` trong tab Terminal của Desktop.
5. Mỗi lần sửa code: commit trong GitHub Desktop rồi bấm **Push origin**.

> Nhánh kích hoạt build: `main` hoặc `master`. Nếu bạn dùng tên nhánh khác, sửa dòng `branches:` trong `.github/workflows/build-ipa.yml`.

---

## 3. Build IPA trên GitHub

1. Sau khi push, vào repo trên web → tab **Actions**.
2. Chọn workflow **Build unsigned IPA** → bấm **Run workflow** (hoặc push cũng tự chạy).
3. Đợi ~3–6 phút. Vào run vừa tạo → phần **Artifacts** → tải `3105Lite-unsigned-IPA`.
4. Giải nén được `3105Lite-unsigned.ipa` + file `.sha256` để kiểm tra checksum.

### Ký lại IPA

IPA được build **unsigned**. Dùng ESign / enterprise certificate để ký lại:

- Bundle identifier: `com.patchlite.app` (có thể đổi trong `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER`).
- Tên app hiển thị: `3105 Lite`.
- Không hỗ trợ SideStore / AltStore / 3uTools / LiveContainer nếu bạn cần quyền truy cập container thật.

---

## 3b. Nhập patch cũ khi file không chọn được trong picker

- Tab **Ứng dụng** liệt kê dữ liệu ứng dụng theo **bundle ID** (giống 3105), có ô tìm kiếm, hai chế độ Application / App Group. Chạm vào một app để duyệt thư mục dữ liệu, rồi bấm **Dùng làm path đích**.
- Nếu file `.3105` nằm trong trình duyệt Tệp của 3105: chọn file → **Chia sẻ** → chọn **3105 Lite** (app đã đăng ký mở tệp `.3105`).
- Nếu vẫn lỗi, tab **Patch** có phần **Chẩn đoán tệp** hiện đuôi file, kích thước và 10 byte đầu để đối chiếu magic `3105PATCH\0`.
- Trên iOS 17–18, quyền đọc container hệ thống phụ thuộc vào cách ký/entitlements; khi không đọc được, app vẫn liệt kê app đã cài và bạn dán path đích thủ công.

## 4. Tạo patch mẫu để test

Trên máy có Swift (macOS):

```bash
# không mật khẩu
swift Tools/make_sample_patch.swift sample.3105

# có mật khẩu
swift Tools/make_sample_patch.swift locked.3105 "mat-khau"
```

Sau đó:
- Mở app → **Chọn tệp .3105** → chọn file vừa tạo.
- Nếu có mật khẩu → nhập `mat-khau` → patch được mở và khóa được lưu vào Keychain.
- Dán một thư mục tồn tại (ví dụ tạo thư mục trên thiết bị qua Files) vào ô **Path đích** → **Áp dụng patch**.
- Vào tab **Khôi phục** → **Khôi phục ngay** để xem thời gian thực thi.

Bạn cũng có thể copy file `.3105` vào app qua **Files → On My iPhone → 3105 Lite** (đã bật `UIFileSharingEnabled`).

---

## 5. Đổi tên / bundle ID / phiên bản

Sửa trong `project.yml`:

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.patchlite.app
```

Sửa `CFBundleShortVersionString` / `CFBundleVersion` trong `App/Info.plist`.

Muốn đổi tên target, sửa `name:` và `targets:` trong `project.yml` **và** `-project`, `-scheme`, tên `.app` trong `.github/workflows/build-ipa.yml`.

---

## 6. Chi tiết kỹ thuật

Xem [docs/PATCH_FORMAT.md](docs/PATCH_FORMAT.md) cho mô tả nhị phân của `.3105` v1/v2 (magic, Envelope, AES-GCM AAD, PBKDF2, digests).

## License

Mã nguồn tự viết cho dự án này. Phần định dạng `.3105` được suy ra từ dự án [3105](https://github.com/YangJiiii/3105) (GPL-3.0) để tương thích; vui lòng giữ ghi nhận nếu bạn phát hành lại.
