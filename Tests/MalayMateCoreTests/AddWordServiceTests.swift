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
        XCTAssertEqual(word.chineseMeaning, "学习")
        XCTAssertEqual(word.partOfSpeech, "unknown")
        XCTAssertEqual(word.pronunciationNotes, "belajar")
        XCTAssertEqual(word.reviewStatus, "needsEnrichment")
        XCTAssertEqual(cards.count, 2)

        let malayToChinese = try XCTUnwrap(cards.first { $0.directionRaw == CardDirection.malayToChinese.rawValue })
        XCTAssertEqual(malayToChinese.prompt, "belajar")
        XCTAssertEqual(malayToChinese.answer, "学习")

        let chineseToMalay = try XCTUnwrap(cards.first { $0.directionRaw == CardDirection.chineseToMalay.rawValue })
        XCTAssertEqual(chineseToMalay.prompt, "学习")
        XCTAssertEqual(chineseToMalay.answer, "belajar")

        let examples = try JSONDecoder.seedDecoder.decode([SeedExample].self, from: Data(word.examplesJSON.utf8))
        XCTAssertTrue(examples.contains { $0.malay.contains("belajar") })
    }
}
