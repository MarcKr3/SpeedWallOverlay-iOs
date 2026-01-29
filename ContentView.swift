import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera layer (always visible)
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                
                // Mode-specific overlay
                switch appState.mode {
                case .calibration:
                    CalibrationView()
                        .environmentObject(cameraManager)
                    
                case .templateSelection:
                    TemplateSelectionView()
                    
                case .overlay:
                    OverlayView()
                }
            }
            .onAppear {
                appState.screenSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                appState.screenSize = newSize
            }
        }
        .task {
            let hasPermission = await cameraManager.checkPermissions()
            if hasPermission {
                cameraManager.configure()
                cameraManager.start()
            }
        }
        .alert("Camera Error", isPresented: .constant(cameraManager.error != nil)) {
            Button("OK") {
                cameraManager.error = nil
            }
        } message: {
            Text(cameraManager.error?.localizedDescription ?? "Unknown error")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
