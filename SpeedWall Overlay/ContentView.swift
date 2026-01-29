import SwiftUI

extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

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

                case .overlay:
                    OverlayView()
                }
            }
            .onAppear {
                appState.screenSize = geometry.size
            }
            .onChangeCompat(of: geometry.size) { newSize in
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
