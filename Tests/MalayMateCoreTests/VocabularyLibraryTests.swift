import XCTest
@testable import MalayMateCore

final class VocabularyLibraryTests: XCTestCase {
    func testSectionsPreserveDeckWordOrderAndIncludeUnassignedWords() throws {
        let firstID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let personalID = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
        let deck = DeckRecord(
            id: "starter",
            name: "Starter",
            deckDescription: "Starter words",
            isStarter: true,
            wordIDsJSON: #"["\#(secondID.uuidString)","\#(firstID.uuidString)"]"#,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let words = [
            makeWord(id: firstID, term: "saya", createdAt: Date(timeIntervalSince1970: 1)),
            makeWord(id: secondID, term: "makan", createdAt: Date(timeIntervalSince1970: 2)),
            makeWord(id: personalID, term: "kopi", createdAt: Date(timeIntervalSince1970: 3))
        ]

        let sections = VocabularyLibrary.sections(decks: [deck], words: words)

        XCTAssertEqual(sections.map(\.id), ["starter", VocabularyLibrary.personalSectionID])
        XCTAssertEqual(sections[0].words.map(\.term), ["makan", "saya"])
        XCTAssertEqual(sections[1].name, "Personal Words")
        XCTAssertEqual(sections[1].words.map(\.term), ["kopi"])
    }

    func testExamplesDecodeFromWordRecord() throws {
        let example = SeedExample(
            id: "example-1",
            malay: "Saya makan nasi.",
            chinese: "我吃米饭。",
            sourceRefs: []
        )
        let word = makeWord(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000004")!,
            term: "makan",
            examplesJSON: String(decoding: try JSONEncoder.seedEncoder.encode([example]), as: UTF8.self)
        )

        let examples = VocabularyLibrary.examples(for: word)

        XCTAssertEqual(examples, [example])
    }

    func testBrowseSectionsSearchesFiltersSortsAndLimitsRows() throws {
        let firstID = UUID(uuidString: "00000000-0000-4000-8000-000000000011")!
        let secondID = UUID(uuidString: "00000000-0000-4000-8000-000000000012")!
        let thirdID = UUID(uuidString: "00000000-0000-4000-8000-000000000013")!
        let deck = DeckRecord(
            id: "starter",
            name: "Starter",
            deckDescription: "Starter words",
            isStarter: true,
            wordIDsJSON: #"["\#(firstID.uuidString)","\#(secondID.uuidString)","\#(thirdID.uuidString)"]"#,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let words = [
            makeWord(id: firstID, term: "zebra", meaning: "斑马", status: .new, createdAt: Date(timeIntervalSince1970: 1)),
            makeWord(id: secondID, term: "makan", meaning: "吃米饭", status: .inReview, createdAt: Date(timeIntervalSince1970: 3)),
            makeWord(id: thirdID, term: "api", meaning: "火", status: .inReview, createdAt: Date(timeIntervalSince1970: 2))
        ]

        let searchResult = VocabularyLibrary.browseSections(
            decks: [deck],
            words: words,
            selectedDeckID: "starter",
            query: VocabularyLibraryQuery(searchText: "米饭", visibleLimit: 10)
        )
        XCTAssertEqual(searchResult.totalMatches, 1)
        XCTAssertEqual(searchResult.sections.flatMap(\.words).map(\.term), ["makan"])

        let limitedResult = VocabularyLibrary.browseSections(
            decks: [deck],
            words: words,
            selectedDeckID: "starter",
            query: VocabularyLibraryQuery(statusFilter: .inReview, sort: .term, visibleLimit: 1)
        )
        XCTAssertEqual(limitedResult.totalMatches, 2)
        XCTAssertEqual(limitedResult.visibleCount, 1)
        XCTAssertTrue(limitedResult.hasMore)
        XCTAssertEqual(limitedResult.sections.flatMap(\.words).map(\.term), ["api"])
    }

    private func makeWord(
        id: UUID,
        term: String,
        meaning: String? = nil,
        status: LearningStatus = .new,
        examplesJSON: String = "[]",
        createdAt: Date = Date(timeIntervalSince1970: 1)
    ) -> WordRecord {
        WordRecord(
            id: id,
            term: term,
            languageCode: "ms",
            chineseMeaning: meaning ?? "meaning-\(term)",
            partOfSpeech: "noun",
            pronunciationNotes: "note-\(term)",
            syllablesJSON: "[]",
            examplesJSON: examplesJSON,
            sourceRefsJSON: "[]",
            reviewStatus: "reviewed",
            createdAt: createdAt,
            updatedAt: createdAt,
            learningStatusRaw: status.rawValue
        )
    }
}
