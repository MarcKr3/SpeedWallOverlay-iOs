import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cameraManager: CameraManager
    
    @State private var distanceInput: String = "1.0"
    @State private var showDistanceInput = false
    @State private var selectedUnit: DistanceUnit = .meters
    @State private var draggingPointIndex: Int? = nil
    @State private var pointDragOffset: CGSize = .zero
    @State private var showCompleteBanner = false
    @State private var showAbout = false
    
    enum DistanceUnit: String, CaseIterable {
        case meters = "m"
        case centimeters = "cm"
        case inches = "in"
        case feet = "ft"
        
        func toMeters(_ value: Double) -> Double {
            switch self {
            case .meters:
                return value
            case .centimeters:
                return value / 100
            case .inches:
                return value * 0.0254
            case .feet:
                return value * 0.3048
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Tap gesture layer
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            handleTap(at: value.location)
                        }
                )
                .allowsHitTesting(appState.calibrationState != .complete)
            
            // Line between points
            if appState.calibrationPoints.count == 2 {
                CalibrationLine(
                    from: displayPosition(for: 0, basePoint: appState.calibrationPoints[0]),
                    to: displayPosition(for: 1, basePoint: appState.calibrationPoints[1])
                )
                .allowsHitTesting(false)
            }

            // Distance label at midpoint of calibration line
            if appState.calibrationState == .complete && appState.calibrationPoints.count == 2 {
                let p1 = displayPosition(for: 0, basePoint: appState.calibrationPoints[0])
                let p2 = displayPosition(for: 1, basePoint: appState.calibrationPoints[1])
                let angle = atan2(p2.y - p1.y, p2.x - p1.x)
                // Keep text readable: flip if label would be upside-down
                let correctedAngle = (angle > .pi / 2 || angle < -.pi / 2)
                    ? angle + .pi : angle
                Text("\(distanceInput) \(selectedUnit.rawValue)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.yellow)
                    .cornerRadius(14)
                    .rotationEffect(Angle(radians: correctedAngle))
                    .position(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                    .onTapGesture {
                        showDistanceInput = true
                    }
            }

            // Calibration points visualization
            ForEach(Array(appState.calibrationPoints.enumerated()), id: \.offset) { index, point in
                CalibrationPointMarker(index: index + 1)
                    .contentShape(Circle().size(width: 34, height: 34).offset(x: -5, y: -5))
                    .position(displayPosition(for: index, basePoint: point))
                    .gesture(
                        appState.calibrationState == .complete ?
                        DragGesture()
                            .onChanged { value in
                                draggingPointIndex = index
                                pointDragOffset = value.translation
                            }
                            .onEnded { value in
                                let newPos = CGPoint(
                                    x: point.x + value.translation.width,
                                    y: point.y + value.translation.height
                                )
                                appState.updatePointPosition(index: index, newPosition: newPos)
                                draggingPointIndex = nil
                                pointDragOffset = .zero
                            }
                        : nil
                    )
            }
            
            // Instructions overlay
            VStack {
                // Top instruction banner
                if appState.calibrationState != .complete || showCompleteBanner {
                    InstructionBanner(text: instructionText)
                        .padding(.top, 20)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // Bottom controls
                HStack(alignment: .bottom) {
                    // Info button (bottom-left)
                    Button(action: { showAbout = true }) {
                        Text("i")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .italic()
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .overlay {
                    // Centered calibration controls
                    VStack(spacing: 12) {
                        if appState.calibrationState == .complete {
                            calibrationCompleteView
                        }

                        HStack(spacing: 20) {
                            // Reset button
                            Button(action: {
                                appState.resetCalibration()
                            }) {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                                    .font(.headline)
                                    .frame(minWidth: 130)
                                    .padding(.vertical, 12)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(25)
                            }

                            // Continue button (when calibration complete)
                            if appState.isCalibrated {
                                Button(action: {
                                    appState.proceedToOverlay()
                                }) {
                                    Label("Continue", systemImage: "arrow.right")
                                        .font(.headline)
                                        .frame(minWidth: 130)
                                        .padding(.vertical, 12)
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(25)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            // About overlay
            if showAbout {
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("SpeedWall Overlay")
                            .font(.title2.bold())
                        Text("1. Calibrate to a known distance \n\n 2. Speed-Route Overlay for easy setup.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Divider()
                        Text("Version 1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Close") { showAbout = false }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(30)
                    .background(.regularMaterial)
                    .cornerRadius(20)
                    .padding()
                }
                .background(Color.black.opacity(0.5))
            }

            // Distance input sheet
            if showDistanceInput {
                DistanceInputSheet(
                    distanceInput: $distanceInput,
                    selectedUnit: $selectedUnit,
                    onConfirm: confirmDistance,
                    onCancel: { showDistanceInput = false }
                )
            }
        }
        .onChangeCompat(of: appState.calibrationState) { newState in
            if newState == .complete {
                showCompleteBanner = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation {
                        showCompleteBanner = false
                    }
                }
            } else {
                showCompleteBanner = false
            }
        }
    }

    // MARK: - Subviews
    
    private var calibrationCompleteView: some View {
        Text(String(format: "%.1f px/m", appState.pixelsPerMeter))
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundColor(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7))
            .cornerRadius(14)
            .onTapGesture {
                showDistanceInput = true
            }
    }
    
    // MARK: - Computed Properties
    
    private var instructionText: String {
        switch appState.calibrationState {
        case .waitingForFirstPoint:
            return "Tap the first point of a known distance"
        case .waitingForSecondPoint:
            return "Tap the second point"
        case .waitingForDistance:
            return "Enter the distance between points"
        case .complete:
            return "Calibration complete!"
        }
    }
    
    // MARK: - Helpers

    private func displayPosition(for index: Int, basePoint: CGPoint) -> CGPoint {
        if index == draggingPointIndex {
            return CGPoint(
                x: basePoint.x + pointDragOffset.width,
                y: basePoint.y + pointDragOffset.height
            )
        }
        return basePoint
    }

    // MARK: - Actions

    private func handleTap(at location: CGPoint) {
        switch appState.calibrationState {
        case .waitingForFirstPoint, .waitingForSecondPoint:
            appState.recordCalibrationTap(at: location)
            
            // Check if we need to show distance input
            if case .waitingForDistance = appState.calibrationState {
                showDistanceInput = true
            }
            
        case .waitingForDistance:
            // Already showing distance input
            break
            
        case .complete:
            // Could tap to recalibrate, or ignore
            break
        }
    }
    
    private func confirmDistance() {
        guard let value = Double(distanceInput), value > 0 else { return }
        let meters = selectedUnit.toMeters(value)
        appState.setKnownDistance(meters)
        showDistanceInput = false
    }
}

// MARK: - Calibration Point Marker

struct CalibrationPointMarker: View {
    let index: Int
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.yellow, lineWidth: 1.5)
                .frame(width: 25, height: 25)

            // Inner circle
            Circle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: 22, height: 22)

            // Crosshair
            VStack {
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 1, height: 10)
            }
            HStack {
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 10, height: 1)
            }

            // Number label
            Text("\(index)")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.black)
                .padding(3)
                .background(Color.yellow)
                .clipShape(Circle())
                .offset(x: 13, y: -13)
        }
    }
}

// MARK: - Calibration Line

struct CalibrationLine: View {
    let from: CGPoint
    let to: CGPoint
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            
            context.stroke(
                path,
                with: .color(.yellow),
                style: StrokeStyle(lineWidth: 3, dash: [10, 5])
            )
        }
    }
}

// MARK: - Instruction Banner

struct InstructionBanner: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.7))
            .cornerRadius(25)
    }
}

// MARK: - Distance Input Sheet

struct DistanceInputSheet: View {
    @Binding var distanceInput: String
    @Binding var selectedUnit: CalibrationView.DistanceUnit
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                Text("Enter Known Distance")
                    .font(.headline)
                
                HStack {
                    TextField("Distance", text: $distanceInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .frame(width: 100)
                    
                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(CalibrationView.DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.red)
                    
                    Button("Confirm") {
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(30)
            .background(.regularMaterial)
            .cornerRadius(20)
            .padding()
        }
        .background(Color.black.opacity(0.5))
    }
}

#Preview {
    CalibrationView()
        .environmentObject(AppState())
        .environmentObject(CameraManager())
}
