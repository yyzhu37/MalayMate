import XCTest
@testable import MalayMateCore

final class LeitnerSchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testAgainResetsToBoxOneAndAddsLapse() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 4, dueAt: now, lapses: 2, lastReviewedAt: nil, easeHint: 1.0)

        let update = scheduler.update(from: snapshot, rating: .again, now: now)

        XCTAssertEqual(update.nextBox, 1)
        XCTAssertEqual(update.lapses, 3)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(10 * 60))
    }

    func testGoodMovesUpOneBox() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 2, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0)

        let update = scheduler.update(from: snapshot, rating: .good, now: now)

        XCTAssertEqual(update.nextBox, 3)
        XCTAssertEqual(update.lapses, 0)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(3 * 24 * 60 * 60))
    }

    func testEasyMovesUpTwoBoxesAndCapsAtSix() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 5, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0)

        let update = scheduler.update(from: snapshot, rating: .easy, now: now)

        XCTAssertEqual(update.nextBox, 6)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(30 * 24 * 60 * 60))
    }
}
