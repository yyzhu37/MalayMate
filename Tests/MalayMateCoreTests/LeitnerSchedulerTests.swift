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
        XCTAssertEqual(snapshot.easeHint, 2.5)
    }

    func testAgainResetsToBoxOneAddsLapseAndReducesEase() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 4, dueAt: now, lapses: 2, lastReviewedAt: nil, easeHint: 2.5)

        let update = scheduler.update(from: snapshot, rating: .again, now: now)

        XCTAssertEqual(update.nextBox, 1)
        XCTAssertEqual(update.lapses, 3)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(10 * 60))
        XCTAssertEqual(update.easeHint, 2.3, accuracy: 0.0001)
    }

    func testGoodMovesUpOneStageWithSM2BaseInterval() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 2, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 2.5)

        let update = scheduler.update(from: snapshot, rating: .good, now: now)

        XCTAssertEqual(update.nextBox, 3)
        XCTAssertEqual(update.lapses, 0)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(6 * 24 * 60 * 60))
        XCTAssertEqual(update.easeHint, 2.5)
    }

    func testGoodAtMaximumStageStaysCappedAndLimitsInterval() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 10, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 2.5)

        let update = scheduler.update(from: snapshot, rating: .good, now: now)

        XCTAssertEqual(update.nextBox, 10)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(365 * 24 * 60 * 60))
    }

    func testEasyMovesUpTwoStagesAndIncreasesEase() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 2, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 2.5)

        let update = scheduler.update(from: snapshot, rating: .easy, now: now)

        XCTAssertEqual(update.nextBox, 4)
        XCTAssertEqual(update.easeHint, 2.65, accuracy: 0.0001)
        XCTAssertEqual(update.nextDueAt.timeIntervalSince(now), 20.67 * 24 * 60 * 60, accuracy: 0.001)
    }

    func testEasyMovesUpTwoStagesAndCapsAtTen() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 9, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 2.5)

        let update = scheduler.update(from: snapshot, rating: .easy, now: now)

        XCTAssertEqual(update.nextBox, 10)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(365 * 24 * 60 * 60))
    }

    func testUpdatePreservesReviewMetadata() {
        let scheduler = LeitnerScheduler()
        let dueAt = now.addingTimeInterval(-24 * 60 * 60)
        let snapshot = ReviewSnapshot(box: 3, dueAt: dueAt, lapses: 1, lastReviewedAt: dueAt, easeHint: 2.5)

        let update = scheduler.update(from: snapshot, rating: .easy, now: now)

        XCTAssertEqual(update.rating, .easy)
        XCTAssertEqual(update.reviewedAt, now)
        XCTAssertEqual(update.previousBox, 3)
        XCTAssertEqual(update.previousDueAt, dueAt)
        XCTAssertEqual(update.easeHint, 2.65, accuracy: 0.0001)
    }
}
