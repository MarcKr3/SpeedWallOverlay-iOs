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

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let renderedHeight = screenWidth * (imageHeight / imageWidth)

            ZStack {
                // Three-layer overlay stack
                overlayLayers(screenWidth: screenWidth, renderedHeight: renderedHeight)
                    .opacity(appState.overlayOpacity)
                    .offset(
                        x: offset.width + dragOffset.width,
                        y: offset.height + dragOffset.height
                    )
                    .gesture(panGesture)

                // Controls
                if showControls {
                    controlsOverlay()
                }
            }
            .onTapGesture(count: 2) {
                withAnimation { showControls.toggle() }
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
                    .resizable()
                    .frame(width: screenWidth, height: renderedHeight)
            }

            // Grid layer (toggleable)
            if appState.showGrid, let img = UIImage(named: "grid") {
                Image(uiImage: img)
                    .resizable()
                    .frame(width: screenWidth, height: renderedHeight)
            }

            // Labels layer (toggleable)
            if appState.showLabels, let img = UIImage(named: "labels") {
                Image(uiImage: img)
                    .resizable()
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
                HStack(spacing: 12) {
                    Button(action: { appState.showGrid.toggle() }) {
                        Image(systemName: "grid")
                            .font(.title2)
                            .padding(12)
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

                Spacer()

                // Info display
                Text(String(format: "Opacity: %.0f%%", appState.overlayOpacity * 100))
                    .font(.caption.monospacedDigit())
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.top, 60)

            Spacer()

            // Bottom controls
            VStack(spacing: 16) {
                // Opacity slider
                VStack(spacing: 4) {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(.white)

                    Slider(value: $appState.overlayOpacity, in: 0.1...1.0)
                        .tint(.yellow)
                        .padding(.horizontal, 40)
                }

                // Quick actions
                HStack(spacing: 20) {
                    Button(action: resetPosition) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }

                    Button(action: centerOverlay) {
                        Label("Center", systemImage: "viewfinder")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                }

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

    // MARK: - Actions

    private func resetPosition() {
        withAnimation {
            offset = .zero
            dragOffset = .zero
        }
    }

    private func centerOverlay() {
        withAnimation {
            offset = .zero
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
