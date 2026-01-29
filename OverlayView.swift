import SwiftUI

struct OverlayView: View {
    @EnvironmentObject var appState: AppState
    
    // Template dimensions
    private let templateWidth: CGFloat = 800
    private let templateHeight: CGFloat = 4000
    
    // Gesture state for positioning
    @State private var overlayOffset: CGSize = .zero
    @State private var currentDragOffset: CGSize = .zero
    
    // Scroll state for moving through template
    @State private var localScrollOffset: CGFloat = 0
    
    // Pinch to scale
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    // UI visibility
    @State private var showControls: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Template overlay (scaled and positioned)
                templateOverlay(geometry: geometry)
                    .opacity(appState.overlayOpacity)
                    .offset(x: overlayOffset.width + currentDragOffset.width,
                            y: overlayOffset.height + currentDragOffset.height)
                    .gesture(dragGesture)
                    .gesture(magnificationGesture)
                
                // Controls overlay
                if showControls {
                    controlsOverlay(geometry: geometry)
                }
            }
            .onTapGesture(count: 2) {
                // Double tap to toggle controls
                withAnimation {
                    showControls.toggle()
                }
            }
            .onAppear {
                localScrollOffset = appState.templateScrollOffset
            }
        }
    }
    
    // MARK: - Template Overlay
    
    private func templateOverlay(geometry: GeometryProxy) -> some View {
        // Calculate the visible section of the template
        let scale = appState.overlayScale * currentScale
        
        // Calculate display size based on calibration
        // The template section should appear at the real-world size based on pixelsPerMeter
        let displayHeight = appState.templateVisibleHeightPixels * scale
        let aspectRatio = templateWidth / (templateHeight * windowHeightRatio)
        let displayWidth = displayHeight * aspectRatio
        
        return CroppedTemplateOverlay(
            scrollOffset: localScrollOffset,
            windowHeightRatio: windowHeightRatio,
            templateWidth: templateWidth,
            templateHeight: templateHeight
        )
        .frame(width: displayWidth, height: displayHeight)
        .border(Color.yellow.opacity(0.5), width: 2)
        .clipped()
    }
    
    // MARK: - Controls Overlay
    
    private func controlsOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            // Top bar
            HStack {
                Button(action: {
                    appState.backToTemplateSelection()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Info display
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "Scale: %.0f%%", appState.overlayScale * currentScale * 100))
                    Text(String(format: "Opacity: %.0f%%", appState.overlayOpacity * 100))
                }
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
                // Vertical scroll through template
                VStack(spacing: 4) {
                    Text("Template Position")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Slider(value: $localScrollOffset, in: 0...max(0, 1 - windowHeightRatio))
                        .tint(.yellow)
                        .padding(.horizontal, 40)
                }
                
                // Opacity control
                VStack(spacing: 4) {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Slider(value: $appState.overlayOpacity, in: 0.1...1.0)
                        .tint(.yellow)
                        .padding(.horizontal, 40)
                }
                
                // Scale control
                VStack(spacing: 4) {
                    Text("Scale")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Slider(value: $appState.overlayScale, in: 0.5...2.0)
                        .tint(.yellow)
                        .padding(.horizontal, 40)
                }
                
                // Quick actions
                HStack(spacing: 20) {
                    // Reset position
                    Button(action: resetPosition) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                    
                    // Center overlay
                    Button(action: centerOverlay) {
                        Label("Center", systemImage: "viewfinder")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                    
                    // Lock position (future feature)
                    Button(action: {}) {
                        Label("Lock", systemImage: "lock")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                }
                
                // Hint
                Text("Double-tap to hide controls • Drag to move • Pinch to scale")
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
    
    // MARK: - Computed Properties
    
    private var windowHeightRatio: CGFloat {
        // This should match what was set in TemplateSelectionView
        // For now, using a reasonable default
        0.15
    }
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                currentDragOffset = value.translation
            }
            .onEnded { value in
                overlayOffset.width += value.translation.width
                overlayOffset.height += value.translation.height
                currentDragOffset = .zero
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                currentScale = value
            }
            .onEnded { value in
                appState.overlayScale *= value
                currentScale = 1.0
                
                // Clamp scale to reasonable bounds
                appState.overlayScale = min(max(appState.overlayScale, 0.25), 4.0)
            }
    }
    
    // MARK: - Actions
    
    private func resetPosition() {
        withAnimation {
            overlayOffset = .zero
            appState.overlayScale = 1.0
            currentScale = 1.0
        }
    }
    
    private func centerOverlay() {
        withAnimation {
            overlayOffset = .zero
        }
    }
}

// MARK: - Cropped Template Overlay

struct CroppedTemplateOverlay: View {
    let scrollOffset: CGFloat
    let windowHeightRatio: CGFloat
    let templateWidth: CGFloat
    let templateHeight: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let visibleHeight = templateHeight * windowHeightRatio
            let startY = templateHeight * scrollOffset
            let scaleX = geometry.size.width / templateWidth
            let fullHeight = templateHeight * scaleX
            
            TemplateImageView()
                .frame(
                    width: geometry.size.width,
                    height: fullHeight
                )
                .offset(y: -startY * scaleX)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }
}

#Preview {
    OverlayView()
        .environmentObject({
            let state = AppState()
            state.pixelsPerMeter = 500 // Simulate calibration
            return state
        }())
}
