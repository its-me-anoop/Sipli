import CoreGraphics
import UIKit
import XCTest
@testable import Sipli

final class BottleWaterModelTests: XCTestCase {
    func testInitialBottleIsFullWithoutAnEntranceAnimation() {
        let model = BottleWaterModel(progress: 0)
        XCTAssertEqual(model.remaining, 1)
        XCTAssertEqual(model.targetRemaining, 1)
        XCTAssertEqual(model.tilt, 0)
        XCTAssertEqual(model.ripple, 0)
        XCTAssertTrue(model.isSettled)
    }

    func testIntakeConsumesBottleIncludingGoalAndOverGoal() {
        for (progress, remaining) in [(0.0, 1.0), (0.25, 0.75), (0.5, 0.5), (1, 0), (1.8, 0)] {
            let model = BottleWaterModel(progress: progress)
            XCTAssertEqual(model.remaining, remaining, accuracy: 0.000001)
            XCTAssertTrue(model.isSettled)
        }
    }

    func testInvalidProgressNeverProducesInvalidDrawingValues() {
        XCTAssertEqual(BottleWaterModel.remainingFraction(for: -0.5), 1)
        XCTAssertEqual(BottleWaterModel.remainingFraction(for: -.infinity), 1)
        XCTAssertEqual(BottleWaterModel.remainingFraction(for: .infinity), 0)
        XCTAssertEqual(BottleWaterModel.remainingFraction(for: .nan), 1)
    }

    func testLoggingDrainsSmoothlyAndMonotonicallyWithoutOvershoot() {
        var model = BottleWaterModel(progress: 0)
        model.setProgress(0.6, animated: true)
        XCTAssertEqual(model.remaining, 1)
        XCTAssertEqual(model.targetRemaining, 0.4, accuracy: 0.000001)
        XCTAssertGreaterThan(model.ripple, 0)
        XCTAssertFalse(model.isSettled)
        var previous = model.remaining
        for _ in 0..<180 {
            model.advance(by: 1.0 / 60)
            XCTAssertLessThanOrEqual(model.remaining, previous)
            XCTAssertGreaterThanOrEqual(model.remaining, model.targetRemaining)
            previous = model.remaining
        }
        XCTAssertEqual(model.remaining, 0.4, accuracy: 0.000001)
        XCTAssertTrue(model.isSettled)
    }

    func testUndoRefillsSmoothlyAndMonotonically() {
        var model = BottleWaterModel(progress: 0.8)
        model.setProgress(0.2, animated: true)
        var previous = model.remaining
        for _ in 0..<180 {
            model.advance(by: 1.0 / 60)
            XCTAssertGreaterThanOrEqual(model.remaining, previous)
            XCTAssertLessThanOrEqual(model.remaining, model.targetRemaining)
            previous = model.remaining
        }
        XCTAssertEqual(model.remaining, 0.8)
        XCTAssertTrue(model.isSettled)
    }

    func testRapidLogsRetargetTheCurrentLevelWithoutJumping() {
        var model = BottleWaterModel(progress: 0)
        model.setProgress(0.25, animated: true)
        model.advance(by: 0.1)
        let current = model.remaining
        model.setProgress(0.7, animated: true)
        XCTAssertEqual(model.remaining, current)
        XCTAssertEqual(model.targetRemaining, 0.3, accuracy: 0.000001)
        advanceToRest(&model)
        XCTAssertEqual(model.remaining, 0.3, accuracy: 0.000001)
    }

    func testReducedMotionUpdatesImmediatelyWithoutRipples() {
        var model = BottleWaterModel(progress: 0)
        model.setProgress(0.5, animated: false)
        XCTAssertEqual(model.remaining, 0.5)
        XCTAssertEqual(model.ripple, 0)
        XCTAssertEqual(model.phase, 0)
        XCTAssertTrue(model.isSettled)
    }

    func testRepeatedUnchangedIntakeDoesNotWakeWater() {
        var model = BottleWaterModel(progress: 0.4)
        model.setProgress(0.4, animated: true)
        XCTAssertTrue(model.isSettled)
        XCTAssertEqual(model.ripple, 0)
    }

    func testGravityTiltsInBothDirectionsAndClampsAtTheLimit() {
        for x in [-0.5, 0.5] {
            var model = BottleWaterModel(progress: 0.5)
            model.setGravity(x: x, y: -sqrt(0.75))
            advanceToRest(&model)
            XCTAssertEqual(model.tilt, atan2(-x, sqrt(0.75)), accuracy: 0.0001)
            XCTAssertEqual(model.remaining, 0.5)
        }
        var extreme = BottleWaterModel(progress: 0.5)
        extreme.setGravity(x: -1, y: 0)
        advanceToRest(&extreme)
        XCTAssertEqual(extreme.tilt, 35 * .pi / 180, accuracy: 0.0001)
    }

