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
}
