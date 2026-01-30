import SwiftUI

private let CalibrationAccent = Color(red: 1.0, green: 0.655, blue: 0.149) // Material Orange 400 (#FFA726)

struct CalibrationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cameraManager: CameraManager
    
    @State private var showDistanceInput = false
    @State private var draggingPointIndex: Int? = nil
    @State private var dragStartBasePosition: CGPoint? = nil
    @State private var draggingLine = false
    @State private var lineDragOffset: CGSize = .zero
    @State private var showCompleteBanner = false
    @State private var showAbout = false
    
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
                    from: displayPosition(for: 0),
                    to: displayPosition(for: 1)
                )
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            // Distance label at midpoint of calibration line
            if appState.calibrationState == .complete && appState.calibrationPoints.count == 2 {
                let p1 = displayPosition(for: 0)
                let p2 = displayPosition(for: 1)
                let angle = atan2(p2.y - p1.y, p2.x - p1.x)
                // Keep text readable: flip if label would be upside-down
                let correctedAngle = (angle > .pi / 2 || angle < -.pi / 2)
                    ? angle + .pi : angle
                Text("\(appState.distanceInputText) \(appState.selectedDistanceUnit.rawValue)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(CalibrationAccent)
                    .cornerRadius(14)
                    .rotationEffect(Angle(radians: correctedAngle))
                    .position(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation { showDistanceInput = true }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 3)
                            .onChanged { value in
                                draggingLine = true
                                // Counter-rotate drag translation from rotated local space to screen space
                                let cosA = cos(correctedAngle)
                                let sinA = sin(correctedAngle)
                                let dx = value.translation.width
                                let dy = value.translation.height
                                lineDragOffset = CGSize(
                                    width: dx * cosA - dy * sinA,
                                    height: dx * sinA + dy * cosA
                                )
                            }
                            .onEnded { value in
                                let cosA = cos(correctedAngle)
                                let sinA = sin(correctedAngle)
                                let dx = value.translation.width
                                let dy = value.translation.height
                                let screenOffset = CGSize(
                                    width: dx * cosA - dy * sinA,
                                    height: dx * sinA + dy * cosA
                                )
                                for i in 0..<appState.calibrationPoints.count {
                                    let old = appState.calibrationPoints[i]
                                    let newPos = CGPoint(x: old.x + screenOffset.width, y: old.y + screenOffset.height)
                                    appState.updatePointPosition(index: i, newPosition: newPos)
                                }
                                draggingLine = false
                                lineDragOffset = .zero
                            }
                    )
            }

            // Calibration points visualization
            ForEach(Array(appState.calibrationPoints.indices), id: \.self) { index in
                CalibrationPointMarker(index: index + 1)
                    .contentShape(Circle().size(width: 34, height: 34).offset(x: -5, y: -5))
                    .position(displayPosition(for: index))
                    .transition(.opacity)
                    .gesture(
                        appState.calibrationState == .complete ?
                        DragGesture()
                            .onChanged { value in
                                if draggingPointIndex != index {
                                    draggingPointIndex = index
                                    dragStartBasePosition = appState.calibrationPoints[index]
                                }
                                if let base = dragStartBasePosition {
                                    appState.updatePointPosition(index: index, newPosition: CGPoint(
                                        x: base.x + value.translation.width,
                                        y: base.y + value.translation.height
                                    ))
                                }
                            }
                            .onEnded { _ in
                                draggingPointIndex = nil
                                dragStartBasePosition = nil
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
                VStack(spacing: 12) {
                    if appState.calibrationState == .complete {
                        calibrationCompleteView
                            .transition(.opacity)
                    }

                    HStack(spacing: 20) {
                        // Reset — hidden until first marker placed
                        if appState.calibrationState != .waitingForFirstPoint {
                            Button(action: { appState.resetCalibration() }) {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                                    .font(.headline)
                                    .frame(minWidth: 130)
                                    .padding(.vertical, 12)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(25)
                            }
                            .transition(.opacity)
                        }

                        // Continue — when calibration complete
                        if appState.isCalibrated {
                            Button(action: { appState.proceedToOverlay() }) {
                                Label("Continue", systemImage: "arrow.right")
                                    .font(.headline)
                                    .frame(minWidth: 130)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(25)
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottomLeading) {
                        // Info button — only in initial state, doesn't affect layout
                        if appState.calibrationState == .waitingForFirstPoint && !showAbout {
                            Button(action: { withAnimation { showAbout = true } }) {
                                Text("i")
                                    .font(.system(size: 13, weight: .semibold, design: .serif))
                                    .italic()
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .frame(minWidth: 100, minHeight: 100)
                            .contentShape(Circle())
                            .accessibilityLabel("About this app")
                            .transition(.opacity)
                        }
                    }
                }
                .animation(.easeOut(duration: 0.3), value: appState.calibrationState)
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
                        Button("Close") { withAnimation { showAbout = false } }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(30)
                    .background(.regularMaterial)
                    .cornerRadius(20)
                    .padding()
                }
                .background(Color.black.opacity(0.5))
                .transition(.opacity)
            }

            // Distance input sheet
            if showDistanceInput {
                DistanceInputSheet(
                    distanceInput: $appState.distanceInputText,
                    selectedUnit: $appState.selectedDistanceUnit,
                    onConfirm: confirmDistance,
                    onCancel: {
                        if case .waitingForDistance = appState.calibrationState {
                            appState.setKnownDistance(1.0)
                        }
                        withAnimation { showDistanceInput = false }
                    }
                )
                .transition(.opacity)
                .zIndex(1)
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
                withAnimation { showDistanceInput = true }
            }
    }

    // MARK: - Computed Properties
    
    private var instructionText: LocalizedStringKey {
        switch appState.calibrationState {
        case .waitingForFirstPoint:
            return "Tap first point of known distance"
        case .waitingForSecondPoint:
            return "Tap second point"
        case .waitingForDistance:
            return "Enter the distance between points"
        case .complete:
            return "Calibration complete!"
        }
    }
    
    // MARK: - Helpers

    private func displayPosition(for index: Int) -> CGPoint {
        var point = appState.calibrationPoints[index]
        if draggingLine {
            point.x += lineDragOffset.width
            point.y += lineDragOffset.height
        }
        return point
    }

    // MARK: - Actions

    private func handleTap(at location: CGPoint) {
        switch appState.calibrationState {
        case .waitingForFirstPoint, .waitingForSecondPoint:
            withAnimation(.easeOut(duration: 0.2)) {
                appState.recordCalibrationTap(at: location)
            }

            // Check if we need to show distance input
            if case .waitingForDistance = appState.calibrationState {
                withAnimation { showDistanceInput = true }
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
        guard let value = Double(appState.distanceInputText), value > 0 else { return }
        let meters = appState.selectedDistanceUnit.toMeters(value)
        appState.setKnownDistance(meters)
        withAnimation { showDistanceInput = false }
    }
}

// MARK: - Calibration Point Marker

struct CalibrationPointMarker: View {
    let index: Int
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(CalibrationAccent, lineWidth: 1.5)
                .frame(width: 25, height: 25)

            // Inner circle
            Circle()
                .fill(CalibrationAccent.opacity(0.3))
                .frame(width: 22, height: 22)

            // Crosshair
            VStack {
                Rectangle()
                    .fill(CalibrationAccent)
                    .frame(width: 1, height: 10)
            }
            HStack {
                Rectangle()
                    .fill(CalibrationAccent)
                    .frame(width: 10, height: 1)
            }

            // Number label
            Text("\(index)")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.black)
                .padding(3)
                .background(CalibrationAccent)
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
                with: .color(CalibrationAccent),
                style: StrokeStyle(lineWidth: 3, dash: [10, 5])
            )
        }
    }
}

// MARK: - Instruction Banner

struct InstructionBanner: View {
    let text: LocalizedStringKey

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
    @Binding var selectedUnit: DistanceUnit
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

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
                            ForEach(DistanceUnit.allCases, id: \.self) { unit in
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
        }
    }
}

#Preview {
    CalibrationView()
        .environmentObject(AppState())
        .environmentObject(CameraManager())
}
