import SwiftUI

struct OverlayView: View {
    @EnvironmentObject var appState: AppState

    // Image dimensions (800x4000, 1:5 aspect ratio)
    private let imageWidth: CGFloat = 800
    private let imageHeight: CGFloat = 4000

    // Pan offset (accumulated + in-flight drag)
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    // Controls visibility
    @State private var showControls: Bool = true

    // Flash feedback for screenshot
    @State private var showFlash: Bool = false

    // Initial position flag
    @State private var hasSetInitialPosition = false

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let renderedHeight = screenWidth * (imageHeight / imageWidth)

            overlayLayers(screenWidth: screenWidth, renderedHeight: renderedHeight)
                .offset(
                    x: offset.width + dragOffset.width,
                    y: offset.height + dragOffset.height
                )
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
                .gesture(panGesture)
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
                    // Default the system color picker to the Spectrum tab
                    UserDefaults.standard.set(1, forKey: "UICPSelectedCustomSegment")

                    guard !hasSetInitialPosition else { return }
                    hasSetInitialPosition = true
                    let renderedHeight = screenWidth * (imageHeight / imageWidth)
                    offset.height = screenHeight / 3 - renderedHeight / 2
                }
        }
    }

    // MARK: - Overlay Layers

    @ViewBuilder
    private func overlayLayers(screenWidth: CGFloat, renderedHeight: CGFloat) -> some View {
        ZStack {
            // Holds layer (always visible)
            if let img = UIImage(named: "overlay") {
                Image(uiImage: img)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(appState.overlayColor)
                    .frame(width: screenWidth, height: renderedHeight)
            }

            // Grid layer (toggleable)
            if appState.showGrid, let img = UIImage(named: "grid") {
                Image(uiImage: img)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(appState.overlayColor)
                    .frame(width: screenWidth, height: renderedHeight)
            }

            // Labels layer (toggleable)
            if appState.showLabels, let img = UIImage(named: "labels") {
                Image(uiImage: img)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(appState.overlayColor)
                    .frame(width: screenWidth, height: renderedHeight)
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

                Spacer()

                // Layer toggles
                HStack(spacing: 1) {
                    ColorPicker("", selection: $appState.overlayColor, supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(0.9)
                        .frame(width: 40, height: 40)

                    Button(action: { appState.showGrid.toggle() }) {
                        Image(systemName: "grid")
                            .font(.title2)
                            .padding(8)
                            .background(appState.showGrid ? Color.yellow : Color.clear)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button(action: { appState.showLabels.toggle() }) {
                        Image(systemName: "ruler")
                            .font(.title2)
                            .padding(12)
                            .background(appState.showLabels ? Color.yellow : Color.clear)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
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
                    Spacer()
                }
                .padding(.leading, 10)

                // Horizontal tilt slider
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 20)

                    Slider(
                        value: $appState.horizontalTilt,
                        in: -45...45,
                        step: 0.5
                    )
                    .tint(.yellow)

                    Button(action: { appState.horizontalTilt = 0 }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 20)
                    }
                }
                .padding(.horizontal)

                // Vertical tilt slider
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 20)

                    Slider(
                        value: $appState.verticalTilt,
                        in: -45...45,
                        step: 0.5
                    )
                    .tint(.yellow)

                    Button(action: { appState.verticalTilt = 0 }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 20)
                    }
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
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
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

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
                dragOffset = .zero
            }
    }

}

#Preview {
    OverlayView()
        .environmentObject({
            let state = AppState()
            return state
        }())
}
