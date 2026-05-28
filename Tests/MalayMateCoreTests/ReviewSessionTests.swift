import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class ReviewSessionTests: XCTestCase {
    func testDueCardsReturnSeededReviewItems() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        try SeedImporter().importBundledSeed(into: context, now: Date(timeIntervalSince1970: 1_800_000_000))

        let items = try ReviewSession(context: context).dueCards(now: Date(timeIntervalSince1970: 1_800_000_100))

        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.contains { $0.word.term == "makan" })
        XCTAssertTrue(items.allSatisfy { $0.state.dueAt <= Date(timeIntervalSince1970: 1_800_000_100) })
    }

    func testApplyingRatingUpdatesStateAndCreatesLog() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        try SeedImporter().importBundledSeed(into: context, now: Date(timeIntervalSince1970: 1_800_000_000))
        let session = ReviewSession(context: context)
        let item = try XCTUnwrap(session.dueCards(now: Date(timeIntervalSince1970: 1_800_000_100)).first)

        try session.apply(rating: .good, to: item.card.id, now: Date(timeIntervalSince1970: 1_800_000_100))

        let state = try XCTUnwrap(try context.fetch(FetchDescriptor<ReviewStateRecord>()).first { $0.cardID == item.card.id })
        XCTAssertEqual(state.box, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewLogRecord>()).count, 1)
    }
}
