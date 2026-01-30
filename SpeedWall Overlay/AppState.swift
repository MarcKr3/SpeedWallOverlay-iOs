import SwiftUI
import Combine

/// Represents a calibration point tapped by the user
struct CalibrationPoint: Equatable {
    var screenPosition: CGPoint
    let timestamp: Date
}

/// The current mode of the app
enum AppMode: Equatable {
    case calibration
    case overlay
}

/// Distance unit for calibration input
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

/// Calibration state tracking
enum CalibrationState: Equatable {
    case waitingForFirstPoint
    case waitingForSecondPoint(firstPoint: CalibrationPoint)
    case waitingForDistance(firstPoint: CalibrationPoint, secondPoint: CalibrationPoint)
    case complete
}

/// Main app state container
@MainActor
class AppState: ObservableObject {

    // MARK: - Published Properties

    @Published var mode: AppMode = .calibration
    @Published var calibrationState: CalibrationState = .waitingForFirstPoint

    /// The real-world distance the user specified (in meters)
    @Published var knownDistanceMeters: Double = 1.0

    /// Distance input text persisted across view lifecycle
    @Published var distanceInputText: String = "1.0"

    /// Selected distance unit persisted across view lifecycle
    @Published var selectedDistanceUnit: DistanceUnit = .meters

    /// Calculated pixels per meter based on calibration
    @Published private(set) var pixelsPerMeter: CGFloat = 0

    /// The current screen size (needed for calculations)
    @Published var screenSize: CGSize = .zero

    /// Layer visibility toggles
    @Published var showGrid: Bool = false
    @Published var showLabels: Bool = false

    /// Overlay color for image layers
    @Published var overlayColor: Color = .black

    /// Perspective tilt adjustments (degrees)
    @Published var horizontalTilt: Double = 0
    @Published var verticalTilt: Double = 0

    /// Auto-level using device motion
    @Published var autoLevel: Bool = false

    // MARK: - Internal Properties

    @Published var firstCalibrationPoint: CalibrationPoint?
    @Published var secondCalibrationPoint: CalibrationPoint?

    // MARK: - Calibration Methods

    /// Record a tap during calibration
    func recordCalibrationTap(at position: CGPoint) {
        switch calibrationState {
        case .waitingForFirstPoint:
            let point = CalibrationPoint(screenPosition: position, timestamp: Date())
            firstCalibrationPoint = point
            calibrationState = .waitingForSecondPoint(firstPoint: point)

        case .waitingForSecondPoint(let firstPoint):
            let point = CalibrationPoint(screenPosition: position, timestamp: Date())
            secondCalibrationPoint = point
            calibrationState = .waitingForDistance(firstPoint: firstPoint, secondPoint: point)

        case .waitingForDistance, .complete:
            break
        }
    }

    /// Set the known distance and complete calibration
    func setKnownDistance(_ meters: Double) {
        guard let first = firstCalibrationPoint,
              let second = secondCalibrationPoint else { return }

        knownDistanceMeters = meters

        // Calculate pixel distance between the two points
        let dx = second.screenPosition.x - first.screenPosition.x
        let dy = second.screenPosition.y - first.screenPosition.y
        let pixelDistance = sqrt(dx * dx + dy * dy)

        // Calculate pixels per meter
        pixelsPerMeter = pixelDistance / CGFloat(meters)

        calibrationState = .complete

        print("Calibration complete: \(pixelsPerMeter) pixels/meter")
    }

    /// Update a calibration point position and recalculate px/m
    func updatePointPosition(index: Int, newPosition: CGPoint) {
        guard calibrationState == .complete else { return }
        if index == 0 {
            firstCalibrationPoint?.screenPosition = newPosition
        } else {
            secondCalibrationPoint?.screenPosition = newPosition
        }

        // Recalculate pixelsPerMeter with updated positions
        guard let first = firstCalibrationPoint,
              let second = secondCalibrationPoint,
              knownDistanceMeters > 0 else { return }
        let dx = second.screenPosition.x - first.screenPosition.x
        let dy = second.screenPosition.y - first.screenPosition.y
        let pixelDistance = sqrt(dx * dx + dy * dy)
        pixelsPerMeter = pixelDistance / CGFloat(knownDistanceMeters)
    }

    /// Reset calibration
    func resetCalibration() {
        withAnimation(.easeOut(duration: 0.3)) {
            calibrationState = .waitingForFirstPoint
            firstCalibrationPoint = nil
            secondCalibrationPoint = nil
            pixelsPerMeter = 0
        }
    }

    /// Move to overlay mode
    func proceedToOverlay() {
        guard calibrationState == .complete else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            mode = .overlay
        }
    }

    /// Go back to calibration
    func backToCalibration() {
        withAnimation(.easeOut(duration: 0.3)) {
            mode = .calibration
        }
    }

    // MARK: - Computed Properties

    /// The calibration points for display
    var calibrationPoints: [CGPoint] {
        var points: [CGPoint] = []
        if let first = firstCalibrationPoint {
            points.append(first.screenPosition)
        }
        if let second = secondCalibrationPoint {
            points.append(second.screenPosition)
        }
        return points
    }

    /// Whether calibration is done
    var isCalibrated: Bool {
        calibrationState == .complete && pixelsPerMeter > 0
    }
}
