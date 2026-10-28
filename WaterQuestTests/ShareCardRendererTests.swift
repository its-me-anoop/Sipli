import XCTest
import SwiftUI
import Vision
import UniformTypeIdentifiers
@testable import Sipli

@MainActor
final class ShareCardRendererTests: XCTestCase {
    private var earned: Date { Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12))! }
    private func export(_ achievement: Achievement, scheme: ColorScheme = .light, locale: Locale = Locale(identifier: "en_US")) throws -> ShareCardPayload {
        try XCTUnwrap(ShareCardRenderer.render(.achievement(achievement, earnedOn: earned), colorScheme: scheme, locale: locale))
    }
    private func capture(_ payload: ShareCardPayload, _ name: String) {
        let attachment = XCTAttachment(data: payload.pngData, uniformTypeIdentifier: UTType.png.identifier)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func recognized(_ payload: ShareCardPayload) throws -> [(String, CGRect)] {
        let image = try XCTUnwrap(UIImage(data: payload.pngData)?.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map { ($0.string.lowercased(), observation.boundingBox) }
        }
    }
    private func assertSafe(_ words: [String], in payload: ShareCardPayload, file: StaticString = #filePath, line: UInt = #line) throws {
        let text = try recognized(payload)
        let image = try XCTUnwrap(UIImage(data: payload.pngData)?.cgImage)
        let xMargin = 54.0 / Double(image.width), yMargin = 54.0 / Double(image.height)
        for word in words {
            let item = try XCTUnwrap(text.first { $0.0.contains(word) }, "Missing/cropped text '\(word)': \(text.map(\.0))", file: file, line: line)
            XCTAssertGreaterThan(item.1.minX, xMargin, file: file, line: line)
            XCTAssertLessThan(item.1.maxX, 1 - xMargin, file: file, line: line)
            XCTAssertGreaterThan(item.1.minY, yMargin, file: file, line: line)
            XCTAssertLessThan(item.1.maxY, 1 - yMargin, file: file, line: line)
        }
    }
    func testCatalogKeepsExactExportSizeInBothAppearances() throws {
        for badge in AchievementCatalog.all {
            for scheme in [ColorScheme.light, .dark] {
                try autoreleasepool {
                    let payload = try export(badge, scheme: scheme)
                    let image = try XCTUnwrap(UIImage(data: payload.pngData)?.cgImage)
                    XCTAssertEqual(image.width, 1080, badge.id)
                    XCTAssertEqual(image.height, 1350, badge.id)
                }
            }
        }
    }
    func testFirstBrewSafeMarginsAndSeasonalPreviews() throws {
        let first = try XCTUnwrap(AchievementCatalog.byID["spooky.first"])
        for (scheme, label) in [(ColorScheme.light, "Light"), (.dark, "Dark")] {
            let payload = try export(first, scheme: scheme)
            capture(payload, "First-Brew-\(label)")
            try assertSafe(["achievement", "october", "first brew", "spooky season", "sipli"], in: payload)
        }
        for id in ["spooky.cauldron", "spooky.halloween", "streak.100", "explorer.15", "matchday.golden"] {
            let badge = try XCTUnwrap(AchievementCatalog.byID[id])
            capture(try export(badge), badge.title.replacingOccurrences(of: " ", with: "-"))
        }
    }
    func testLongLocalizedCopyAndDateRemainComplete() throws {
        let badge = Achievement(id: "fixture.localized", title: "Ein außergewöhnlicher Meilenstein für viele kleine Schritte jeden Tag", detail: "Ein persönlicher Erfolg, der Geduld und Beständigkeit über viele Wochen widerspiegelt. Ein guter Moment, um die kleinen Fortschritte zu feiern.", symbol: "rosette", category: .dedication)
        let payload = try export(badge, locale: Locale(identifier: "de_DE"))
        capture(payload, "Long-Localized-Achievement")
        let image = try XCTUnwrap(UIImage(data: payload.pngData)?.cgImage)
        XCTAssertEqual(image.width, 1080)
        XCTAssertGreaterThanOrEqual(image.height, 1350)
        try assertSafe(["meilenstein", "fortschritte", "sipli"], in: payload)
        let first = try XCTUnwrap(AchievementCatalog.byID["spooky.first"])
        capture(try export(first, locale: Locale(identifier: "ar_SA")), "First-Brew-Arabic-Date")
    }
    func testDailyAndWeeklyUseTheSameSafeCanvas() throws {
        let cards: [(ShareCardContent, String, String)] = [
            (.daily(totalML: 1850, goalML: 2200, streak: 6, unitSystem: .metric, date: earned), "Daily-Progress", "hydration"),
            (.weekly(dayFractions: [1, 0.8, 1, 0.4, 1, 1, 0.9], goalDays: 4, totalML: 13400, unitSystem: .metric, weekEnding: earned), "Weekly-Progress", "this week")]
        for (content, name, header) in cards {
            let payload = try XCTUnwrap(ShareCardRenderer.render(content))
            let image = try XCTUnwrap(UIImage(data: payload.pngData)?.cgImage)
            XCTAssertEqual(image.width, 1080); XCTAssertEqual(image.height, 1350)
            capture(payload, name)
            try assertSafe([header, "sipli"], in: payload)
        }
    }
    func testStaticExportDoesNotInheritAccessibilityTextScaling() throws {
        let first = try XCTUnwrap(AchievementCatalog.byID["spooky.first"])
        let content = ShareCardContent.achievement(first, earnedOn: earned)
        let normal = try export(first)
        let renderer = ImageRenderer(content: ShareCardView(content: content)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, .accessibility5))
        renderer.scale = 3; renderer.proposedSize = ProposedViewSize(width: 360, height: 450)
        let large = try XCTUnwrap(renderer.uiImage?.pngData())
        XCTAssertTrue(normal.pngData == large, "Static poster should be independent of sender's text-size setting")
    }
    func testVeryLongContentGetsTallerCanvasWithoutTruncation() throws {
        let badge = Achievement(id: "fixture.long", title: String(repeating: "A remarkable milestone worth remembering ", count: 4) + "together", detail: String(repeating: "Every small check-in is a moment to remember and appreciate. ", count: 6) + "Celebrate the small steps.", symbol: "rosette", category: .dedication)
        let payload = try export(badge)
        let image = try XCTUnwrap(UIImage(data: payload.pngData)?.cgImage)
        XCTAssertGreaterThan(image.height, 1350)
        XCTAssertEqual(image.width, 1080)
        try assertSafe(["remarkable", "together", "celebrate", "sipli"], in: payload)
        capture(payload, "Extra-Long-Achievement")
    }

}
