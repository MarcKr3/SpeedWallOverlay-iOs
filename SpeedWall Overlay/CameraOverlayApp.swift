import SwiftUI

@main
struct CameraOverlayAppApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var motionManager = MotionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(motionManager)
        }
    }
}
