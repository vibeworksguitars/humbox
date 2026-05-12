import SwiftUI

@main
struct HumboxApp: App {
    @StateObject private var audioService = AudioService()
    @StateObject private var storeService = StoreService()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .environmentObject(audioService)
                    .environmentObject(storeService)
                    .task { await storeService.load() }

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
            .task {
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
            }
        }
    }
}
