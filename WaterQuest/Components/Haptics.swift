import SwiftUI
import UIKit
import CoreHaptics

// MARK: - Haptics Manager
enum Haptics {
    private static var engine: CHHapticEngine?

    // MARK: - Basic Haptics
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    // MARK: - Advanced Haptic Patterns
    static func waterDrop() {
        playPattern(.waterDrop)
    }

    static func ripple() {
        playPattern(.ripple)
    }

    static func splash() {
        playPattern(.splash)
    }

    // MARK: - Core Haptics Engine
    private static func initializeEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = {
                do {
                    try engine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
            try engine?.start()
        } catch {
            print("Failed to initialize haptic engine: \(error)")
        }
    }

    private static func playPattern(_ pattern: HapticPattern) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            // Fallback to basic haptics
            impact(pattern.fallbackStyle)
            return
        }

        if engine == nil {
            initializeEngine()
        }

        do {
            let events = pattern.events
            let hapticPattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: hapticPattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Fallback
            impact(pattern.fallbackStyle)
        }
    }
}

// MARK: - Haptic Patterns
enum HapticPattern {
    case waterDrop
    case ripple
    case splash

    var fallbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .waterDrop: return .light
        case .ripple: return .medium
        case .splash: return .heavy
        }
    }

    var events: [CHHapticEvent] {
        switch self {
        case .waterDrop:
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0.05
                )
            ]

        case .ripple:
            var events: [CHHapticEvent] = []
            for i in 0..<4 {
                let intensity = 0.8 - Float(i) * 0.2
                let time = Double(i) * 0.08
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: time
                ))
            }
            return events

        case .splash:
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0.05,
                    duration: 0.15
                )
            ]
        }
    }
}

// MARK: - View Extensions
extension View {
    func hapticTap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        simultaneousGesture(TapGesture().onEnded {
            Haptics.impact(style)
        })
    }

    func hapticWaterDrop() -> some View {
        simultaneousGesture(TapGesture().onEnded {
            Haptics.waterDrop()
        })
    }

    func hapticRipple() -> some View {
        simultaneousGesture(TapGesture().onEnded {
            Haptics.ripple()
        })
    }

    func hapticOnChange<V: Equatable>(of value: V, perform haptic: @escaping () -> Void) -> some View {
        onChange(of: value) { _, _ in
            haptic()
        }
    }
}
