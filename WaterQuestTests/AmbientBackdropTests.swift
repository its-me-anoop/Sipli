import SwiftUI
import XCTest
@testable import Sipli

final class AmbientBackdropTests: XCTestCase {
    // MARK: - When the backdrop moves

    private func policy(
        reduceMotion: Bool = false,
        lowPower: Bool = false,
        active: Bool = true,
        visible: Bool = true
    ) -> AmbientBackdropPolicy {
        AmbientBackdropPolicy(
            reduceMotion: reduceMotion,
            isLowPowerMode: lowPower,
            isSceneActive: active,
            isVisible: visible
        )
    }

    func testAnimatesOnlyWhenVisibleInTheActiveApp() {
        XCTAssertEqual(policy().mode, .animated)
    }

    func testReduceMotionDrawsTheRestingPoseEvenWhenVisible() {
        XCTAssertEqual(policy(reduceMotion: true).mode, .still)
        XCTAssertEqual(policy(reduceMotion: true, active: false, visible: false).mode, .still)
    }

    func testPausesOffscreenSoHiddenTabsAndCoveredScreensCostNothing() {
        XCTAssertEqual(policy(visible: false).mode, .paused)
    }

    func testPausesWhileTheAppIsInactiveOrInTheBackground() {
        XCTAssertEqual(policy(active: false).mode, .paused)
    }

    func testPausesInLowPowerMode() {
        XCTAssertEqual(policy(lowPower: true).mode, .paused)
    }

    func testFrameRateIsFarBelowTheDisplayRefreshRate() {
        // 120 Hz ProMotion would be 1/120 s; the backdrop must stay at or below 30 fps.
        XCTAssertGreaterThanOrEqual(AmbientBackdropPolicy.frameInterval, 1.0 / 30.0)
    }

    // MARK: - Motion stays smooth at that frame rate

    func testBlobsMoveLessThanOnePointPerFrameAtTheCappedRate() {
        let interval = AmbientBackdropPolicy.frameInterval
        var time: TimeInterval = 0
        while time < 120 {
            let now = AmbientBackdropMotion(time: time)
            let next = AmbientBackdropMotion(time: time + interval)
            XCTAssertLessThan(now.maxBlobDistance(to: next), 1.0, "at t=\(time)")
            time += 0.37
        }
    }

    func testMotionAtTimeZeroIsTheRestingPose() {
        let rest = AmbientBackdropMotion(time: 0)
        XCTAssertEqual(rest.blobA.width, -72, accuracy: 0.0001)
        XCTAssertEqual(rest.blobA.height, -140, accuracy: 0.0001)
        XCTAssertEqual(rest.blobB.width, 120, accuracy: 0.0001)
        XCTAssertEqual(rest.blobC.height, 370, accuracy: 0.0001)
    }

    // MARK: - Soft blob looks like a blurred circle

    func testSoftBlobFadesFromCentreToNothing() {
        let profile = SoftBlobProfile(radius: 150, blur: 70)
        var previous = profile.opacity(at: 0)
        var distance: CGFloat = 10
        while distance <= profile.outerRadius {
            let value = profile.opacity(at: distance)
            XCTAssertLessThanOrEqual(value, previous + 0.000001, "at \(distance)")
            previous = value
            distance += 10
        }
        XCTAssertLessThan(profile.opacity(at: profile.outerRadius), 0.01)
    }

    func testSoftBlobCentreMatchesAGaussianBlurredDisc() {
        // A disc of radius R blurred with sigma has 1 - exp(-R² / 2σ²) at its centre.
        let profile = SoftBlobProfile(radius: 150, blur: 70)
        let expected = 1 - exp(-(150.0 * 150.0) / (2 * 70.0 * 70.0))
        XCTAssertEqual(profile.opacity(at: 0), expected, accuracy: 0.0001)
    }

    func testSoftBlobEdgeIsAboutHalfStrength() {
        let profile = SoftBlobProfile(radius: 150, blur: 70)
        XCTAssertEqual(profile.opacity(at: 150), 0.46, accuracy: 0.05)
    }

    func testSoftBlobStopsSpanTheWholeGradientAndEndTransparent() {
        let stops = SoftBlobProfile(radius: 120, blur: 64).stops(color: .blue, count: 12)
        XCTAssertEqual(stops.count, 12)
        XCTAssertEqual(stops.first?.location, 0)
        XCTAssertEqual(stops.last?.location, 1)
        XCTAssertEqual(stops.map(\.location), stops.map(\.location).sorted())
    }

    func testSoftBlobNeverProducesInvalidOpacity() {
        for profile in [SoftBlobProfile(radius: 0, blur: 70),
                        SoftBlobProfile(radius: 150, blur: 0),
                        SoftBlobProfile(radius: -10, blur: -5)] {
            for distance in stride(from: CGFloat(0), through: 500, by: 25) {
                let value = profile.opacity(at: distance)
                XCTAssertFalse(value.isNaN)
                XCTAssertGreaterThanOrEqual(value, 0)
                XCTAssertLessThanOrEqual(value, 1)
            }
        }
    }
}
