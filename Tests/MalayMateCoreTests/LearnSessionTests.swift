import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class LearnSessionTests: XCTestCase {
    func testPlanUsesRemainingDailyLimitAndDeckOrder() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let firstID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let learnedTodayID = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
        let otherDeckID = UUID(uuidString: "00000000-0000-4000-8000-000000000004")!
        let deck = deckRecord(id: "starter", wordIDs: [secondID, firstID, learnedTodayID])
        let words = [
            wordRecord(id: firstID, term: "saya", status: .new, createdAt: now),
            wordRecord(id: secondID, term: "makan", status: .new, createdAt: now.addingTimeInterval(1)),
            wordRecord(id: learnedTodayID, term: "air", status: .inReview, learnedAt: now.addingTimeInterval(-60), createdAt: now.addingTimeInterval(2)),
            wordRecord(id: otherDeckID, term: "kopi", status: .new, createdAt: now.addingTimeInterval(3))
        ]

        let plan = LearnSession.plan(
            decks: [deck],
            words: words,
            selectedDeckID: "starter",
            dailyLimit: 2,
            now: now
        )

        XCTAssertEqual(plan.learnedTodayCount, 1)
        XCTAssertEqual(plan.remainingNewWordSlots, 1)
        XCTAssertEqual(plan.words.map(\.term), ["makan"])
    }

    func testNewWordsDoNotAppearInReviewUntilLearned() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let word = wordRecord(id: UUID(), term: "makan", status: .new, createdAt: now)
        let card = cardRecord(wordID: word.id, direction: .malayToChinese, now: now)
        context.insert(word)
        context.insert(card)
        context.insert(ReviewStateRecord(cardID: card.id, box: 1, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0))
        try context.save()

        let items = try ReviewSession(context: context).dueCards(now: now)

        XCTAssertTrue(items.isEmpty)
    }

    func testMarkLearnedSchedulesCardsForFirstReview() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let word = wordRecord(id: UUID(), term: "makan", status: .new, createdAt: now)
        let malayCard = cardRecord(wordID: word.id, direction: .malayToChinese, now: now)
        let chineseCard = cardRecord(wordID: word.id, direction: .chineseToMalay, now: now)
        context.insert(word)
        for card in [malayCard, chineseCard] {
            context.insert(card)
            context.insert(ReviewStateRecord(cardID: card.id, box: 3, dueAt: .distantFuture, lapses: 2, lastReviewedAt: now.addingTimeInterval(-60), easeHint: 1.5))
        }
        try context.save()

        try LearnSession(context: context).markLearned(wordID: word.id, now: now)

        XCTAssertEqual(LearningStatus(word: word), .inReview)
        XCTAssertEqual(word.learnedAt, now)
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
        XCTAssertEqual(Set(states.map(\.dueAt)), [now.addingTimeInterval(10 * 60)])
        XCTAssertEqual(Set(states.map(\.box)), [1])
        XCTAssertEqual(Set(states.map(\.lapses)), [0])
        XCTAssertTrue(states.allSatisfy { $0.lastReviewedAt == nil })
        XCTAssertEqual(try ReviewSession(context: context).dueCards(now: now).count, 0)
        XCTAssertEqual(try ReviewSession(context: context).dueCards(now: now.addingTimeInterval(10 * 60)).count, 2)
    }

    private func deckRecord(id: String, wordIDs: [UUID]) -> DeckRecord {
        DeckRecord(
            id: id,
            name: "Starter",
            deckDescription: "Starter words",
            isStarter: true,
            wordIDsJSON: String(decoding: try! JSONEncoder().encode(wordIDs.map(\.uuidString)), as: UTF8.self),
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }

    private func wordRecord(id: UUID, term: String, status: LearningStatus, learnedAt: Date? = nil, createdAt: Date) -> WordRecord {
        WordRecord(
            id: id,
            term: term,
            languageCode: "ms",
            chineseMeaning: "meaning-\(term)",
            partOfSpeech: "verb",
            pronunciationNotes: "",
            syllablesJSON: "[]",
            examplesJSON: "[]",
            sourceRefsJSON: "[]",
            reviewStatus: "reviewed",
            createdAt: createdAt,
            updatedAt: createdAt,
            learningStatusRaw: status.rawValue,
            learnedAt: learnedAt
        )
    }

    private func cardRecord(wordID: UUID, direction: CardDirection, now: Date) -> CardRecord {
        CardRecord(
            id: UUID(),
            wordID: wordID,
            directionRaw: direction.rawValue,
            prompt: direction == .malayToChinese ? "makan" : "吃",
            answer: direction == .malayToChinese ? "吃" : "makan",
            hint: "verb",
            createdAt: now
        )
    }
}
