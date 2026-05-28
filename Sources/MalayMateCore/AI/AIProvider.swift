import Foundation

public struct AIEnrichment: Codable, Equatable, @unchecked Sendable {
    public var chineseMeaning: String
    public var partOfSpeech: String
    public var pronunciationNotes: String
    public var syllables: [String]
    public var examples: [SeedExample]
    public var practicePrompts: [String]

    public init(chineseMeaning: String, partOfSpeech: String, pronunciationNotes: String, syllables: [String], examples: [SeedExample], practicePrompts: [String]) {
        self.chineseMeaning = chineseMeaning
        self.partOfSpeech = partOfSpeech
        self.pronunciationNotes = pronunciationNotes
        self.syllables = syllables
        self.examples = examples
        self.practicePrompts = practicePrompts
    }
}

public protocol AIProvider: Sendable {
    func enrich(term: String, userMeaning: String, note: String?) async throws -> AIEnrichment
}
