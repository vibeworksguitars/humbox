import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .capture

    enum Tab {
        case capture, library, revival
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "mic.fill")
                }
                .tag(Tab.capture)

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(Tab.library)

            RevivalView()
                .tabItem {
                    Label("Revive", systemImage: "arrow.clockwise")
                }
                .tag(Tab.revival)
        }
        .tint(.primary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AudioService())
        .environmentObject(StoreService())
}
