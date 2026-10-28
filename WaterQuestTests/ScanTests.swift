import XCTest
import UIKit
import SwiftUI
@testable import Sipli

final class ScanTests: XCTestCase {
    func testMetricLabelsAndNutritionAreSeparated() {
        for (text, expected) in [("WATER\n500 ml\nNutrition per 100 ml", 500.0), ("EAU\n1,5 L\npour 100 ml",1500), ("SODA\n33 cl\nper 100ml",330), ("Water 0.75 L",750)] {
            XCTAssertEqual(ScanLabelEvidence.candidates(in: text).map(\.ml), [expected], text)
        }
        for text in ["Nutrition per 100 ml", "Serving size 250 ml", "6 x 330 ml", "1,000 ml", "10000 ml", "-500 ml", "16.9 fl oz", "500 g", "a glass of water", "500ml or 750ml"] {
            let values = ScanLabelEvidence.candidates(in: text)
            if text.contains(" or ") { XCTAssertEqual(values.count, 2) } else { XCTAssertTrue(values.isEmpty, text) }
        }
    }
    func testOnlyGroundedUniqueConfidentCapacityIsSuggested() {
        let text = "WATER\n500 ml\nNutrition per 100ml"
        XCTAssertEqual(ScanLabelEvidence.verifiedCapacity(label: "500 ml", evidence: "500 ml", ocr: text, confident: true, labelled: true),500)
        XCTAssertNil(ScanLabelEvidence.verifiedCapacity(label: "500 ml", evidence: "Nutrition per 100ml", ocr: text, confident: true, labelled: true))
        XCTAssertNil(ScanLabelEvidence.verifiedCapacity(label: "750 ml", evidence: "500 ml", ocr: text, confident: true, labelled: true))
        XCTAssertNil(ScanLabelEvidence.verifiedCapacity(label: "500 ml", evidence: "500 ml", ocr: text, confident: false, labelled: true))
        XCTAssertNil(ScanLabelEvidence.verifiedCapacity(label: "500 ml", evidence: "500 ml", ocr: text, confident: true, labelled: false))
        XCTAssertNil(ScanLabelEvidence.verifiedCapacity(label: "500 ml", evidence: "500 ml", ocr: "500 ml\n750 ml", confident: true, labelled: true))
    }
    func testConsumptionRequiresExplicitChoiceAndSafeAmounts() {
        XCTAssertNil(ScanDraft.consumedML(portion: nil, packageML: 500, customML: nil))
        XCTAssertEqual(ScanDraft.consumedML(portion: .all, packageML: 500, customML: nil),500)
        XCTAssertEqual(ScanDraft.consumedML(portion: .half, packageML: 500, customML: nil),250)
        XCTAssertEqual(ScanDraft.consumedML(portion: .custom, packageML: nil, customML: 180),180)
        XCTAssertNil(ScanDraft.consumedML(portion: .all, packageML: nil, customML: 180))
        for n in [Double.nan, .infinity, -.infinity, -100, 0, 9, 5001] {
            XCTAssertNil(ScanDraft.validML(n))
            XCTAssertNil(ScanDraft.consumedML(portion: .custom, packageML: 500, customML: n))
        }
    }
    func testLocaleParsingRejectsGroupingPartialAndAmbiguousInput() {
        XCTAssertEqual(ScanDraft.number("1,5",locale: Locale(identifier:"fr_FR")),1.5)
        XCTAssertEqual(ScanDraft.number("12.5",locale: Locale(identifier:"en_US")),12.5)
        for s in ["1,000","500ml","-50","NaN","inf","1.000","500 600",""] { XCTAssertNil(ScanDraft.number(s,locale:Locale(identifier:"en_US")),s) }
    }
    @MainActor
    func testOnlyExplicitLogWritesExactlyOnceAndUndoKeepsOtherDrinks() {
        let gate = ScanLogGate()
        let existing = HydrationEntry(date:Date(),volumeML:100,source:.manual)
        var entries = [existing]
        let write: (Double,FluidType)->HydrationEntry = { ml,type in
            let e = HydrationEntry(date:Date(),volumeML:ml,source:.manual,fluidType:type); entries.append(e); return e
        }
        XCTAssertNil(gate.log(volumeML:nil,type:.water,write:write))
        XCTAssertEqual(entries.count,1)
        let entry = gate.log(volumeML:250,type:.water,write:write)
        XCTAssertNotNil(entry)
        XCTAssertNil(gate.log(volumeML:250,type:.water,write:write))
        XCTAssertEqual(entries.count,2)
        gate.undo { e in entries.removeAll { $0.id == e.id } }
        XCTAssertEqual(entries,[existing])
        gate.undo { _ in XCTFail("Undo repeated") }
        XCTAssertNil(gate.log(volumeML:250,type:.water,write:write))
    }
    @MainActor
    func testCameraCancellationCompletesOnceWithoutALog() {
        var completions = 0
        let coordinator = ScanCamera.Coordinator { image in
            XCTAssertNil(image); completions += 1
        }
        coordinator.cancelCapture()
        coordinator.cancelCapture()
        XCTAssertEqual(completions, 1)
    }

