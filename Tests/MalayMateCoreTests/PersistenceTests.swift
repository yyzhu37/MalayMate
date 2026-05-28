import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class PersistenceTests: XCTestCase {
    func testWordCardAndReviewStateCanRoundTripInMemory() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let wordID = UUID()
        let cardID = UUID()

        context.insert(WordRecord(
            id: wordID,
            term: "makan",
            languageCode: "ms-MY",
            chineseMeaning: "吃；进食",
            partOfSpeech: "verb",
            pronunciationNotes: "ma-kan",
            syllablesJSON: #"["ma","kan"]"#,
            examplesJSON: "[]",
            sourceRefsJSON: "[]",
            reviewStatus: "reviewed",
            createdAt: .now,
            updatedAt: .now
        ))
        context.insert(CardRecord(
            id: cardID,
            wordID: wordID,
            directionRaw: CardDirection.malayToChinese.rawValue,
            prompt: "makan",
            answer: "吃；进食",
            hint: "verb",
            createdAt: .now
        ))
        context.insert(ReviewStateRecord(
            cardID: cardID,
            box: 1,
            dueAt: .now,
            lapses: 0,
            lastReviewedAt: nil,
            easeHint: 1.0
        ))
        try context.save()

        let words = try context.fetch(FetchDescriptor<WordRecord>())
        let cards = try context.fetch(FetchDescriptor<CardRecord>())
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())

        XCTAssertEqual(words.map(\.term), ["makan"])
        XCTAssertEqual(cards.map(\.directionRaw), [CardDirection.malayToChinese.rawValue])
        XCTAssertEqual(states.map(\.box), [1])
    }
}
