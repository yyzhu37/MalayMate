import Foundation
import SwiftData

@MainActor
public final class AddWordService {
    private let context: ModelContext
    private let aiProvider: AIProvider?
    private let scheduler: LeitnerScheduler
    private let templateGenerator: TemplateGenerator

    public init(context: ModelContext, aiProvider: AIProvider?, scheduler: LeitnerScheduler = LeitnerScheduler(), templateGenerator: TemplateGenerator = TemplateGenerator()) {
        self.context = context
        self.aiProvider = aiProvider
        self.scheduler = scheduler
        self.templateGenerator = templateGenerator
    }

    public func addWord(term: String, userMeaning: String, note: String?, now: Date = .now) async throws -> UUID {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else {
            throw AddWordError.emptyTerm
        }

        let enrichment: AIEnrichment
        let reviewStatus: String
        do {
            if let aiProvider {
                enrichment = try await aiProvider.enrich(term: trimmedTerm, userMeaning: userMeaning, note: note)
                reviewStatus = "aiGenerated"
            } else {
                enrichment = templateGenerator.enrichment(term: trimmedTerm, userMeaning: userMeaning, note: note, now: now)
                reviewStatus = "needsEnrichment"
            }
        } catch {
            enrichment = templateGenerator.enrichment(term: trimmedTerm, userMeaning: userMeaning, note: note, now: now)
            reviewStatus = "needsEnrichment"
        }

        let wordID = UUID()
        let sourceRefs = [
            SeedSourceRef(
                field: "term",
                sourceName: "User input",
                sourceUrl: "local://user-input",
                license: "personal-use-local",
                attribution: "User-added word",
                retrievedAt: now,
                reviewStatus: reviewStatus
            )
        ]
        let word = WordRecord(
            id: wordID,
            term: trimmedTerm,
            languageCode: "ms-MY",
            chineseMeaning: enrichment.chineseMeaning,
            partOfSpeech: enrichment.partOfSpeech,
            pronunciationNotes: enrichment.pronunciationNotes,
            syllablesJSON: try encodeJSONString(enrichment.syllables),
            examplesJSON: try encodeJSONString(enrichment.examples),
            sourceRefsJSON: try encodeJSONString(sourceRefs),
            reviewStatus: reviewStatus,
            createdAt: now,
            updatedAt: now
        )
        context.insert(word)

        for direction in [CardDirection.malayToChinese, .chineseToMalay] {
            let cardID = UUID()
            context.insert(CardRecord(
                id: cardID,
                wordID: wordID,
                directionRaw: direction.rawValue,
                prompt: direction == .malayToChinese ? trimmedTerm : enrichment.chineseMeaning,
                answer: direction == .malayToChinese ? enrichment.chineseMeaning : trimmedTerm,
                hint: enrichment.partOfSpeech,
                createdAt: now
            ))
            let state = scheduler.initialState(now: now)
            context.insert(ReviewStateRecord(
                cardID: cardID,
                box: state.box,
                dueAt: state.dueAt,
                lapses: state.lapses,
                lastReviewedAt: state.lastReviewedAt,
                easeHint: state.easeHint
            ))
        }

        try context.save()
        return wordID
    }

    private func encodeJSONString<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder.seedEncoder.encode(value), as: UTF8.self)
    }
}

public enum AddWordError: Error, Equatable {
    case emptyTerm
}
