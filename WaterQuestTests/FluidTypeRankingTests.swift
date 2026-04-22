import XCTest
@testable import Sipli

final class FluidTypeRankingTests: XCTestCase {

    private func makeEntry(_ type: FluidType) -> HydrationEntry {
        HydrationEntry(date: Date(), volumeML: 250, source: .manual, fluidType: type)
    }

    func test_ranked_emptyEntries_fallsBackToEnumOrder() {
        let ranked = FluidType.ranked(from: [])
        XCTAssertEqual(ranked, FluidType.allCases)
        XCTAssertEqual(ranked.first, .water)
    }

    func test_ranked_mostUsedTypeAppearsFirst() {
        let entries =
            Array(repeating: makeEntry(.coffee), count: 10) +
            Array(repeating: makeEntry(.greenTea), count: 5) +
            Array(repeating: makeEntry(.water), count: 3)

        let ranked = FluidType.ranked(from: entries)

        XCTAssertEqual(ranked[0], .coffee)
        XCTAssertEqual(ranked[1], .greenTea)
        XCTAssertEqual(ranked[2], .water)
    }

    func test_ranked_neverUsedTypesFollowInEnumOrder() {
        let entries = Array(repeating: makeEntry(.coffee), count: 5)

        let ranked = FluidType.ranked(from: entries)

        XCTAssertEqual(ranked[0], .coffee)
        let tail = Array(ranked.dropFirst())
        let expectedTail = FluidType.allCases.filter { $0 != .coffee }
        XCTAssertEqual(tail, expectedTail)
    }

    func test_ranked_tiesBreakByEnumDeclarationOrder() {
        let entries =
            Array(repeating: makeEntry(.milk), count: 3) +
            Array(repeating: makeEntry(.juice), count: 3)

        let ranked = FluidType.ranked(from: entries)

        // `.milk` is declared before `.juice` in `FluidType` — should win the tie.
        let milkIdx = ranked.firstIndex(of: .milk)!
        let juiceIdx = ranked.firstIndex(of: .juice)!
        XCTAssertLessThan(milkIdx, juiceIdx)
    }

    func test_ranked_alwaysContainsAllCases() {
        let entries = Array(repeating: makeEntry(.coffee), count: 7)
        let ranked = FluidType.ranked(from: entries)
        XCTAssertEqual(Set(ranked), Set(FluidType.allCases))
        XCTAssertEqual(ranked.count, FluidType.allCases.count)
    }
}
