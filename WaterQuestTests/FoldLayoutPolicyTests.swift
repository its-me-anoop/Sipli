import CoreGraphics
import Testing
@testable import Sipli

/// Covers how two-pane containers react to the fold (book / tabletop pose),
/// wide landscape, and plain portrait on iPhone Duo and regular iPhones.
struct FoldLayoutPolicyTests {
    private let policy = FoldLayoutPolicy()
    private let splitAnywhere = PaneSplitOptions(allowsLandscapeSplit: true)

    private func bookFold(x: CGFloat, height: CGFloat, width: CGFloat = 24) -> FoldDivision {
        FoldDivision(frame: CGRect(x: x, y: 0, width: width, height: height))
    }

    private func tabletopFold(y: CGFloat, width: CGFloat, height: CGFloat = 24) -> FoldDivision {
        FoldDivision(frame: CGRect(x: 0, y: y, width: width, height: height))
    }

    // MARK: Book pose

    @Test func bookFoldSplitsPanesSideBySideAroundTheFold() {
        let size = CGSize(width: 800, height: 600)
        let result = policy.arrangement(for: size, division: bookFold(x: 388, height: 600), options: splitAnywhere)
        #expect(result == .sideBySide(leading: 388, gap: 24, trailing: 388))
    }

    @Test func bookFoldSplitsEvenWhenLandscapeSplitIsDisabled() {
        let size = CGSize(width: 800, height: 600)
        let options = PaneSplitOptions(allowsLandscapeSplit: false)
        let result = policy.arrangement(for: size, division: bookFold(x: 388, height: 600), options: options)
        #expect(result == .sideBySide(leading: 388, gap: 24, trailing: 388))
    }

    @Test func bookFoldAcceptsPanesExactlyAtTheMinimumLength() {
        let size = CGSize(width: 464, height: 700)
        let result = policy.arrangement(for: size, division: bookFold(x: 220, height: 700), options: splitAnywhere)
        #expect(result == .sideBySide(leading: 220, gap: 24, trailing: 220))
    }

    @Test func bookFoldWithANarrowPaneFallsBackToLandscapeSplit() {
        let size = CGSize(width: 800, height: 400)
        let result = policy.arrangement(for: size, division: bookFold(x: 100, height: 400), options: splitAnywhere)
        #expect(result == .sideBySide(leading: 368, gap: 16, trailing: 416))
    }

    @Test func bookFoldWithANarrowPaneInPortraitStaysSingle() {
        let size = CGSize(width: 500, height: 800)
        let result = policy.arrangement(for: size, division: bookFold(x: 100, height: 800), options: splitAnywhere)
        #expect(result == .single)
    }

    // MARK: Tabletop pose

    @Test func tabletopFoldStacksPanesAboveAndBelowTheFold() {
        let size = CGSize(width: 700, height: 800)
        let result = policy.arrangement(for: size, division: tabletopFold(y: 388, width: 700), options: splitAnywhere)
        #expect(result == .stacked(top: 388, gap: 24, bottom: 388))
    }

    @Test func tabletopAllowsShorterPanesThanBookPose() {
        // 160pt is under the 220pt book minimum but over the 154pt tabletop one.
        let size = CGSize(width: 700, height: 344)
        let result = policy.arrangement(for: size, division: tabletopFold(y: 160, width: 700), options: splitAnywhere)
        #expect(result == .stacked(top: 160, gap: 24, bottom: 160))
    }

    @Test func tabletopWithAShortPaneFallsBackToLandscapeSplit() {
        let size = CGSize(width: 1000, height: 600)
        let result = policy.arrangement(for: size, division: tabletopFold(y: 100, width: 1000), options: splitAnywhere)
        #expect(result == .sideBySide(leading: 460, gap: 16, trailing: 524))
    }

    @Test func tabletopOptOutStaysSingleEvenInWideLandscape() {
        let size = CGSize(width: 1000, height: 700)
        let options = PaneSplitOptions(allowsLandscapeSplit: true, allowsStackedSplit: false)
        let result = policy.arrangement(for: size, division: tabletopFold(y: 338, width: 1000), options: options)
        #expect(result == .single)
    }

    // MARK: No fold

    @Test func portraitWithoutAFoldStaysSingle() {
        let size = CGSize(width: 390, height: 844)
        #expect(policy.arrangement(for: size, division: nil, options: splitAnywhere) == .single)
    }

