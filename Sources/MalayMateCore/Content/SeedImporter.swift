import Foundation
import SwiftData

public struct SeedImportSummary: Equatable {
    public var decksInserted: Int
    public var wordsInserted: Int
    public var cardsInserted: Int
}

public struct SeedImporter {
    public init() {}

    @MainActor
    public func importBundledSeed(into context: ModelContext, now: Date = .now) throws -> SeedImportSummary {
        try importDecks(from: SeedResource.bundledStarterDeckData(), into: context, now: now)
    }

    @MainActor
    public func importDecks(from data: Data, into context: ModelContext, now: Date) throws -> SeedImportSummary {
        let starterDescriptor = FetchDescriptor<DeckRecord>(predicate: #Predicate { $0.isStarter == true })
        let existingStarterDecks = try context.fetch(starterDescriptor)
        guard existingStarterDecks.isEmpty else {
            return SeedImportSummary(decksInserted: 0, wordsInserted: 0, cardsInserted: 0)
        }

        let collection = try JSONDecoder.seedDecoder.decode(SeedDeckCollection.self, from: data)
        var decksInserted = 0
        var wordsInserted = 0
        var cardsInserted = 0
        let scheduler = LeitnerScheduler()

        for deck in collection.decks {
            var wordIDs: [String] = []

            for seedWord in deck.words {
                let wordID = stableUUID(from: seedWord.id)
                wordIDs.append(wordID.uuidString)
                let word = WordRecord(
                    id: wordID,
                    term: seedWord.term,
                    languageCode: seedWord.languageCode,
                    chineseMeaning: seedWord.chineseMeaning,
                    partOfSpeech: seedWord.partOfSpeech,
                    pronunciationNotes: seedWord.pronunciationNotes,
                    syllablesJSON: try encodeJSONString(seedWord.syllables),
                    examplesJSON: try encodeJSONString(seedWord.examples),
                    sourceRefsJSON: try encodeJSONString(seedWord.sourceRefs),
                    reviewStatus: "reviewed",
                    createdAt: now,
                    updatedAt: now
                )
                context.insert(word)
                wordsInserted += 1

                let directions: [CardDirection] = [.malayToChinese, .chineseToMalay]
                for direction in directions {
                    let cardID = stableUUID(from: "\(seedWord.id)-\(direction.rawValue)")
                    let card = CardRecord(
                        id: cardID,
                        wordID: wordID,
                        directionRaw: direction.rawValue,
                        prompt: direction == .malayToChinese ? seedWord.term : seedWord.chineseMeaning,
                        answer: direction == .malayToChinese ? seedWord.chineseMeaning : seedWord.term,
                        hint: seedWord.partOfSpeech,
                        createdAt: now
                    )
                    context.insert(card)
                    let state = scheduler.initialState(now: now)
                    context.insert(ReviewStateRecord(
                        cardID: cardID,
                        box: state.box,
                        dueAt: state.dueAt,
                        lapses: state.lapses,
                        lastReviewedAt: state.lastReviewedAt,
                        easeHint: state.easeHint
                    ))
                    cardsInserted += 1
                }
            }

            context.insert(DeckRecord(
                id: deck.id,
                name: deck.name,
                deckDescription: deck.description,
                isStarter: deck.isStarter,
                wordIDsJSON: try encodeJSONString(wordIDs),
                createdAt: now
            ))
            decksInserted += 1
        }

        try context.save()
        return SeedImportSummary(decksInserted: decksInserted, wordsInserted: wordsInserted, cardsInserted: cardsInserted)
    }

    private func encodeJSONString<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder.seedEncoder.encode(value), as: UTF8.self)
    }

    private func stableUUID(from string: String) -> UUID {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let raw = String(format: "%016llx", hash)
        let suffix = String(raw.suffix(12))
        return UUID(uuidString: "00000000-0000-4000-8000-\(suffix)")!
    }
}
