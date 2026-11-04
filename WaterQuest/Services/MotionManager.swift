import CoreMotion
import SwiftUI
import Combine

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    init() {
        startTracking()
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
    
    func startTracking() {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        
        // 30 Hz: the slosh is spring-animated, so faster samples only add main-thread work.
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let data = data, error == nil else { return }
            
            // Apply a low-pass filter or smoothing if needed, but for simple sloshing, raw attitude is often fine.
            // We clamp the values to prevent insane flipping.
            let clampedPitch = max(-(.pi / 4), min(.pi / 4, data.attitude.pitch))
            let clampedRoll = max(-(.pi / 4), min(.pi / 4, data.attitude.roll))
            
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                self?.pitch = clampedPitch
                self?.roll = clampedRoll
            }
        }
    }
    
    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
    }
}
