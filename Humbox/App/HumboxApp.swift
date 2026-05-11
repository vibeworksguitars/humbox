import SwiftUI

@main
struct HumboxApp: App {
    @StateObject private var audioService = AudioService()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(audioService)
        }
    }
}
