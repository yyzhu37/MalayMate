import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class AddWordServiceTests: XCTestCase {
    func testAddWordWithoutProviderUsesTemplateAndCreatesCards() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let service = AddWordService(context: context, aiProvider: nil, scheduler: LeitnerScheduler())

        let wordID = try await service.addWord(term: "belajar", userMeaning: "学习", note: "daily study", now: Date(timeIntervalSince1970: 1_800_000_000))

        let word = try XCTUnwrap(try context.fetch(FetchDescriptor<WordRecord>()).first { $0.id == wordID })
        let cards = try context.fetch(FetchDescriptor<CardRecord>()).filter { $0.wordID == wordID }
        XCTAssertEqual(word.term, "belajar")
        XCTAssertEqual(word.reviewStatus, "needsEnrichment")
        XCTAssertEqual(cards.count, 2)
        XCTAssertTrue(cards.contains { $0.directionRaw == CardDirection.malayToChinese.rawValue })
        XCTAssertTrue(cards.contains { $0.directionRaw == CardDirection.chineseToMalay.rawValue })
    }
}
