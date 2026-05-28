import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class GeneratedContentTests: XCTestCase {
    func testGeneratedStarterDeckDecodesAndImports() throws {
        let data = try Data(contentsOf: generatedStarterDeckURL())
        let collection = try JSONDecoder.seedDecoder.decode(SeedDeckCollection.self, from: data)
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let summary = try SeedImporter().importDecks(
            from: data,
            into: context,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let cards = try context.fetch(FetchDescriptor<CardRecord>())

        XCTAssertEqual(collection.decks.count, 1)
        XCTAssertEqual(summary.decksInserted, 1)
        XCTAssertEqual(summary.wordsInserted, 300)
        XCTAssertEqual(summary.cardsInserted, 600)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DeckRecord>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WordRecord>()).count, 300)
        XCTAssertEqual(cards.count, 600)
        XCTAssertTrue(cards.allSatisfy { !$0.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertTrue(cards.allSatisfy { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    private func generatedStarterDeckURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "content/generated/starter_deck.json")
    }
}
