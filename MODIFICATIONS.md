# Modifications applied to the 3106 source

This repository contains a modified copy of [QuinnTang74/3106](https://github.com/QuinnTang74/3106)
(source snapshot at v3.2.8 / build 33), distributed under **GPL-3.0**. The upstream
`LICENSE` and `NOTICE.md` are included unchanged.

Changes made by this repository:

1. Rebranded the application identity:
   - `PRODUCT_BUNDLE_IDENTIFIER` / `CFBundleIdentifier`: `com.qingtang.3106` → `com.patchlite.app`
   - `CFBundleDisplayName` / `CFBundleName`: `3106` → `3105 Lite`
   - App Group entitlement placeholder: `group.com.qingtang.3106` → `group.com.patchlite.app`
     (the signing tool still rewrites this to the group it actually grants)
   - All in-source references to `com.qingtang.3106` (UTI declarations, URL scheme,
     cleaner self-protection lists, backup service identifiers) were updated to
     `com.patchlite.app`.
2. Replaced the GitHub Actions workflow so it builds this project and uploads an IPA
   named `3105Lite-unsigned.ipa`.
3. Added `Tools/make_sample_patch.swift` (a standalone legacy `.3105` v1 patch generator)
   and `docs/PATCH_FORMAT.md` from the earlier 3105 Lite work.
4. Preserved the earlier standalone SwiftUI implementation under `legacy-lite/` for
   reference. It is not part of the Xcode project and is not compiled.

5. Removed the user-facing backup features as requested: the Backup tab, the two
   backup cards in the feature hub, the Settings entry, and the source files
   `BackupTabView.swift`, `BackupCenterView.swift`, `AppSaveBackupView.swift` and
   `FullBackupService.swift` (including their Xcode project references).
   `BackupCenter`, `AppSaveBackupService` and `BackupMetadataPolicy` were kept
   because patch apply/restore and file replacement depend on their internal
   snapshot machinery — only the standalone backup UI/module was removed.

6. Trimmed `FeatureHubView` (the home "features" page) down to a single card:
   Patch Projects. All other feature cards (MobileGestalt, keypad themes,
   supervised mode, system settings, launch artwork, wallpapers, marketplace,
   sources, files/search/cleaner shortcuts, sounds, Wi-Fi share, file replace,
   migration, logs, respring, acknowledgements) were removed from that page.
   The backend/App Group status section was kept because it is required to
   diagnose sandbox access.

No exploit, sandbox, or container-access code was altered. Upstream attribution and
all third-party notices remain in `NOTICE.md`.