    func testFlatPhoneKeepsItsLastStableAngle() {
        var model = BottleWaterModel(progress: 0.5)
        model.setGravity(x: -0.4, y: -0.9)
        advanceToRest(&model)
        let angle = model.tilt
        for (x, y) in [(0.0, 0.0), (0.01, -0.02), (-0.04, 0.01)] {
            model.setGravity(x: x, y: y)
            model.advance(by: 1.0 / 60)
            XCTAssertEqual(model.tilt, angle)
            XCTAssertTrue(model.isSettled)
        }
    }

    func testSensorJitterDoesNotWakeIdleAnimationButSlowTiltAccumulates() {
        var model = BottleWaterModel(progress: 0.5)
        for index in 0..<300 {
            model.setGravity(x: index.isMultiple(of: 2) ? 0.001 : -0.001, y: -1)
            XCTAssertTrue(model.isSettled)
        }
        for index in 1...8 {
            model.setGravity(x: Double(index) * 0.001, y: -1)
        }
        XCTAssertFalse(model.isSettled)
        advanceToRest(&model)
        XCTAssertLessThan(model.tilt, -0.003)
    }

    func testAccelerationCreatesFiniteRipplesWithoutChangingVolume() {
        var model = BottleWaterModel(progress: 0.5)
        model.setGravity(x: 0, y: -1, acceleration: 0.7)
        XCTAssertGreaterThan(model.ripple, 0)
        advanceToRest(&model)
        XCTAssertTrue(model.isSettled)
        XCTAssertEqual(model.remaining, 0.5)
        XCTAssertEqual(model.tilt, 0)
    }

    func testInvalidSensorSamplesAreIgnored() {
        var model = BottleWaterModel(progress: 0.5)
        model.setGravity(x: .nan, y: -1)
        model.setGravity(x: 0, y: .infinity)
        model.setGravity(x: 0, y: -1, acceleration: .nan)
        XCTAssertTrue(model.isSettled)
        XCTAssertEqual(model.tilt, 0)
    }

    func testInvalidAndDelayedFramesCannotCorruptOrJumpTheWater() {
        var model = BottleWaterModel(progress: 0)
        model.setProgress(0.5, animated: true)
        let initialRipple = model.ripple
        for dt in [Double.nan, .infinity, -.infinity, -1, 0] {
            model.advance(by: dt)
            XCTAssertEqual(model.remaining, 1)
            XCTAssertEqual(model.phase, 0)
            XCTAssertEqual(model.ripple, initialRipple)
        }
        model.advance(by: 600)
        XCTAssertGreaterThan(model.remaining, 0.7)
        XCTAssertLessThan(model.remaining, 1)
        XCTAssertTrue(model.phase.isFinite)
        advanceToRest(&model)
        XCTAssertTrue(model.isSettled)
    }

    func testTransientPhaseDoesNotWrapAndStopsCompletelyAfterSettling() {
        var model = BottleWaterModel(progress: 0)
        model.setProgress(1, animated: true)
        for _ in 0..<90 { model.advance(by: 1.0 / 60) }
        XCTAssertGreaterThan(model.phase, 2 * .pi)
        advanceToRest(&model)
        let phase = model.phase
        for _ in 0..<600 { model.advance(by: 1.0 / 60) }
        XCTAssertEqual(model.phase, phase)
        XCTAssertEqual(model.ripple, 0)
        XCTAssertEqual(model.remaining, 0)
        XCTAssertTrue(model.isSettled)
    }

    func testSettleFinishesVolumeTiltAndRipplesImmediately() {
        var model = BottleWaterModel(progress: 0)
        model.setProgress(0.75, animated: true)
        model.setGravity(x: 0.3, y: -0.95)
        model.settle()
        XCTAssertEqual(model.remaining, 0.25)
        XCTAssertEqual(model.tilt, atan2(-0.3, 0.95), accuracy: 0.0001)
        XCTAssertEqual(model.ripple, 0)
        XCTAssertTrue(model.isSettled)
    }

