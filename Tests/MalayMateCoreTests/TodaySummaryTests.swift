import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class TodaySummaryTests: XCTestCase {
    func testSummaryCountsDueReviewsNewWordSlotsAndNextReview() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let learnedToday = wordRecord(term: "makan", status: .inReview, learnedAt: now.addingTimeInterval(-60), now: now)
        let unlearned = wordRecord(term: "minum", status: .new, learnedAt: nil, now: now)
        let laterReview = wordRecord(term: "tidur", status: .inReview, learnedAt: now.addingTimeInterval(-86_400), now: now)
        let dueCard = cardRecord(wordID: learnedToday.id, direction: .malayToChinese, now: now)
        let unlearnedDueCard = cardRecord(wordID: unlearned.id, direction: .malayToChinese, now: now)
        let laterCard = cardRecord(wordID: laterReview.id, direction: .malayToChinese, now: now)
        let nextDueAt = now.addingTimeInterval(600)

        let summary = TodaySummary.make(
            words: [learnedToday, unlearned, laterReview],
            cards: [dueCard, unlearnedDueCard, laterCard],
            reviewStates: [
                ReviewStateRecord(cardID: dueCard.id, box: 1, dueAt: now.addingTimeInterval(-10), lapses: 0, lastReviewedAt: nil, easeHint: 1.0),
                ReviewStateRecord(cardID: unlearnedDueCard.id, box: 1, dueAt: now.addingTimeInterval(-10), lapses: 0, lastReviewedAt: nil, easeHint: 1.0),
                ReviewStateRecord(cardID: laterCard.id, box: 2, dueAt: nextDueAt, lapses: 0, lastReviewedAt: nil, easeHint: 1.0)
            ],
            dailyLimit: 3,
            now: now
        )

        XCTAssertEqual(summary.dueReviewCount, 1)
        XCTAssertEqual(summary.learnedTodayCount, 1)
        XCTAssertEqual(summary.remainingNewWordSlots, 2)
        XCTAssertEqual(summary.newWordCount, 1)
        XCTAssertEqual(summary.nextDueAt, nextDueAt)
    }

    private func wordRecord(term: String, status: LearningStatus, learnedAt: Date?, now: Date) -> WordRecord {
        WordRecord(
            id: UUID(),
            term: term,
            languageCode: "ms",
            chineseMeaning: "meaning-\(term)",
            partOfSpeech: "verb",
            pronunciationNotes: "",
            syllablesJSON: "[]",
            examplesJSON: "[]",
            sourceRefsJSON: "[]",
            reviewStatus: "reviewed",
            createdAt: now,
            updatedAt: now,
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
