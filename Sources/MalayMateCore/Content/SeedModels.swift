import Foundation

public struct SeedDeckCollection: Codable, Equatable, Sendable {
    public var version: Int
    public var generatedAt: Date
    public var decks: [SeedDeck]
}

public struct SeedDeck: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var isStarter: Bool
    public var words: [SeedWord]
}

public struct SeedWord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var term: String
    public var languageCode: String
    public var chineseMeaning: String
    public var partOfSpeech: String
    public var pronunciationNotes: String
    public var syllables: [String]
    public var examples: [SeedExample]
    public var sourceRefs: [SeedSourceRef]
}

public struct SeedExample: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var malay: String
    public var chinese: String
    public var sourceRefs: [SeedSourceRef]
}

public struct SeedSourceRef: Codable, Equatable, Sendable {
    public var field: String
    public var sourceName: String
    public var sourceUrl: String
    public var license: String
    public var attribution: String
    public var retrievedAt: Date
    public var reviewStatus: String
}

public extension JSONDecoder {
    static var seedDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension JSONEncoder {
    static var seedEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

public enum SeedResource {
    public static func bundledStarterDeckData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "starter_deck", withExtension: "json") else {
            throw SeedResourceError.missingBundledStarterDeck
        }
        return try Data(contentsOf: url)
    }
}

public enum SeedResourceError: Error, Equatable {
    case missingBundledStarterDeck
}
