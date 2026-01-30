import CoreMotion
import SwiftUI
import Combine

@MainActor
class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    @Published var rollCorrection: Angle = .zero

    private var smoothedRoll: Double = 0
    private let smoothing: Double = 0.15  // low-pass filter factor

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let gravity = data?.gravity else { return }

            let raw = atan2(gravity.x, -gravity.y)

            // Clamp to +/-45 deg
            let clampLimit = Double.pi / 4
            let clamped = max(-clampLimit, min(clampLimit, raw))

            // Confidence: gravity projection onto screen plane
            let screenMag = sqrt(gravity.x * gravity.x + gravity.y * gravity.y)
            let confidence = max(0.0, min(1.0, (screenMag - 0.25) / 0.4))

            // Fade toward zero when confidence is low
            let target = clamped * confidence

            // Angle-aware EMA
            var delta = target - self.smoothedRoll
            if delta >  Double.pi { delta -= 2 * Double.pi }
            if delta < -Double.pi { delta += 2 * Double.pi }
            self.smoothedRoll += delta * self.smoothing

            self.rollCorrection = Angle(radians: -self.smoothedRoll)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        smoothedRoll = 0
        rollCorrection = .zero
    }
}
