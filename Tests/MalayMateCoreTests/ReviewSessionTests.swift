import Foundation
import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class ReviewSessionTests: XCTestCase {
    func testDueCardsExcludeUnlearnedSeedWords() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        _ = try SeedImporter().importBundledSeed(into: context, now: Date(timeIntervalSince1970: 1_800_000_000))

        let items = try ReviewSession(context: context).dueCards(now: Date(timeIntervalSince1970: 1_800_000_100))

        XCTAssertTrue(items.isEmpty)
    }

    func testDueCardsAreOrderedByDueAtThenCardID() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let earlyCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000300")!
        let tieLowCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
        let tieHighCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000200")!
        let futureCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000400")!
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        insertReviewRecord(context: context, wordTerm: "early", cardID: earlyCardID, dueAt: now.addingTimeInterval(-120))
        insertReviewRecord(context: context, wordTerm: "tie low", cardID: tieLowCardID, dueAt: now.addingTimeInterval(-60))
        insertReviewRecord(context: context, wordTerm: "tie high", cardID: tieHighCardID, dueAt: now.addingTimeInterval(-60))
        insertReviewRecord(context: context, wordTerm: "future", cardID: futureCardID, dueAt: now.addingTimeInterval(60))
        try context.save()

        let items = try ReviewSession(context: context).dueCards(now: now)

        XCTAssertEqual(items.map(\.card.id), [earlyCardID, tieLowCardID, tieHighCardID])
    }

    func testDueCardsRespectsLimit() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let firstCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        insertReviewRecord(context: context, wordTerm: "first", cardID: firstCardID, dueAt: now.addingTimeInterval(-120))
        insertReviewRecord(context: context, wordTerm: "second", cardID: secondCardID, dueAt: now.addingTimeInterval(-60))
        try context.save()

        let items = try ReviewSession(context: context).dueCards(now: now, limit: 1)

        XCTAssertEqual(items.map(\.card.id), [firstCardID])
    }

    func testDueCardsReturnsEmptyForNonPositiveLimit() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        insertReviewRecord(
            context: context,
            wordTerm: "limited",
            cardID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            dueAt: now
        )
        try context.save()

        XCTAssertEqual(try ReviewSession(context: context).dueCards(now: now, limit: 0).count, 0)
        XCTAssertEqual(try ReviewSession(context: context).dueCards(now: now, limit: -1).count, 0)
    }

    func testDueCardsCompactsStatesWithMissingCardsOrWords() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let validCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let missingCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let missingWordCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

        insertReviewRecord(context: context, wordTerm: "valid", cardID: validCardID, dueAt: now)
        context.insert(ReviewStateRecord(cardID: missingCardID, box: 1, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0))
        context.insert(CardRecord(
            id: missingWordCardID,
            wordID: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            directionRaw: CardDirection.malayToChinese.rawValue,
            prompt: "orphan",
            answer: "orphan",
            hint: "",
            createdAt: now
        ))
        context.insert(ReviewStateRecord(cardID: missingWordCardID, box: 1, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0))
        try context.save()

        let items = try ReviewSession(context: context).dueCards(now: now)

        XCTAssertEqual(items.map(\.card.id), [validCardID])
    }

    func testApplyingRatingUpdatesStateAndCreatesLog() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_100)
        let previousDueAt = Date(timeIntervalSince1970: 1_800_000_000)
        let lastReviewedAt = Date(timeIntervalSince1970: 1_799_999_000)
        let cardID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let word = makeWord(term: "makan", createdAt: previousDueAt)
        let card = makeCard(id: cardID, wordID: word.id, createdAt: previousDueAt)
        let state = ReviewStateRecord(
            cardID: cardID,
            box: 1,
            dueAt: previousDueAt,
            lapses: 2,
            lastReviewedAt: lastReviewedAt,
            easeHint: 1.25
        )
        context.insert(word)
        context.insert(card)
        context.insert(state)
        try context.save()

        try ReviewSession(context: context).apply(rating: .good, to: cardID, now: now)

        let updatedState = try XCTUnwrap(try context.fetch(FetchDescriptor<ReviewStateRecord>()).first { $0.cardID == cardID })
        XCTAssertEqual(updatedState.box, 2)
        XCTAssertEqual(updatedState.dueAt, now.addingTimeInterval(24 * 60 * 60))
        XCTAssertEqual(updatedState.lapses, 2)
        XCTAssertEqual(updatedState.lastReviewedAt, now)
        XCTAssertEqual(updatedState.easeHint, 1.3)

        let log = try XCTUnwrap(try context.fetch(FetchDescriptor<ReviewLogRecord>()).first)
        XCTAssertEqual(log.cardID, cardID)
        XCTAssertEqual(log.ratingRaw, ReviewRating.good.rawValue)
        XCTAssertEqual(log.reviewedAt, now)
        XCTAssertEqual(log.previousBox, 1)
        XCTAssertEqual(log.nextBox, 2)
        XCTAssertEqual(log.previousDueAt, previousDueAt)
        XCTAssertEqual(log.nextDueAt, now.addingTimeInterval(24 * 60 * 60))
    }

    private func insertReviewRecord(context: ModelContext, wordTerm: String, cardID: UUID, dueAt: Date) {
        let word = makeWord(term: wordTerm, createdAt: dueAt)
        context.insert(word)
        context.insert(makeCard(id: cardID, wordID: word.id, createdAt: dueAt))
        context.insert(ReviewStateRecord(cardID: cardID, box: 1, dueAt: dueAt, lapses: 0, lastReviewedAt: nil, easeHint: 1.0))
    }

    private func makeWord(term: String, createdAt: Date) -> WordRecord {
        WordRecord(
            id: UUID(),
            term: term,
            languageCode: "ms",
            chineseMeaning: term,
            partOfSpeech: "verb",
            pronunciationNotes: "",
            syllablesJSON: "[]",
            examplesJSON: "[]",
            sourceRefsJSON: "[]",
            reviewStatus: "seeded",
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private func makeCard(id: UUID, wordID: UUID, createdAt: Date) -> CardRecord {
        CardRecord(
            id: id,
            wordID: wordID,
            directionRaw: CardDirection.malayToChinese.rawValue,
            prompt: "prompt",
            answer: "answer",
            hint: "",
            createdAt: createdAt
        )
    }
}
