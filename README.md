# 3105 Lite (nền 3106)

iOS app quản lý dữ liệu ứng dụng, patch `.3105`/`.3106`, file, dọn dẹp và hơn thế nữa — xây dựng từ nguồn [QuinnTang74/3106](https://github.com/QuinnTang74/3106) (GPL-3.0, bản 3.2.8), đã đổi tên/bundle ID sang `3105 Lite` / `com.patchlite.app`.

> ⚠️ Chỉ dùng trên thiết bị và dữ liệu bạn sở hữu. Luôn sao lưu trước khi thay đổi dữ liệu ứng dụng.

## Tại sao chuyển sang nền 3106

Bản SwiftUI tự viết trước đó (giữ trong `legacy-lite/`) chỉ là trình quản lý patch offline: nó không có exploit nên **không liệt kê được container app**. 3106 có chuỗi truy cập thật:

| iOS | Backend | Yêu cầu |
|---|---|---|
| 17.0–18.7.1 | kernel chain | bấm **Unlock** lần đầu |
| 26.0–26.6.1 | `bad_query` | — |
| 26.7–27.2 / 27.3 beta 1 | `worse_query` | **App Group entitlement** |

Không có “pairing file” nào — App Group được công cụ ký (AltStore / SideStore / Sideloadly / Apple ID) tự tạo và app đọc lúc chạy. Ký bằng wildcard `.p12` → `worse_query` báo “No App Group”.

## Tính năng chính

- Duyệt dữ liệu ứng dụng theo bundle ID (Application / App Group), tìm kiếm, mở thư mục, xem/sửa file.
- Patch `.3105` / `.3106` schema v1–v3, có/không mật khẩu; áp dụng, sao lưu và khôi phục.
- Thay thế file tùy ý, backup, restore, preset.
- Cleaner, wallpaper `.tendies`, dialer theme, MobileGestalt, region, v.v. (xem CHANGELOG của upstream).

## Build IPA trên GitHub

1. Push lên `main` (hoặc vào Actions → **Run workflow**).
2. Workflow `Build unsigned IPA` chạy trên `macos-15`, build `ThreeOneOSSix.xcodeproj` / scheme `3106` với `CODE_SIGNING_ALLOWED=NO`.
3. Tải artifact `3105Lite-unsigned-IPA` → `3105Lite-unsigned.ipa`.
4. Ký lại bằng ESign/AltStore/SideStore với **App Group capability**, cài lên máy.

Release công khai: https://github.com/tavuongta4-dev/3105-lite/releases

## Cấu trúc

```
ThreeOneOSSix/            # mã nguồn 3106 đã đổi tên (App, exploit, kexploit, helpers, views)
ThreeOneOSSix.xcodeproj/  # project gốc của 3106 (giữ nguyên cấu hình build exploit)
Tests/                    # policy tests của upstream
Tools/                    # tiện ích tạo patch mẫu
docs/                     # tài liệu upstream + PATCH_FORMAT.md
legacy-lite/              # bản SwiftUI cũ (không biên dịch)
LICENSE, NOTICE.md        # GPL-3.0 và attribution của upstream
MODIFICATIONS.md          # liệt kê các thay đổi của repo này
```

## Giấy phép

GPL-3.0. Toàn bộ bản quyền và thông báo của upstream cùng các thành phần bên thứ ba nằm trong `LICENSE` và `NOTICE.md`. Các thay đổi được liệt kê trong `MODIFICATIONS.md`.
