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

                CalibrationView()
                    .environmentObject(cameraManager)
                    .opacity(appState.mode == .calibration ? 1 : 0)
                    .allowsHitTesting(appState.mode == .calibration)

                OverlayView()
                    .opacity(appState.mode == .overlay ? 1 : 0)
                    .allowsHitTesting(appState.mode == .overlay)
            }
            .animation(.easeOut(duration: 0.3), value: appState.mode)
            .onAppear {
                appState.screenSize = geometry.size
            }
            .onChangeCompat(of: geometry.size) { newSize in
                let oldWidth = appState.screenSize.width
                appState.screenSize = newSize
                if appState.mode == .calibration && abs(newSize.width - oldWidth) > 1 {
                    appState.resetCalibration()
                }
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
            Text(cameraManager.error?.localizedDescription ?? NSLocalizedString("Unknown error", comment: "Fallback error message"))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
