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
        XCTAssertEqual(summary.wordsInserted, 3006)
        XCTAssertEqual(summary.cardsInserted, 6012)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DeckRecord>()).count, 3)
        let importedWords = try context.fetch(FetchDescriptor<WordRecord>())
        XCTAssertEqual(importedWords.count, 3006)
        XCTAssertEqual(Set(importedWords.map { $0.term.lowercased() }).count, importedWords.count)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CardRecord>()).count, 6012)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewStateRecord>()).count, 6012)
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

    func testImportAddsMissingWordsToExistingStarterDeck() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let importer = SeedImporter()
        let initial = try deckData(
            deckID: "open-dictionary",
            words: [seedWord(id: "word-satu", term: "satu")]
        )
        let expanded = try deckData(
            deckID: "open-dictionary",
            words: [
                seedWord(id: "word-satu", term: "satu"),
                seedWord(id: "word-dua", term: "dua")
            ]
        )

        _ = try importer.importDecks(from: initial, into: context, now: Date(timeIntervalSince1970: 1_800_000_000))
        let summary = try importer.importDecks(from: expanded, into: context, now: Date(timeIntervalSince1970: 1_800_000_100))

        XCTAssertEqual(summary.decksInserted, 0)
        XCTAssertEqual(summary.wordsInserted, 1)
        XCTAssertEqual(summary.cardsInserted, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DeckRecord>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WordRecord>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CardRecord>()).count, 4)

        let deck = try XCTUnwrap(try context.fetch(FetchDescriptor<DeckRecord>()).first)
        let wordIDs = try JSONDecoder().decode([String].self, from: Data(deck.wordIDsJSON.utf8))
        XCTAssertEqual(wordIDs.count, 2)
    }

    func testImportOnlyMissingStarterDecksWhenOneAlreadyExists() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let data = try SeedResource.bundledStarterDeckData()
        let collection = try JSONDecoder.seedDecoder.decode(SeedDeckCollection.self, from: data)
        let missingWordCount = collection.decks.reduce(0) { $0 + $1.words.count }
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
        XCTAssertEqual(summary.wordsInserted, missingWordCount)
        XCTAssertEqual(summary.cardsInserted, missingWordCount * 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DeckRecord>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CardRecord>()).count, summary.cardsInserted)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewStateRecord>()).count, summary.cardsInserted)
    }

    private func deckData(deckID: String, words: [SeedWord]) throws -> Data {
        let collection = SeedDeckCollection(
            version: 1,
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            decks: [
                SeedDeck(
                    id: deckID,
                    name: "Test Deck",
                    description: "Test deck",
                    isStarter: true,
                    words: words
                )
            ]
        )
        return try JSONEncoder.seedEncoder.encode(collection)
    }

    private func seedWord(id: String, term: String) -> SeedWord {
        SeedWord(
            id: id,
            term: term,
            languageCode: "ms",
            chineseMeaning: "meaning-\(term)",
            partOfSpeech: "number",
            pronunciationNotes: "",
            syllables: [],
            examples: [],
            sourceRefs: [
                SeedSourceRef(
                    field: "term",
                    sourceName: "test",
                    sourceUrl: "local://test",
                    license: "test",
                    attribution: "test",
                    retrievedAt: Date(timeIntervalSince1970: 1_800_000_000),
                    reviewStatus: "needs-review"
                )
            ]
        )
    }
}