    func testFullAndEmptySurfacesRespectPhotoInterior() {
        let size = CGSize(width: 124, height: 174.8)
        XCTAssertEqual(BottleWaterGeometry.surfaceY(remaining: 1, tilt: 0, size: size),
                       size.height * 0.265, accuracy: 0.00001)
        XCTAssertEqual(BottleWaterGeometry.surfaceY(remaining: 0, tilt: 0, size: size),
                       size.height * 0.94, accuracy: 0.00001)
        let outline = BottleWaterGeometry.outline(size: size)
        XCTAssertEqual(outline.map(\.x).min()!, size.width * 0.25, accuracy: 0.00001)
        XCTAssertEqual(outline.map(\.x).max()!, size.width * 0.736, accuracy: 0.00001)
        XCTAssertEqual(outline.map(\.y).min()!, size.height * 0.247, accuracy: 0.00001)
        XCTAssertEqual(outline.map(\.y).max()!, size.height * 0.94, accuracy: 0.00001)
    }

    func testTiltingPreservesWaterVolumeAtFullMiddleAndNearlyEmptyLevels() {
        for size in [CGSize(width: 124, height: 174.8), CGSize(width: 210, height: 300)] {
            let capacity = integratedWaterArea(size: size, surface: size.height * 0.265, tilt: 0)
            for remaining in [0.03, 0.25, 0.5, 0.8, 1] {
                for tilt in [-0.61, -0.3, 0, 0.3, 0.61] {
                    let surface = BottleWaterGeometry.surfaceY(remaining: remaining, tilt: tilt, size: size)
                    let area = integratedWaterArea(size: size, surface: surface, tilt: tilt)
                    XCTAssertEqual(area / capacity, remaining, accuracy: 0.0005,
                                   "Volume changed at remaining=\(remaining), tilt=\(tilt)")
                }
            }
        }
    }

    func testSurfaceMovesDownContinuouslyAsBottleDrains() {
        let size = CGSize(width: 124, height: 174.8)
        for tilt in [-0.6, 0, 0.6] {
            var previous = -Double.infinity
            for percent in stride(from: 100, through: 1, by: -1) {
                let level = BottleWaterGeometry.surfaceY(remaining: Double(percent) / 100,
                                                        tilt: tilt, size: size)
                XCTAssertGreaterThan(level, previous)
                previous = level
            }
        }
    }

    func testGeometryHandlesInvalidInputsWithoutNonfiniteCoordinates() {
        for size in [CGSize.zero, CGSize(width: -1, height: 100), CGSize(width: CGFloat.infinity, height: 100)] {
            XCTAssertTrue(BottleWaterGeometry.outline(size: size).isEmpty)
            XCTAssertEqual(BottleWaterGeometry.surfaceY(remaining: 0.5, tilt: 0, size: size), 0)
        }
        let size = CGSize(width: 124, height: 174.8)
        for remaining in [Double.nan, .infinity, -.infinity, -1, 2] {
            for tilt in [Double.nan, .infinity, -.infinity, 0] {
                XCTAssertTrue(BottleWaterGeometry.surfaceY(remaining: remaining, tilt: tilt, size: size).isFinite)
            }
        }
    }

    @MainActor
    func testControllerStartsAtRestAndStopsAnimationWhenHomeDisappears() {
        let controller = BottleWaterAnimation(progress: 0)
        XCTAssertFalse(controller.isActive)
        XCTAssertFalse(controller.isAnimating)
        controller.setActive(true, reduceMotion: false)
        XCTAssertTrue(controller.isActive)
        XCTAssertFalse(controller.isAnimating)
        controller.setProgress(0.5, animated: true)
        XCTAssertTrue(controller.isAnimating)
        XCTAssertEqual(controller.frame.remaining, 1)
        controller.setActive(false, reduceMotion: false)
        XCTAssertFalse(controller.isActive)
        XCTAssertFalse(controller.isAnimating)
        XCTAssertEqual(controller.frame.remaining, 0.5)
        XCTAssertTrue(controller.frame.isSettled)
    }

    @MainActor
    func testControllerReducedMotionAlwaysUpdatesImmediatelyAndIgnoresSensors() {
        let controller = BottleWaterAnimation(progress: 0)
        controller.setActive(true, reduceMotion: true)
        controller.setProgress(0.75, animated: true)
        controller.receiveGravity(x: 0.5, y: -0.8, acceleration: 1)
        XCTAssertTrue(controller.isReducedMotion)
        XCTAssertEqual(controller.frame.remaining, 0.25)
        XCTAssertEqual(controller.frame.tilt, 0)
        XCTAssertEqual(controller.frame.ripple, 0)
        XCTAssertFalse(controller.isAnimating)
        controller.setActive(false, reduceMotion: true)
    }

