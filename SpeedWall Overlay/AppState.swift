import SwiftUI
import UIKit
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

/// Parses user-entered distance values
enum DistanceInput {
    /// Accepts both "." and "," as decimal separator: the decimal pad inserts
    /// the locale's separator, but Double(String) only accepts ".".
    static func parse(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }
}

extension Color {
    /// Re-resolves the color in sRGB. The system color picker returns pure
    /// white/gray as 2-component grayscale-space colors, which the template
    /// image tint path can misrender as black.
    func normalizedToSRGB() -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Preset overlay colors. Applying one is instant; the system color picker
/// stays available for custom colors, but its first open in a process is
/// slow (~3.5 s on the simulator), so it is not the primary control.
enum OverlayPalette {
    struct Preset: Equatable {
        let name: String
        let color: Color
    }

    static let presets: [Preset] = [
        Preset(name: "White", color: Color(.sRGB, red: 1, green: 1, blue: 1)),
        Preset(name: "Yellow", color: Color(.sRGB, red: 1, green: 0.92, blue: 0.23)),
        Preset(name: "Orange", color: Color(.sRGB, red: 1, green: 0.6, blue: 0)),
        Preset(name: "Red", color: Color(.sRGB, red: 1, green: 0.23, blue: 0.19)),
        Preset(name: "Magenta", color: Color(.sRGB, red: 1, green: 0.18, blue: 0.9)),
        Preset(name: "Green", color: Color(.sRGB, red: 0.2, green: 0.9, blue: 0.3)),
        Preset(name: "Cyan", color: Color(.sRGB, red: 0.2, green: 0.9, blue: 1)),
        Preset(name: "Black", color: Color(.sRGB, red: 0, green: 0, blue: 0)),
    ]
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

    // MARK: - Welcome Popup

    /// UserDefaults key written by "Don't show again" on the startup popup.
    static let hideWelcomeKey = "hideWelcomePopup"

    private let defaults: UserDefaults

    /// Whether the startup popup is visible. True on every launch until the
    /// user checks "Don't show again".
    @Published var showWelcome: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showWelcome = !defaults.bool(forKey: Self.hideWelcomeKey)
    }

    /// Close the startup popup, optionally for good.
    func dismissWelcome(dontShowAgain: Bool) {
        if dontShowAgain {
            defaults.set(true, forKey: Self.hideWelcomeKey)
        }
        withAnimation(.easeOut(duration: 0.3)) {
            showWelcome = false
        }
    }

    // MARK: - Calibration Methods

    /// Points closer than this produce a degenerate px/m scale
    static let minimumCalibrationPixelDistance: CGFloat = 20

    /// Record a tap during calibration
    func recordCalibrationTap(at position: CGPoint) {
        switch calibrationState {
        case .waitingForFirstPoint:
            let point = CalibrationPoint(screenPosition: position, timestamp: Date())
            firstCalibrationPoint = point
            calibrationState = .waitingForSecondPoint(firstPoint: point)

        case .waitingForSecondPoint(let firstPoint):
            guard distance(from: firstPoint.screenPosition, to: position)
                    >= Self.minimumCalibrationPixelDistance else { return }
            let point = CalibrationPoint(screenPosition: position, timestamp: Date())
            secondCalibrationPoint = point
            calibrationState = .waitingForDistance(firstPoint: firstPoint, secondPoint: point)

        case .waitingForDistance, .complete:
            break
        }
    }

    /// Set the known distance and complete calibration
    func setKnownDistance(_ meters: Double) {
        guard meters.isFinite, meters > 0,
              let first = firstCalibrationPoint,
              let second = secondCalibrationPoint else { return }

        let pixelDistance = distance(from: first.screenPosition, to: second.screenPosition)
        guard pixelDistance > 0 else { return }

        knownDistanceMeters = meters
        pixelsPerMeter = pixelDistance / CGFloat(meters)
        calibrationState = .complete
    }

    /// Update a calibration point position and recalculate px/m
    func updatePointPosition(index: Int, newPosition: CGPoint) {
        guard calibrationState == .complete else { return }

        let other = index == 0 ? secondCalibrationPoint : firstCalibrationPoint
        if let other = other,
           distance(from: other.screenPosition, to: newPosition)
            < Self.minimumCalibrationPixelDistance {
            return
        }

        if index == 0 {
            firstCalibrationPoint?.screenPosition = newPosition
        } else {
            secondCalibrationPoint?.screenPosition = newPosition
        }

        // Recalculate pixelsPerMeter with updated positions
        guard let first = firstCalibrationPoint,
              let second = secondCalibrationPoint,
              knownDistanceMeters > 0 else { return }
        let pixelDistance = distance(from: first.screenPosition, to: second.screenPosition)
        pixelsPerMeter = pixelDistance / CGFloat(knownDistanceMeters)
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
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
