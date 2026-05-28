import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class SeedImporterTests: XCTestCase {
    func testImportCreatesDeckWordsCardsAndReviewStates() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let data = try SeedResource.bundledStarterDeckData()

        let summary = try SeedImporter().importDecks(from: data, into: context, now: Date(timeIntervalSince1970: 1_800_000_000))
        let words = try context.fetch(FetchDescriptor<WordRecord>())

        XCTAssertGreaterThanOrEqual(summary.wordsInserted, 6)
        XCTAssertEqual(words.count, summary.wordsInserted)
        XCTAssertTrue(words.contains { $0.term == "makan" })
        XCTAssertEqual(summary.cardsInserted, summary.wordsInserted * 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DeckRecord>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CardRecord>()).count, summary.cardsInserted)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewStateRecord>()).count, summary.cardsInserted)
    }

    func testSecondImportDoesNotDuplicateStarterDecks() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let data = try SeedResource.bundledStarterDeckData()
        let importer = SeedImporter()

        _ = try importer.importDecks(from: data, into: context, now: .now)
        let second = try importer.importDecks(from: data, into: context, now: .now)

        XCTAssertEqual(second.decksInserted, 0)
        XCTAssertEqual(second.wordsInserted, 0)
        XCTAssertEqual(second.cardsInserted, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DeckRecord>()).count, 2)
    }
}
