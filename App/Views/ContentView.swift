import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView(selection: $app.selectedTab) {
            NavigationStack { PatchView() }
                .tabItem { Label("Patch", systemImage: "square.stack.3d.up") }
                .tag(0)

            NavigationStack { RestoreView() }
                .tabItem { Label("Khôi phục", systemImage: "arrow.uturn.backward") }
                .tag(1)

            NavigationStack { ApplicationsView() }
                .tabItem { Label("Ứng dụng", systemImage: "app.badge") }
                .tag(2)

            NavigationStack { HistoryView() }
                .tabItem { Label("Path", systemImage: "clock.arrow.circlepath") }
                .tag(3)

            NavigationStack { AboutView() }
                .tabItem { Label("Thông tin", systemImage: "info.circle") }
                .tag(4)
        }
        .tint(.orange)
    }
}
