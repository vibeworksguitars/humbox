import SwiftUI

@main
struct HumboxApp: App {
    @StateObject private var audioService = AudioService()
    @StateObject private var storeService = StoreService()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(audioService)
                .environmentObject(storeService)
                .task { await storeService.load() }
                .preferredColorScheme(.dark)
        }
    }
}
