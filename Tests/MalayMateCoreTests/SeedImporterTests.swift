import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class SeedImporterTests: XCTestCase {
    func testImportCreatesDeckWordsCardsAndReviewStates() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let data = try SeedResource.bundledStarterDeckData()
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let summary = try SeedImporter().importDecks(from: data, into: context, now: now)
        let words = try context.fetch(FetchDescriptor<WordRecord>())
        let reviewStates = try context.fetch(FetchDescriptor<ReviewStateRecord>())

        XCTAssertGreaterThanOrEqual(summary.wordsInserted, 6)
        XCTAssertEqual(words.count, summary.wordsInserted)
        XCTAssertTrue(words.contains { $0.term == "makan" })
        XCTAssertEqual(summary.cardsInserted, summary.wordsInserted * 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DeckRecord>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CardRecord>()).count, summary.cardsInserted)
        XCTAssertEqual(reviewStates.count, summary.cardsInserted)
        XCTAssertTrue(words.allSatisfy { LearningStatus(word: $0) == .new })
        XCTAssertTrue(reviewStates.allSatisfy { $0.box == 1 })
        XCTAssertTrue(reviewStates.allSatisfy { $0.dueAt == .distantFuture })
        XCTAssertTrue(reviewStates.allSatisfy { $0.lapses == 0 })
        XCTAssertTrue(reviewStates.allSatisfy { $0.lastReviewedAt == nil })
    }

    func testImportBundledSeedImportsAuthoredAndGeneratedDecks() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let summary = try SeedImporter().importBundledSeed(into: context, now: now)

        XCTAssertEqual(summary.decksInserted, 3)
        XCTAssertEqual(summary.wordsInserted, 46)
        XCTAssertEqual(summary.cardsInserted, 92)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DeckRecord>()).count, 3)
        let importedWords = try context.fetch(FetchDescriptor<WordRecord>())
        XCTAssertEqual(importedWords.count, 46)
        XCTAssertEqual(Set(importedWords.map { $0.term.lowercased() }).count, importedWords.count)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CardRecord>()).count, 92)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewStateRecord>()).count, 92)
        XCTAssertTrue(importedWords.allSatisfy { LearningStatus(word: $0) == .new })
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

    func testImportOnlyMissingStarterDecksWhenOneAlreadyExists() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let data = try SeedResource.bundledStarterDeckData()
        let collection = try JSONDecoder.seedDecoder.decode(SeedDeckCollection.self, from: data)
        let missingDeck = try XCTUnwrap(collection.decks.first { $0.id == "starter-food" })
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(DeckRecord(
            id: "starter-basics",
            name: "Basics",
            deckDescription: "Already imported",
            isStarter: true,
            wordIDsJSON: "[]",
            createdAt: now
        ))
        try context.save()

        let summary = try SeedImporter().importDecks(from: data, into: context, now: now)

        XCTAssertEqual(summary.decksInserted, 1)
        XCTAssertEqual(summary.wordsInserted, missingDeck.words.count)
        XCTAssertEqual(summary.cardsInserted, missingDeck.words.count * 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DeckRecord>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CardRecord>()).count, summary.cardsInserted)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewStateRecord>()).count, summary.cardsInserted)
    }
}
