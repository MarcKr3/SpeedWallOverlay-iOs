import SwiftUI
import Photos

struct OverlayView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var motionManager: MotionManager

    // Real-world wall dimensions (meters)
    private let wallWidthMeters: CGFloat = 3.0
    private let wallHeightMeters: CGFloat = 15.0

    // Pan offset (accumulated + in-flight drag)
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    // Controls visibility
    @State private var showControls: Bool = true

    // Flash feedback for screenshot
    @State private var showFlash: Bool = false

    // Initial position flag
    @State private var hasSetInitialPosition = false

    // Screenshot error alert
    @State private var showSaveError = false

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let renderedWidth = wallWidthMeters * appState.pixelsPerMeter
            let renderedHeight = wallHeightMeters * appState.pixelsPerMeter

            overlayLayers(renderedWidth: renderedWidth, renderedHeight: renderedHeight)
                .offset(
                    x: offset.width + dragOffset.width,
                    y: offset.height + dragOffset.height
                )
                .rotationEffect(appState.autoLevel ? motionManager.rollCorrection : .zero)
                .rotation3DEffect(
                    .degrees(appState.verticalTilt),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.5
                )
                .rotation3DEffect(
                    .degrees(appState.horizontalTilt),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .gesture(panGesture(renderedWidth: renderedWidth, renderedHeight: renderedHeight,
                                    screenWidth: screenWidth, screenHeight: screenHeight))
                .frame(width: screenWidth, height: screenHeight)
                .overlay {
                    if showControls {
                        controlsOverlay()
                    }
                    if showFlash {
                        Color.white
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
                .onTapGesture(count: 2) {
                    withAnimation { showControls.toggle() }
                }
                .onAppear {
                    UserDefaults.standard.set(1, forKey: "UICPSelectedCustomSegment")
                }
                .onChangeCompat(of: appState.mode) { newMode in
                    if newMode == .overlay {
                        if appState.autoLevel { motionManager.start() }
                        hasSetInitialPosition = true
                        offset.height = screenHeight / 3 - renderedHeight / 2
                        clampOffset(renderedWidth: renderedWidth, renderedHeight: renderedHeight,
                                    screenWidth: screenWidth, screenHeight: screenHeight)
                    } else {
                        motionManager.stop()
                        hasSetInitialPosition = false
                    }
                }
                .onChangeCompat(of: appState.autoLevel) { enabled in
                    if appState.mode == .overlay {
                        enabled ? motionManager.start() : motionManager.stop()
                    }
                }
                .onChange(of: geometry.size) { _ in
                    clampOffset(renderedWidth: renderedWidth, renderedHeight: renderedHeight,
                                screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                }
                .alert("Screenshot Failed", isPresented: $showSaveError) {
                    Button("Settings") {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Allow photo library access in Settings to save screenshots.")
                }
        }
    }

    // MARK: - Overlay Layers

    @ViewBuilder
    private func overlayLayers(renderedWidth: CGFloat, renderedHeight: CGFloat) -> some View {
        ZStack {
            // Holds layer (always visible)
            if let img = UIImage(named: "overlay") {
                Image(uiImage: img)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(appState.overlayColor)
                    .frame(width: renderedWidth, height: renderedHeight)
            }

            // Grid layer — always loaded, opacity toggled
            if let img = UIImage(named: "grid") {
                Image(uiImage: img)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(appState.overlayColor)
                    .frame(width: renderedWidth, height: renderedHeight)
                    .opacity(appState.showGrid ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: appState.showGrid)
            }

            // Labels layer — always loaded, opacity toggled
            if let img = UIImage(named: "labels") {
                Image(uiImage: img)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(appState.overlayColor)
                    .frame(width: renderedWidth, height: renderedHeight)
                    .opacity(appState.showLabels ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: appState.showLabels)
            }
        }
    }

    // MARK: - Controls Overlay

    private func controlsOverlay() -> some View {
        VStack {
            // Top bar
            HStack {
                // Back button
                Button(action: { appState.backToCalibration() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Back to calibration")

                Spacer()

                // Layer toggles
                HStack(spacing: 1) {
                    ColorPicker("", selection: $appState.overlayColor, supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(0.9)
                        .frame(width: 40, height: 40)
                        .accessibilityLabel("Overlay color")

                    Button(action: { appState.showGrid.toggle() }) {
                        Image(systemName: "grid")
                            .font(.title2)
                            .padding(8)
                            .background(appState.showGrid ? Color.yellow : Color.clear)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(appState.showGrid ? "Hide grid" : "Show grid")

                    Button(action: { appState.showLabels.toggle() }) {
                        Image(systemName: "ruler")
                            .font(.title2)
                            .padding(12)
                            .background(appState.showLabels ? Color.yellow : Color.clear)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(appState.showLabels ? "Hide labels" : "Show labels")

                }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Spacer()

            // Bottom controls
            VStack(spacing: 12) {
                HStack {
                    Button(action: { takeScreenshot() }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 35, height: 35)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .accessibilityLabel("Take screenshot")

                    Spacer()

                    Button(action: { appState.autoLevel.toggle() }) {
                        ZStack {
                            Circle()
                                .stroke(appState.autoLevel ? Color.yellow : Color.white, lineWidth: 3)
                                .frame(width: 35, height: 35)
                            Image(systemName: "level")
                                .font(.system(size: 16))
                                .foregroundColor(appState.autoLevel ? .yellow : .white)
                        }
                    }
                    .accessibilityLabel(appState.autoLevel ? "Disable auto-level" : "Enable auto-level")
                }
                .padding(.horizontal, 10)

                // Horizontal tilt slider
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    Slider(
                        value: $appState.horizontalTilt,
                        in: -45...45,
                        step: 0.5
                    )
                    .tint(.yellow)
                    .accessibilityLabel("Horizontal tilt")

                    Button(action: { appState.horizontalTilt = 0 }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 20)
                    }
                    .accessibilityLabel("Reset horizontal tilt")
                }
                .padding(.horizontal)

                // Vertical tilt slider
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    Slider(
                        value: $appState.verticalTilt,
                        in: -45...45,
                        step: 0.5
                    )
                    .tint(.yellow)
                    .accessibilityLabel("Vertical tilt")

                    Button(action: { appState.verticalTilt = 0 }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 20)
                    }
                    .accessibilityLabel("Reset vertical tilt")
                }
                .padding(.horizontal)

                Text("Double-tap to hide controls")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Screenshot

    private func takeScreenshot() {
        showControls = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
                let image = renderer.image { ctx in
                    window.layer.render(in: ctx.cgContext)
                }
                guard let imageData = image.pngData() else { return }
                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: imageData, options: nil)
                }) { success, error in
                    if !success {
                        DispatchQueue.main.async {
                            showSaveError = true
                        }
                    }
                }
            }
            showFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showFlash = false
                }
                showControls = true
            }
        }
    }

    // MARK: - Clamping

    private func clampOffset(
        renderedWidth: CGFloat, renderedHeight: CGFloat,
        screenWidth: CGFloat, screenHeight: CGFloat
    ) {
        let margin: CGFloat = 100
        let maxX = (screenWidth + renderedWidth) / 2 - margin
        offset.width = min(max(offset.width, -maxX), maxX)
        let maxY = (screenHeight + renderedHeight) / 2 - margin
        offset.height = min(max(offset.height, -maxY), maxY)
    }

    // MARK: - Gestures

    private func panGesture(
        renderedWidth: CGFloat, renderedHeight: CGFloat,
        screenWidth: CGFloat, screenHeight: CGFloat
    ) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
                dragOffset = .zero
                clampOffset(renderedWidth: renderedWidth, renderedHeight: renderedHeight,
                            screenWidth: screenWidth, screenHeight: screenHeight)
            }
    }

}

#Preview {
    OverlayView()
        .environmentObject({
            let state = AppState()
            state.recordCalibrationTap(at: CGPoint(x: 100, y: 100))
            state.recordCalibrationTap(at: CGPoint(x: 300, y: 100))
            state.setKnownDistance(1.0) // 200 px/m
            return state
        }())
        .environmentObject(MotionManager())
}
