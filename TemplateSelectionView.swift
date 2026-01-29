import SwiftUI

struct TemplateSelectionView: View {
    @EnvironmentObject var appState: AppState
    
    // Template image dimensions (as specified: 800x4000)
    private let templateWidth: CGFloat = 800
    private let templateHeight: CGFloat = 4000
    
    // Visible window height relative to template (adjustable)
    @State private var windowHeightRatio: CGFloat = 0.15 // 15% of template visible at once
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    headerView
                    
                    // Main content: Template browser
                    HStack(spacing: 20) {
                        // Template scroll view
                        templateScrollView(geometry: geometry)
                        
                        // Preview of selected section
                        selectedSectionPreview(geometry: geometry)
                    }
                    .padding(.horizontal)
                    
                    // Settings controls
                    settingsControls
                    
                    // Action buttons
                    actionButtons
                }
                .padding(.vertical)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Select Template Section")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("Scroll to choose which part of the template to overlay")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 40)
    }
    
    private func templateScrollView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Text("Template")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Scrollable template with selection window
            ZStack {
                // The full template (scaled to fit)
                TemplateImageView()
                    .aspectRatio(templateWidth / templateHeight, contentMode: .fit)
                    .frame(maxHeight: geometry.size.height * 0.6)
                    .overlay(
                        // Selection window indicator
                        GeometryReader { templateGeometry in
                            selectionWindowOverlay(templateSize: templateGeometry.size)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Scroll slider
            VStack(spacing: 4) {
                Slider(value: $appState.templateScrollOffset, in: 0...max(0, 1 - windowHeightRatio))
                    .tint(.yellow)
                
                Text("Scroll Position: \(Int(appState.templateScrollOffset * 100))%")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: geometry.size.width * 0.4)
    }
    
    private func selectionWindowOverlay(templateSize: CGSize) -> some View {
        let windowTop = appState.templateScrollOffset * templateSize.height
        let windowHeight = windowHeightRatio * templateSize.height
        
        return ZStack {
            // Dimmed areas above and below selection
            VStack(spacing: 0) {
                // Top dimmed area
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(height: windowTop)
                
                // Selected area (clear)
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: windowHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.yellow, lineWidth: 3)
                    )
                
                // Bottom dimmed area
                Rectangle()
                    .fill(Color.black.opacity(0.6))
            }
        }
    }
    
    private func selectedSectionPreview(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Text("Selected Section")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Preview of the selected portion
            TemplateImageView()
                .aspectRatio(templateWidth / (templateHeight * windowHeightRatio), contentMode: .fit)
                .frame(maxWidth: geometry.size.width * 0.5, maxHeight: geometry.size.height * 0.4)
                .mask(
                    // Only show the selected portion
                    GeometryReader { previewGeometry in
                        Rectangle()
                            .frame(
                                width: previewGeometry.size.width,
                                height: previewGeometry.size.height
                            )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow, lineWidth: 2)
                )
                .overlay(
                    // Crop indicator
                    CroppedTemplatePreview(
                        scrollOffset: appState.templateScrollOffset,
                        windowHeightRatio: windowHeightRatio
                    )
                )
            
            Text("This section will overlay on camera")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
    
    private var settingsControls: some View {
        VStack(spacing: 16) {
            // Visible height setting (real-world size)
            VStack(spacing: 4) {
                HStack {
                    Text("Template Height (real-world)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.2f m", appState.templateVisibleHeightMeters))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.yellow)
                }
                
                Slider(value: $appState.templateVisibleHeightMeters, in: 0.1...2.0)
                    .tint(.yellow)
            }
            
            // Overlay opacity
            VStack(spacing: 4) {
                HStack {
                    Text("Overlay Opacity")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(appState.overlayOpacity * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.yellow)
                }
                
                Slider(value: $appState.overlayOpacity, in: 0.1...1.0)
                    .tint(.yellow)
            }
            
            // Window size adjustment
            VStack(spacing: 4) {
                HStack {
                    Text("Selection Size")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(windowHeightRatio * 100))% of template")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.yellow)
                }
                
                Slider(value: $windowHeightRatio, in: 0.05...0.5)
                    .tint(.yellow)
            }
        }
        .padding(.horizontal, 30)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            Button(action: {
                appState.backToCalibration()
            }) {
                Label("Back", systemImage: "arrow.left")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(25)
            }
            
            Button(action: {
                appState.proceedToOverlay()
            }) {
                Label("Start Overlay", systemImage: "viewfinder")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(25)
            }
        }
        .padding(.bottom, 30)
    }
}

// MARK: - Template Image View

/// Displays the template image. Replace with your actual image loading logic.
struct TemplateImageView: View {
    var body: some View {
        // Try to load from bundle, otherwise show placeholder
        if let image = UIImage(named: "template") {
            Image(uiImage: image)
                .resizable()
        } else {
            // Placeholder - a gradient representing a tall template
            PlaceholderTemplateView()
        }
    }
}

/// Placeholder when no template image is available
struct PlaceholderTemplateView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [.blue, .purple, .pink, .orange, .yellow],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Grid lines to show sections
                VStack(spacing: 0) {
                    ForEach(0..<20, id: \.self) { index in
                        ZStack {
                            Rectangle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            
                            Text("Section \(index + 1)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(height: geometry.size.height / 20)
                    }
                }
            }
        }
    }
}

// MARK: - Cropped Template Preview

struct CroppedTemplatePreview: View {
    let scrollOffset: CGFloat
    let windowHeightRatio: CGFloat
    
    // Template dimensions
    private let templateWidth: CGFloat = 800
    private let templateHeight: CGFloat = 4000
    
    var body: some View {
        GeometryReader { geometry in
            // Calculate the visible portion
            let visibleHeight = templateHeight * windowHeightRatio
            let startY = templateHeight * scrollOffset
            
            TemplateImageView()
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.width * (templateHeight / templateWidth)
                )
                .offset(y: -startY * (geometry.size.width / templateWidth))
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }
}

#Preview {
    TemplateSelectionView()
        .environmentObject(AppState())
}
