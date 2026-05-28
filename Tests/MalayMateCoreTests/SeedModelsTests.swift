import XCTest
@testable import MalayMateCore

final class SeedModelsTests: XCTestCase {
    func testBundledStarterDeckDecodes() throws {
        let data = try SeedResource.bundledStarterDeckData()
        let collection = try JSONDecoder.seedDecoder.decode(SeedDeckCollection.self, from: data)

        XCTAssertEqual(collection.version, 1)
        XCTAssertGreaterThanOrEqual(collection.decks.count, 2)
        XCTAssertTrue(collection.decks.flatMap(\.words).contains { $0.term == "makan" })
        XCTAssertTrue(collection.decks.flatMap(\.words).allSatisfy { !$0.sourceRefs.isEmpty })
    }

    func testBundledOpenFrequencyStarterDeckMatchesGeneratedOutput() throws {
        let generated = try Data(contentsOf: generatedStarterDeckURL())
        let bundled = try SeedResource.bundledOpenFrequencyStarterDeckData()

        XCTAssertEqual(bundled, generated)
    }

    func testAllBundledDeckDataIncludesAuthoredAndGeneratedDecks() throws {
        let allData = try SeedResource.allBundledDeckData()

        XCTAssertEqual(allData.count, 2)
        XCTAssertEqual(allData[0], try SeedResource.bundledStarterDeckData())
        XCTAssertEqual(allData[1], try SeedResource.bundledOpenFrequencyStarterDeckData())
    }

    private func generatedStarterDeckURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "content/generated/starter_deck.json")
    }
}
