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
    public var audioURL: String? = nil
    public var audioFormat: String? = nil
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
        try bundledDeckData(resourceName: "starter_deck", missingError: .missingBundledStarterDeck)
    }

    public static func bundledOpenFrequencyStarterDeckData() throws -> Data {
        try bundledDeckData(resourceName: "open_frequency_starter_deck", missingError: .missingBundledOpenFrequencyStarterDeck)
    }

    public static func allBundledDeckData() throws -> [Data] {
        [
            try bundledStarterDeckData(),
            try bundledOpenFrequencyStarterDeckData()
        ]
    }

    private static func bundledDeckData(resourceName: String, missingError: SeedResourceError) throws -> Data {
        guard let url = resourceBundle().url(forResource: resourceName, withExtension: "json") else {
            throw missingError
        }
        return try Data(contentsOf: url)
    }

    private static func resourceBundle() -> Bundle {
        let bundleName = "MalayMate_MalayMateCore.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            Bundle.module.bundleURL
        ]

        for candidate in candidates {
            if let candidate, let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        return Bundle.module
    }
}

public enum SeedResourceError: Error, Equatable {
    case missingBundledStarterDeck
    case missingBundledOpenFrequencyStarterDeck
}