    @Test func wideLandscapeSplitsWithTheDefaultLeadingFraction() {
        let size = CGSize(width: 844, height: 390)
        let result = policy.arrangement(for: size, division: nil, options: splitAnywhere)
        #expect(result == .sideBySide(leading: 388, gap: 16, trailing: 440))
    }

    @Test func wideLandscapeHonoursACustomLeadingFraction() {
        let size = CGSize(width: 844, height: 390)
        let options = PaneSplitOptions(allowsLandscapeSplit: true, landscapeLeadingFraction: 0.4)
        let result = policy.arrangement(for: size, division: nil, options: options)
        #expect(result == .sideBySide(leading: 338, gap: 16, trailing: 490))
    }

    @Test func landscapeSplitCanBeDisabled() {
        let size = CGSize(width: 844, height: 390)
        let options = PaneSplitOptions(allowsLandscapeSplit: false)
        #expect(policy.arrangement(for: size, division: nil, options: options) == .single)
    }

    @Test func landscapeTooNarrowForTwoPanesStaysSingle() {
        let size = CGSize(width: 440, height: 300)
        #expect(policy.arrangement(for: size, division: nil, options: splitAnywhere) == .single)
    }

    @Test func nearlySquareSizeIsNotTreatedAsLandscape() {
        let size = CGSize(width: 800, height: 700)
        #expect(policy.arrangement(for: size, division: nil, options: splitAnywhere) == .single)
    }

    @Test func customMinimumPaneLengthChangesTheBookThreshold() {
        let strict = FoldLayoutPolicy(minimumPaneLength: 400)
        let size = CGSize(width: 800, height: 600)
        let options = PaneSplitOptions(allowsLandscapeSplit: false)
        #expect(strict.arrangement(for: size, division: bookFold(x: 388, height: 600), options: options) == .single)
    }

    // MARK: Arrangement helpers

    @Test func onlySingleIsNotASplit() {
        #expect(!PaneArrangement.single.isSplit)
        #expect(PaneArrangement.sideBySide(leading: 1, gap: 0, trailing: 1).isSplit)
        #expect(PaneArrangement.stacked(top: 1, gap: 0, bottom: 1).isSplit)
    }
}

/// Covers turning a raw fold frame into the division a view lays out around.
struct FoldDivisionResolutionTests {
    @Test func axisIsInferredFromTheBandShape() {
        #expect(FoldDivision(frame: CGRect(x: 0, y: 0, width: 24, height: 600)).axis == .vertical)
        #expect(FoldDivision(frame: CGRect(x: 0, y: 0, width: 600, height: 24)).axis == .horizontal)
        #expect(FoldDivision(frame: CGRect(x: 0, y: 0, width: 24, height: 24)).axis == .vertical)
    }

    @Test func missingFoldResolvesToNil() {
        #expect(FoldResolver.division(clipping: nil, to: CGSize(width: 400, height: 800)) == nil)
    }

    @Test func foldOutsideTheViewResolvesToNil() {
        let fold = CGRect(x: 500, y: 0, width: 24, height: 800)
        #expect(FoldResolver.division(clipping: fold, to: CGSize(width: 400, height: 800)) == nil)
    }

    @Test func foldIsClippedToTheViewBounds() {
        let fold = CGRect(x: 388, y: -100, width: 24, height: 1000)
        let division = FoldResolver.division(clipping: fold, to: CGSize(width: 800, height: 600))
        #expect(division == FoldDivision(frame: CGRect(x: 388, y: 0, width: 24, height: 600), axis: .vertical))
    }

    @Test func clippingKeepsTheAxisOfTheUnclippedFold() {
        // A short view only sees an 8pt-tall sliver of a book fold, which on
        // its own would look horizontal.
        let fold = CGRect(x: 100, y: 0, width: 24, height: 800)
        let division = FoldResolver.division(clipping: fold, to: CGSize(width: 300, height: 8))
        #expect(division?.frame == CGRect(x: 100, y: 0, width: 24, height: 8))
        #expect(division?.axis == .vertical)
    }

    @Test func globalFoldIsConvertedIntoTheViewsSpace() {
        let global = CGRect(x: 400, y: 0, width: 24, height: 900)
        let local = FoldResolver.localFrame(ofGlobal: global, viewOrigin: CGPoint(x: 16, y: 60))
        #expect(local == CGRect(x: 384, y: -60, width: 24, height: 900))
    }

    @Test func resolverKeepsItsPublicMinimumInSyncWithThePolicy() {
        #expect(FoldResolver.minimumPaneLength == FoldLayoutPolicy().minimumPaneLength)
    }
}