    @MainActor
    func testControllerOffscreenIgnoresGravityAndUsesLatestIntakeOnReturn() {
        let controller = BottleWaterAnimation(progress: 0)
        controller.receiveGravity(x: 0.5, y: -0.8, acceleration: 1)
        controller.setProgress(0.7, animated: true)
        XCTAssertFalse(controller.isAnimating)
        XCTAssertEqual(controller.frame.remaining, 0.3, accuracy: 0.000001)
        XCTAssertEqual(controller.frame.tilt, 0)
        controller.setActive(true, reduceMotion: false)
        XCTAssertEqual(controller.frame.remaining, 0.3, accuracy: 0.000001)
        XCTAssertFalse(controller.isAnimating)
        controller.setActive(false, reduceMotion: false)
    }

    @MainActor
    func testControllerMotionWakesDisplayLinkAndReduceMotionStopsIt() {
        let controller = BottleWaterAnimation(progress: 0.5)
        controller.setActive(true, reduceMotion: false)
        controller.receiveGravity(x: 0.4, y: -0.9)
        XCTAssertTrue(controller.isAnimating)
        controller.setActive(true, reduceMotion: true)
        XCTAssertFalse(controller.isAnimating)
        XCTAssertTrue(controller.frame.isSettled)
        XCTAssertEqual(controller.frame.tilt, 0)
        controller.setActive(false, reduceMotion: true)
    }

    @MainActor
    func testControllerNoiseDoesNotStartDisplayLink() {
        let controller = BottleWaterAnimation(progress: 0.5)
        controller.setActive(true, reduceMotion: false)
        for index in 0..<100 {
            controller.receiveGravity(x: index.isMultiple(of: 2) ? 0.001 : -0.001, y: -1)
        }
        XCTAssertFalse(controller.isAnimating)
        controller.setActive(false, reduceMotion: false)
    }

    @MainActor
    func testDisplayLinkDoesNotRetainAReleasedController() {
        var controller: BottleWaterAnimation? = BottleWaterAnimation(progress: 0)
        weak var weakController = controller
        controller?.setActive(true, reduceMotion: false)
        controller?.setProgress(0.5, animated: true)
        XCTAssertTrue(controller?.isAnimating == true)
        controller = nil
        XCTAssertNil(weakController)
    }

    @MainActor
    func testScreenGravityMapsEveryUprightInterfaceOrientationToLevel() {
        let cases: [(UIInterfaceOrientation, Double, Double)] = [
            (.portrait, 0, -1), (.portraitUpsideDown, 0, 1),
            (.landscapeLeft, 1, 0), (.landscapeRight, -1, 0)
        ]
        for (orientation, x, y) in cases {
            let gravity = BottleWaterAnimation.screenGravity(x: x, y: y, orientation: orientation)
            XCTAssertEqual(gravity.x, 0, accuracy: 0.000001)
            XCTAssertEqual(gravity.y, -1, accuracy: 0.000001)
        }
    }

    @MainActor
    func testScreenGravityRotatesTiltInTheCorrectDirection() {
        let portrait = BottleWaterAnimation.screenGravity(x: -0.3, y: -0.95, orientation: .portrait)
        let left = BottleWaterAnimation.screenGravity(x: 0.95, y: -0.3, orientation: .landscapeLeft)
        let right = BottleWaterAnimation.screenGravity(x: -0.95, y: 0.3, orientation: .landscapeRight)
        XCTAssertEqual(left.x, portrait.x)
        XCTAssertEqual(left.y, portrait.y)
        XCTAssertEqual(right.x, portrait.x)
        XCTAssertEqual(right.y, portrait.y)
    }

    private func advanceToRest(_ model: inout BottleWaterModel) {
        for _ in 0..<180 { model.advance(by: 1.0 / 60) }
    }

    /// Independent midpoint integration along vertical strips checks the
    /// solver's polygon-clipping area without reusing its implementation.
    private func integratedWaterArea(size: CGSize, surface: Double, tilt: Double) -> Double {
        let polygon = BottleWaterGeometry.outline(size: size)
        let steps = 1_600
        let dx = size.width / Double(steps)
        var area = 0.0
        for step in 0..<steps {
            let x = (Double(step) + 0.5) * dx
            var intersections: [Double] = []
            for index in polygon.indices {
                let a = polygon[index]
                let b = polygon[(index + 1) % polygon.count]
                guard (a.x <= x && b.x > x) || (b.x <= x && a.x > x) else { continue }
                intersections.append(a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y))
            }
            guard let top = intersections.min(), let bottom = intersections.max() else { continue }
            let waterTop = surface + tan(tilt) * (x - size.width / 2)
            area += max(0, bottom - max(top, waterTop)) * dx
        }
        return area
    }
}
