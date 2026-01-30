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
            let raw = atan2(gravity.x, -gravity.y)  // 0 when upright
            self.smoothedRoll += (raw - self.smoothedRoll) * self.smoothing
            self.rollCorrection = Angle(radians: -self.smoothedRoll)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        smoothedRoll = 0
        rollCorrection = .zero
    }
}
