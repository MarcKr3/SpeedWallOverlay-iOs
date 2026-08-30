import SwiftUI
import Photos

struct OverlayView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var motionManager: MotionManager
    @EnvironmentObject var cameraManager: CameraManager

    // Real-world wall dimensions (meters)
    private let wallWidthMeters: CGFloat = 3.0
    private let wallHeightMeters: CGFloat = 15.0

    // Pan offset (accumulated + in-flight drag)
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    // Controls visibility
    @State private var showControls: Bool = true
    @State private var showPalette: Bool = false

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
            // Freeze layout at zero while hidden: calibration drags mutate
            // pixelsPerMeter per touch event, and the wall layers must not
            // re-layout at full size in an invisible view.
            let layoutPPM = appState.mode == .overlay ? appState.pixelsPerMeter : 0
            let renderedWidth = wallWidthMeters * layoutPPM
            let renderedHeight = wallHeightMeters * layoutPPM

            overlayLayers(renderedWidth: renderedWidth, renderedHeight: renderedHeight)
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
                .offset(
                    x: offset.width + dragOffset.width,
                    y: offset.height + dragOffset.height
                )
                .gesture(panGesture(renderedWidth: renderedWidth, renderedHeight: renderedHeight,
                                    screenWidth: screenWidth, screenHeight: screenHeight))
                .frame(width: screenWidth, height: screenHeight)
                .contentShape(Rectangle())
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
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation { showControls.toggle() }
                        }
                )
                .onChangeCompat(of: appState.mode) { newMode in
                    // Sizes computed from appState directly: the captured
                    // renderedWidth/Height are from the pre-transition layout.
                    let fullWidth = wallWidthMeters * appState.pixelsPerMeter
                    let fullHeight = wallHeightMeters * appState.pixelsPerMeter
                    if newMode == .overlay {
                        if appState.autoLevel { motionManager.start() }
                        if !hasSetInitialPosition {
                            hasSetInitialPosition = true
                            offset.height = screenHeight / 3 - fullHeight / 2
                        }
                        clampOffset(renderedWidth: fullWidth, renderedHeight: fullHeight,
                                    screenWidth: screenWidth, screenHeight: screenHeight)
                    } else {
                        motionManager.stop()
                    }
                }
                .onChangeCompat(of: appState.pixelsPerMeter) { _ in
                    // Recalibration invalidates the saved pan position
                    hasSetInitialPosition = false
                }
                .onChangeCompat(of: appState.autoLevel) { enabled in
                    if appState.mode == .overlay {
                        enabled ? motionManager.start() : motionManager.stop()
                    }
                }
                .onChangeCompat(of: geometry.size) { newSize in
                    guard appState.mode == .overlay else { return }
                    clampOffset(renderedWidth: wallWidthMeters * appState.pixelsPerMeter,
                                renderedHeight: wallHeightMeters * appState.pixelsPerMeter,
                                screenWidth: newSize.width, screenHeight: newSize.height)
                }
                .alert("Screenshot Failed", isPresented: $showSaveError) {
                    Button("Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Allow photo library access in Settings to save screenshots.")
                }
        }
    }

    // MARK: - Overlay Layers

    // Fill+mask instead of .renderingMode(.template) + .foregroundColor:
    // the live CA template-tint path renders a pure white tint as the
    // artwork's own dark color (verified by pixel probe on simulator).
    private func tintedLayer(_ img: UIImage, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(appState.overlayColor)
            .frame(width: width, height: height)
            .mask(Image(uiImage: img).resizable())
    }

    @ViewBuilder
    private func overlayLayers(renderedWidth: CGFloat, renderedHeight: CGFloat) -> some View {
        ZStack {
            // Holds layer (always visible)
            if let img = UIImage(named: "overlay") {
                tintedLayer(img, width: renderedWidth, height: renderedHeight)
            }

            // Grid layer
            if appState.showGrid, let img = UIImage(named: "grid") {
                tintedLayer(img, width: renderedWidth, height: renderedHeight)
                    .transition(.opacity)
            }

            // Labels layer
            if appState.showLabels, let img = UIImage(named: "labels") {
                tintedLayer(img, width: renderedWidth, height: renderedHeight)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: appState.showGrid)
        .animation(.easeOut(duration: 0.15), value: appState.showLabels)
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
                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) { showPalette.toggle() }
                    }) {
                        Circle()
                            .fill(appState.overlayColor)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
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

            if showPalette {
                paletteRow()
                    .padding(.top, 8)
                    .padding(.horizontal)
                    .transition(.opacity)
            }

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
                        in: -45...45
                    )
                    .tint(.white)
                    .accessibilityLabel("Horizontal tilt")

                    Button(action: { appState.horizontalTilt = 0 }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
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
                        in: -45...45
                    )
                    .tint(.white)
                    .accessibilityLabel("Vertical tilt")

                    Button(action: { appState.verticalTilt = 0 }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
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
                    colors: [.black.opacity(0), .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Color Palette

    private func paletteRow() -> some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                ForEach(OverlayPalette.presets, id: \.name) { preset in
                    let selected = appState.overlayColor == preset.color
                    Button(action: {
                        appState.overlayColor = preset.color
                        withAnimation(.easeOut(duration: 0.15)) { showPalette = false }
                    }) {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: selected ? 3 : 1)
                            )
                    }
                    .accessibilityLabel(Text(LocalizedStringKey(preset.name)))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }

                // Custom colors: the system picker. Its first open is slow.
                ColorPicker("", selection: Binding(
                    get: { appState.overlayColor },
                    set: { appState.overlayColor = $0.normalizedToSRGB() }
                ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32, height: 32)
                    .accessibilityLabel("Custom overlay color")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
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
                    // 1. Draw camera frame as background (aspect-fill, matching preview layer)
                    if let frame = cameraManager.latestFrame {
                        let frameW = CGFloat(frame.width)
                        let frameH = CGFloat(frame.height)
                        let boundsW = window.bounds.width
                        let boundsH = window.bounds.height
                        let scale = max(boundsW / frameW, boundsH / frameH)
                        let drawW = frameW * scale
                        let drawH = frameH * scale
                        let drawRect = CGRect(
                            x: (boundsW - drawW) / 2,
                            y: (boundsH - drawH) / 2,
                            width: drawW,
                            height: drawH
                        )
                        UIImage(cgImage: frame).draw(in: drawRect)
                    }

                    // 2. Hide camera preview (renders as black)
                    let previewView = Self.findVideoPreviewView(in: window)
                    previewView?.isHidden = true

                    // 3. Clear all opaque backgrounds so overlay renders transparently
                    let saved = Self.clearAllBackgrounds(in: window)

                    // 4. Render UI — only overlay graphics draw (transparent backgrounds)
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)

                    // 5. Restore everything
                    Self.restoreBackgrounds(saved)
                    previewView?.isHidden = false
                }
                // PNG encoding takes hundreds of ms — keep it off the main thread
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let imageData = image.pngData() else { return }
                    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                        guard status == .authorized || status == .limited else {
                            DispatchQueue.main.async {
                                showSaveError = true
                            }
                            return
                        }
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
                }
            }
            showFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showFlash = false
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = true
                }
            }
        }
    }

    // MARK: - Screenshot Helpers

    private static func findVideoPreviewView(in view: UIView) -> VideoPreviewView? {
        if let preview = view as? VideoPreviewView { return preview }
        for subview in view.subviews {
            if let found = findVideoPreviewView(in: subview) { return found }
        }
        return nil
    }

    private static func clearAllBackgrounds(in window: UIWindow) -> [(UIView, UIColor?, Bool)] {
        var saved: [(UIView, UIColor?, Bool)] = []
        func walk(_ view: UIView) {
            let bg = view.backgroundColor
            let opaque = view.isOpaque
            if bg != nil || opaque {
                saved.append((view, bg, opaque))
                view.backgroundColor = .clear
                view.isOpaque = false
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(window)
        return saved
    }

    private static func restoreBackgrounds(_ saved: [(UIView, UIColor?, Bool)]) {
        for (view, bg, opaque) in saved {
            view.backgroundColor = bg
            view.isOpaque = opaque
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
        .environmentObject(CameraManager())
}
