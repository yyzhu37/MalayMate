import Foundation

public struct TemplateGenerator: Sendable {
    public init() {}

    public func enrichment(term: String, userMeaning: String, note: String?, now: Date) -> AIEnrichment {
        let trimmedMeaning = userMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let syllables = term.split(separator: "-").map(String.init)
        let inferredSyllables = syllables.count > 1 ? syllables : [term]
        let source = SeedSourceRef(
            field: "example",
            sourceName: "MalayMate template fallback",
            sourceUrl: "local://template-fallback",
            license: "personal-use-local",
            attribution: "MalayMate deterministic template",
            retrievedAt: now,
            reviewStatus: "generated"
        )
        let example = SeedExample(
            id: "template-\(term)-example-1",
            malay: "Saya belajar perkataan \(term).",
            chinese: "我学习单词 \(term)。",
            sourceRefs: [source]
        )
        return AIEnrichment(
            chineseMeaning: trimmedMeaning.isEmpty ? term : trimmedMeaning,
            partOfSpeech: "unknown",
            pronunciationNotes: inferredSyllables.joined(separator: "-"),
            syllables: inferredSyllables,
            examples: [example],
            practicePrompts: ["看到 \(term) 时，先回忆中文意思。"]
        )
    }
}