    func testBrownAccentsAndSelectedGlyphsHaveContrastInBothThemes() {
        func luminance(_ v:[Double])->Double {
            let c=v.map { $0 <= 0.04045 ? $0/12.92 : pow(($0+0.055)/1.055,2.4) }
            return c[0]*0.2126+c[1]*0.7152+c[2]*0.0722
        }
        func ratio(_ a:[Double],_ b:[Double])->Double {
            let x=luminance(a),y=luminance(b);return (max(x,y)+0.05)/(min(x,y)+0.05)
        }
        // Representative white and dark elevated card surfaces; native captures verify the actual UI.
        for isDark in [false,true] {
            let surface = isDark ? [44.0/255,44.0/255,46.0/255] : [1.0,1.0,1.0]
            for fluid in FluidType.allCases where fluid.usesBrownAccent {
                let fg = fluid.brownAccentComponents(isDark:isDark)!
                let chip=zip(fg,surface).map { $0*0.14+$1*0.86 }
                XCTAssertGreaterThanOrEqual(ratio(fg,chip),4.5,"\(fluid) dark=\(isDark)")
                XCTAssertGreaterThanOrEqual(ratio(fluid.selectionComponents(isDark:isDark),fg),4.5)
                if isDark {
                    let disabled=zip(fg,surface).map { $0*0.5+$1*0.5 }
                    XCTAssertGreaterThanOrEqual(ratio(disabled,surface),3)
                }
            }
        }
    }

    @MainActor
    func testActualOCRFixturePreservesPackageSize() async throws {
        let image = UIGraphicsImageRenderer(size:CGSize(width:900,height:600)).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x:0,y:0,width:900,height:600))
            ("SPRING WATER\n500 ml\nNutrition per 100 ml" as NSString).draw(in:CGRect(x:40,y:50,width:820,height:500),withAttributes:[.font:UIFont.systemFont(ofSize:52),.foregroundColor:UIColor.black])
        }
        let text = try await ScanAnalyzer.readText(XCTUnwrap(image.cgImage))
        XCTAssertTrue(text.lowercased().contains("500"),text)
        XCTAssertEqual(ScanLabelEvidence.candidates(in:text).map(\.ml),[500],text)
    }
    @MainActor
    func testActualModelAvailabilityOrExplicitlySkip() async throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Simulator image-model inference is unsupported/missing model assets; verify with a physical Apple Intelligence device")
#else
        guard ScanAnalyzer.isReady else { throw XCTSkip("Apple Intelligence model unavailable on this simulator; physical photo inference remains unverified") }
        // A text-only extraction really executes the on-device model on capable hosts.
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let image = UIGraphicsImageRenderer(size:CGSize(width:600,height:600)).image { _ in
                UIColor.white.setFill(); UIRectFill(CGRect(x:0,y:0,width:600,height:600))
                ("WATER 500 ml" as NSString).draw(at:CGPoint(x:30,y:100),withAttributes:[.font:UIFont.systemFont(ofSize:48),.foregroundColor:UIColor.black])
            }
            let result = try await ScanAnalyzer().analyze(image)
            XCTAssertTrue(result.method.contains("AI interpreted"))
            XCTAssertTrue(result.packageML == nil || result.packageML == 500)
        }
        #endif
#endif
    }
}
