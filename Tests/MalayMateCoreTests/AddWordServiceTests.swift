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
        let reviewStates = try context.fetch(FetchDescriptor<ReviewStateRecord>()).filter { state in
            cards.contains { $0.id == state.cardID }
        }
        XCTAssertEqual(word.term, "belajar")
        XCTAssertEqual(word.chineseMeaning, "学习")
        XCTAssertEqual(word.partOfSpeech, "unknown")
        XCTAssertEqual(word.pronunciationNotes, "belajar")
        XCTAssertEqual(word.reviewStatus, "needsEnrichment")
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(reviewStates.count, 2)
        for reviewState in reviewStates {
            XCTAssertEqual(reviewState.box, 1)
            XCTAssertEqual(reviewState.dueAt, Date(timeIntervalSince1970: 1_800_000_000))
            XCTAssertEqual(reviewState.lapses, 0)
            XCTAssertNil(reviewState.lastReviewedAt)
            XCTAssertEqual(reviewState.easeHint, 1.0)
        }

        let malayToChinese = try XCTUnwrap(cards.first { $0.directionRaw == CardDirection.malayToChinese.rawValue })
        XCTAssertEqual(malayToChinese.prompt, "belajar")
        XCTAssertEqual(malayToChinese.answer, "学习")

        let chineseToMalay = try XCTUnwrap(cards.first { $0.directionRaw == CardDirection.chineseToMalay.rawValue })
        XCTAssertEqual(chineseToMalay.prompt, "学习")
        XCTAssertEqual(chineseToMalay.answer, "belajar")

        let examples = try JSONDecoder.seedDecoder.decode([SeedExample].self, from: Data(word.examplesJSON.utf8))
        XCTAssertTrue(examples.contains { $0.malay.contains("belajar") })
    }

    func testAddWordTrimsWhitespaceOnlyMeaningBeforeTemplateFallback() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let service = AddWordService(context: context, aiProvider: nil, scheduler: LeitnerScheduler())

        let wordID = try await service.addWord(term: " makan ", userMeaning: " \n\t ", note: nil, now: Date(timeIntervalSince1970: 1_800_000_001))

        let word = try XCTUnwrap(try context.fetch(FetchDescriptor<WordRecord>()).first { $0.id == wordID })
        let cards = try context.fetch(FetchDescriptor<CardRecord>()).filter { $0.wordID == wordID }
        let malayToChinese = try XCTUnwrap(cards.first { $0.directionRaw == CardDirection.malayToChinese.rawValue })
        let chineseToMalay = try XCTUnwrap(cards.first { $0.directionRaw == CardDirection.chineseToMalay.rawValue })

        XCTAssertEqual(word.term, "makan")
        XCTAssertEqual(word.chineseMeaning, "makan")
        XCTAssertEqual(malayToChinese.prompt, "makan")
        XCTAssertEqual(malayToChinese.answer, "makan")
        XCTAssertEqual(chineseToMalay.prompt, "makan")
        XCTAssertEqual(chineseToMalay.answer, "makan")
    }

    func testAddWordRejectsEmptyTerm() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let service = AddWordService(context: context, aiProvider: nil, scheduler: LeitnerScheduler())

        do {
            _ = try await service.addWord(term: " \n\t ", userMeaning: "学习", note: nil)
            XCTFail("Expected empty term to throw")
        } catch let error as AddWordError {
            XCTAssertEqual(error, .emptyTerm)
        }

        XCTAssertTrue(try context.fetch(FetchDescriptor<WordRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CardRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ReviewStateRecord>()).isEmpty)
    }

    func testAddWordFallsBackToTemplateWhenProviderThrows() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let service = AddWordService(context: context, aiProvider: ThrowingAIProvider(), scheduler: LeitnerScheduler())

        let wordID = try await service.addWord(term: "minum", userMeaning: " 喝 ", note: nil, now: Date(timeIntervalSince1970: 1_800_000_002))

        let word = try XCTUnwrap(try context.fetch(FetchDescriptor<WordRecord>()).first { $0.id == wordID })
        let cards = try context.fetch(FetchDescriptor<CardRecord>()).filter { $0.wordID == wordID }
        let malayToChinese = try XCTUnwrap(cards.first { $0.directionRaw == CardDirection.malayToChinese.rawValue })
        let chineseToMalay = try XCTUnwrap(cards.first { $0.directionRaw == CardDirection.chineseToMalay.rawValue })

        XCTAssertEqual(word.chineseMeaning, "喝")
        XCTAssertEqual(word.reviewStatus, "needsEnrichment")
        XCTAssertEqual(malayToChinese.prompt, "minum")
        XCTAssertEqual(malayToChinese.answer, "喝")
        XCTAssertEqual(chineseToMalay.prompt, "喝")
        XCTAssertEqual(chineseToMalay.answer, "minum")
    }
}

private struct ThrowingAIProvider: AIProvider {
    func enrich(term: String, userMeaning: String, note: String?) async throws -> AIEnrichment {
        throw TestError.providerUnavailable
    }
}

private enum TestError: Error {
    case providerUnavailable
}
