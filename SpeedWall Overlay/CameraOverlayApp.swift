import SwiftUI

@main
struct CameraOverlayApp: App {
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
