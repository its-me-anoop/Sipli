import XCTest
@testable import Sipli

/// Tests for the Match Day pure model: season window, match phases, and the
/// deterministic commentary/scoreboard copy.
///
/// Also guards the trademark constraint: no user-facing Match Day string may
/// contain protected tournament marks.
final class MatchDayTests: XCTestCase {

    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - Season window

    func test_isActive_insideWindow() {
        XCTAssertTrue(MatchDay.isActive(on: date(2026, 7, 3)))
        XCTAssertTrue(MatchDay.isActive(on: date(2026, 7, 19)))
        XCTAssertTrue(MatchDay.isActive(on: date(2026, 8, 2, hour: 23)))
    }

    func test_isActive_outsideWindow() {
        XCTAssertFalse(MatchDay.isActive(on: date(2026, 7, 2, hour: 23)))
        XCTAssertFalse(MatchDay.isActive(on: date(2026, 8, 3, hour: 0)))
        XCTAssertFalse(MatchDay.isActive(on: date(2027, 7, 10)))
    }

    // MARK: - Phases

    func test_phase_goalMet_isFullTime_regardlessOfHour() {
        XCTAssertEqual(MatchDay.phase(progress: 1.0, now: date(2026, 7, 10, hour: 9)), .fullTime)
        XCTAssertEqual(MatchDay.phase(progress: 1.2, now: date(2026, 7, 10, hour: 22)), .fullTime)
    }

    func test_phase_byHour() {
        XCTAssertEqual(MatchDay.phase(progress: 0.3, now: date(2026, 7, 10, hour: 9)), .firstHalf)
        XCTAssertEqual(MatchDay.phase(progress: 0.5, now: date(2026, 7, 10, hour: 15)), .secondHalf)
        XCTAssertEqual(MatchDay.phase(progress: 0.7, now: date(2026, 7, 10, hour: 21)), .extraTime)
    }

    // MARK: - Copy

    func test_commentary_isDeterministic_andPhaseAppropriate() {
        XCTAssertTrue(MatchDay.commentary(phase: .firstHalf, progress: 0, score: 0).contains("Kickoff"))
        XCTAssertTrue(MatchDay.commentary(phase: .extraTime, progress: 0.8, score: 5).contains("Extra time"))
        XCTAssertTrue(MatchDay.commentary(phase: .fullTime, progress: 1.0, score: 8).contains("Full time"))
    }

    func test_scoreline_pluralization() {
        XCTAssertEqual(MatchDay.scoreline(score: 1, progress: 0.25), "1 goal · 25%")
        XCTAssertEqual(MatchDay.scoreline(score: 3, progress: 0.5), "3 goals · 50%")
    }

    func test_winsSummary_goldenBottleAtThreshold() {
        XCTAssertTrue(MatchDay.winsSummary(wins: 11).contains("Golden Bottle at 12"))
        XCTAssertTrue(MatchDay.winsSummary(wins: 12).contains("Golden Bottle earned"))
    }

    // MARK: - Trademark safety

    /// Every user-visible Match Day string must stay clear of protected
    /// tournament marks (App Review guideline 5.2.1).
    func test_copy_containsNoProtectedMarks() {
        var corpus: [String] = []
        for phase: MatchDay.Phase in [.firstHalf, .secondHalf, .extraTime, .fullTime] {
            for (progress, score) in [(0.0, 0), (0.4, 3), (0.9, 7), (1.0, 9)] {
                corpus.append(MatchDay.commentary(phase: phase, progress: progress, score: score))
            }
        }
        corpus.append(MatchDay.winsSummary(wins: 0))
        corpus.append(MatchDay.winsSummary(wins: 12))
        corpus.append(MatchDay.scoreline(score: 2, progress: 0.4))

        let banned = ["fifa", "world cup", "we are 26", "copa mundial", "wc26"]
        for text in corpus {
            let lowered = text.lowercased()
            for mark in banned {
                XCTAssertFalse(lowered.contains(mark), "protected mark \"\(mark)\" found in: \(text)")
            }
        }
    }
}
