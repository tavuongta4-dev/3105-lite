# Định dạng tệp `.3105` (tương thích v1 / v2)

Tài liệu này mô tả đúng định dạng được `3105 Lite` giải mã, suy ra từ mã nguồn công khai của 3105 (`PatchPackageCodec.swift`).

## Tổng thể

```
[ 10 bytes ] magic = ASCII "3105PATCH\0"   (0x33 31 30 35 50 41 54 43 48 00)
[ N bytes  ] binary plist: Envelope
```

## Envelope (binary plist)

| Trường | Kiểu | Ghi chú |
| --- | --- | --- |
| `schemaVersion` | Int | `1` = legacy, `2` = hiện tại |
| `keyAADVersion` | Int? | Phiên bản dùng cho AAD của khóa (thường bằng schemaVersion) |
| `packageID` | UUID / String | ID gói, trùng `project.id` |
| `isPasswordProtected` | Bool | `true` → có mật khẩu |
| `kdfSalt` | Data? | 16 bytes, chỉ khi có mật khẩu |
| `kdfIterations` | Int? | 100.000 … 1.000.000 (mặc định 250.000) |
| `wrappedContentKey` | Data? | AES-GCM(contentKey, wrappingKey) khi có mật khẩu |
| `publicContentKey` | Data? | 32 bytes, khóa rõ khi KHÔNG có mật khẩu |
| `keyFingerprint` | Data | SHA-256(contentKey), 32 bytes |
| `encryptedPayload` | Data | AES-GCM(binary plist Payload) |

## Payload (binary plist, đã mã hóa)

```
Payload {
  project: PatchProject {
    id: UUID, name: String, createdAt: Date, updatedAt: Date,
    bundleIdentifiers: [String],
    directories: [ { id, bundleID, relativePath } ],
    rules: [ { id, bundleID, relativePath, replacementFilename, replacementData: Data } ]
  },
  replacementDigests: [ ruleID.uuidString : SHA256(replacementData) ]
}
```

## Mã hóa

- **KDF**: PBKDF2-HMAC-SHA256, salt 16 bytes, output 32 bytes → `wrappingKey`.
- **Cipher**: AES-256-GCM, `combined` (nonce 12 + ciphertext + tag 16).
- **AAD cho khóa**: `3105PATCH/v<keyAADVersion ?? schemaVersion>/key/<packageID>`.
- **AAD cho payload**: `3105PATCH/v<schemaVersion>/payload/<packageID>`.
- `wrappedContentKey = AES-GCM.seal(contentKey, wrappingKey, keyAAD)`.
- `encryptedPayload = AES-GCM.seal(payloadPlist, contentKey, payloadAAD)`.

## Kiểm tra khi giải mã

1. Magic phải đúng, plist parse được, schemaVersion ∈ {1, 2}.
2. Nếu có mật khẩu: derive key → mở `wrappedContentKey`; nếu sai mật khẩu → AES-GCM ném lỗi → info báo “Sai mật khẩu”.
3. `SHA256(contentKey) == keyFingerprint`.
4. Mở `encryptedPayload` → parse Payload.
5. `payload.project.id == packageID`, số digest bằng số rule, từng digest khớp `SHA256(replacementData)`.

## Khác biệt v1 vs v2

- `schemaVersion` 1 là bản legacy; payload vẫn dùng cấu trúc project như trên.
- `schemaVersion` 2 cho phép workspace/nhiều bundle phong phú hơn nhưng vẫn dùng chung cấu trúc Envelope/Payload, nên decoder trong app xử lý cả hai.

## Gợi ý tạo file test

`Tools/make_sample_patch.swift` tạo đúng cấu trúc trên cho schema v1.
