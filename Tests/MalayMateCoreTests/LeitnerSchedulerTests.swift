import XCTest
@testable import MalayMateCore

final class LeitnerSchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testInitialStateStartsInBoxOneDueNow() {
        let scheduler = LeitnerScheduler()

        let snapshot = scheduler.initialState(now: now)

        XCTAssertEqual(snapshot.box, 1)
        XCTAssertEqual(snapshot.dueAt, now)
        XCTAssertEqual(snapshot.lapses, 0)
        XCTAssertNil(snapshot.lastReviewedAt)
        XCTAssertEqual(snapshot.easeHint, 1.0)
    }

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

    func testGoodAtMaximumBoxStaysCapped() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 6, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0)

        let update = scheduler.update(from: snapshot, rating: .good, now: now)

        XCTAssertEqual(update.nextBox, 6)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(30 * 24 * 60 * 60))
    }

    func testEasyMovesUpTwoBoxesFromNonCapBox() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 2, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0)

        let update = scheduler.update(from: snapshot, rating: .easy, now: now)

        XCTAssertEqual(update.nextBox, 4)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(7 * 24 * 60 * 60))
    }

    func testEasyMovesUpTwoBoxesAndCapsAtSix() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 5, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0)

        let update = scheduler.update(from: snapshot, rating: .easy, now: now)

        XCTAssertEqual(update.nextBox, 6)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(30 * 24 * 60 * 60))
    }

    func testUpdatePreservesReviewMetadata() {
        let scheduler = LeitnerScheduler()
        let dueAt = now.addingTimeInterval(-24 * 60 * 60)
        let snapshot = ReviewSnapshot(box: 3, dueAt: dueAt, lapses: 1, lastReviewedAt: dueAt, easeHint: 1.25)

        let update = scheduler.update(from: snapshot, rating: .easy, now: now)

        XCTAssertEqual(update.rating, .easy)
        XCTAssertEqual(update.reviewedAt, now)
        XCTAssertEqual(update.previousBox, 3)
        XCTAssertEqual(update.previousDueAt, dueAt)
        XCTAssertEqual(update.easeHint, 1.25)
    }
}
