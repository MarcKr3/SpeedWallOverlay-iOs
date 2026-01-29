import SwiftUI
import Combine

/// Represents a calibration point tapped by the user
struct CalibrationPoint: Equatable {
    let screenPosition: CGPoint
    let timestamp: Date
}

/// The current mode of the app
enum AppMode: Equatable {
    case calibration
    case templateSelection
    case overlay
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
    
    /// Calculated pixels per meter based on calibration
    @Published private(set) var pixelsPerMeter: CGFloat = 0
    
    /// The current screen size (needed for calculations)
    @Published var screenSize: CGSize = .zero
    
    /// Template image scroll offset (0.0 to 1.0, representing position in the tall image)
    @Published var templateScrollOffset: CGFloat = 0.0
    
    /// Height of the visible template section (in real-world meters)
    @Published var templateVisibleHeightMeters: Double = 0.5
    
    /// Opacity of the overlay
    @Published var overlayOpacity: Double = 0.5
    
    /// The overlay scale factor
    @Published var overlayScale: CGFloat = 1.0
    
    // MARK: - Private Properties
    
    private var firstCalibrationPoint: CalibrationPoint?
    private var secondCalibrationPoint: CalibrationPoint?
    
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
    
    /// Reset calibration
    func resetCalibration() {
        calibrationState = .waitingForFirstPoint
        firstCalibrationPoint = nil
        secondCalibrationPoint = nil
        pixelsPerMeter = 0
    }
    
    /// Move to template selection after calibration
    func proceedToTemplateSelection() {
        guard calibrationState == .complete else { return }
        mode = .templateSelection
    }
    
    /// Move to overlay mode
    func proceedToOverlay() {
        mode = .overlay
    }
    
    /// Go back to calibration
    func backToCalibration() {
        mode = .calibration
    }
    
    /// Go back to template selection
    func backToTemplateSelection() {
        mode = .templateSelection
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
    
    /// The pixel height of the visible template section on screen
    var templateVisibleHeightPixels: CGFloat {
        CGFloat(templateVisibleHeightMeters) * pixelsPerMeter * overlayScale
    }
}
