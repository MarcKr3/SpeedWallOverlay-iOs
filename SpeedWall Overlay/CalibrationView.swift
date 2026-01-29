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
            
            // Calibration points visualization
            ForEach(Array(appState.calibrationPoints.enumerated()), id: \.offset) { index, point in
                CalibrationPointMarker(index: index + 1)
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

            // Line between points
            if appState.calibrationPoints.count == 2 {
                CalibrationLine(
                    from: displayPosition(for: 0, basePoint: appState.calibrationPoints[0]),
                    to: displayPosition(for: 1, basePoint: appState.calibrationPoints[1])
                )
            }
            
            // Instructions overlay
            VStack {
                // Top instruction banner
                if appState.calibrationState != .complete || showCompleteBanner {
                    InstructionBanner(text: instructionText)
                        .padding(.top, 60)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 16) {
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
                                .padding(.horizontal, 24)
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
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(25)
                            }
                        }
                    }
                }
                .padding(.bottom, 50)
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
            .font(.headline.monospacedDigit())
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
    }
    
    // MARK: - Computed Properties
    
    private var instructionText: String {
        switch appState.calibrationState {
        case .waitingForFirstPoint:
            return "Tap the FIRST point of a known distance"
        case .waitingForSecondPoint:
            return "Tap the SECOND point"
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
                .stroke(Color.yellow, lineWidth: 3)
                .frame(width: 50, height: 50)
            
            // Inner circle
            Circle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: 44, height: 44)
            
            // Crosshair
            VStack {
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 2, height: 20)
            }
            HStack {
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 20, height: 2)
            }
            
            // Number label
            Text("\(index)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .padding(6)
                .background(Color.yellow)
                .clipShape(Circle())
                .offset(x: 25, y: -25)
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
