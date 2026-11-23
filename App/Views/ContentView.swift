import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView {
            NavigationStack { PatchView() }
                .tabItem { Label("Patch", systemImage: "square.stack.3d.up") }

            NavigationStack { RestoreView() }
                .tabItem { Label("Khôi phục", systemImage: "arrow.uturn.backward") }

            NavigationStack { HistoryView() }
                .tabItem { Label("Path", systemImage: "clock.arrow.circlepath") }

            NavigationStack { AboutView() }
                .tabItem { Label("Thông tin", systemImage: "info.circle") }
        }
        .tint(.orange)
    }
}
