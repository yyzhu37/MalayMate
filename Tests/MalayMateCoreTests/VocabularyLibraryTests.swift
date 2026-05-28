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

    private func makeWord(
        id: UUID,
        term: String,
        examplesJSON: String = "[]",
        createdAt: Date = Date(timeIntervalSince1970: 1)
    ) -> WordRecord {
        WordRecord(
            id: id,
            term: term,
            languageCode: "ms",
            chineseMeaning: "meaning-\(term)",
            partOfSpeech: "noun",
            pronunciationNotes: "note-\(term)",
            syllablesJSON: "[]",
            examplesJSON: examplesJSON,
            sourceRefsJSON: "[]",
            reviewStatus: "reviewed",
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}
