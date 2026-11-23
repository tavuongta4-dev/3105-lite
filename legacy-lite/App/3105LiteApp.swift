import SwiftUI

@main
struct PatchLiteApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    appState.importFile(at: url)
                    appState.selectedTab = 0
                }
        }
    }
}
