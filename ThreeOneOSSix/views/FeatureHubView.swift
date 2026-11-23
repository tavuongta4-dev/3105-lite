import SwiftUI

/// Landing page trimmed down to a single feature: patch projects.
struct FeatureHubView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var taskCenter: MigrationTaskCenter
    @State private var entranceShown = false
    let onSelectTab: (AppSection) -> Void
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent(language.text("home.version"), value: appVersion)
                    LabeledContent(
                        language.text("home.backend"),
                        value: SandboxAccess.backend.displayName
                    )
                    if SandboxAccess.needsWorseQuery {
                        LabeledContent(
                            language.text("home.app_group"),
                            value: appGroupText
                        )
                        if SandboxAccess.appGroup == nil {
                            Text(language.text("home.app_group_warning"))
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text(language.text("home.status"))
                }

                Section {
                    NavigationLink {
                        PatchProjectsView(
                            onOpenSettings: onOpenSettings,
                            onOpenLogs: onOpenLogs
                        )
                    } label: {
                        card(
                            "tab.installed",
                            detail: "home.card.patches_detail",
                            icon: "square.stack.3d.up.fill"
                        )
                    }
                } header: {
                    Text(language.text("home.section.apps"))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(language.text("tab.features"))
            .navigationBarTitleDisplayMode(.inline)
            .opacity(entranceShown ? 1 : 0)
            .offset(y: entranceShown ? 0 : 10)
            .onAppear {
                guard !entranceShown, !reduceMotion else {
                    entranceShown = true
                    taskCenter.refreshPendingResumes()
                    return
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    entranceShown = true
                }
                taskCenter.refreshPendingResumes()
            }
            .toolbar {
                AppUtilityToolbar(
                    language: language,
                    onOpenSettings: onOpenSettings,
                    onOpenLogs: onOpenLogs
                )
            }
        }
    }

    private func card(
        _ titleKey: String,
        detail: String,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(language.text(titleKey))
                    .foregroundStyle(.primary)
                Text(language.text(detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var appGroupText: String {
        SandboxAccess.appGroup ?? language.text("home.app_group_missing")
    }
}
