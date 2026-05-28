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
        var total = SeedImportSummary(decksInserted: 0, wordsInserted: 0, cardsInserted: 0)
        for data in try SeedResource.allBundledDeckData() {
            let summary = try importDecks(from: data, into: context, now: now)
            total.decksInserted += summary.decksInserted
            total.wordsInserted += summary.wordsInserted
            total.cardsInserted += summary.cardsInserted
        }
        return total
    }

    @MainActor
    public func importDecks(from data: Data, into context: ModelContext, now: Date) throws -> SeedImportSummary {
        let collection = try JSONDecoder.seedDecoder.decode(SeedDeckCollection.self, from: data)
        let existingDecks = try context.fetch(FetchDescriptor<DeckRecord>())
        let existingDecksByID = Dictionary(uniqueKeysWithValues: existingDecks.map { ($0.id, $0) })
        let existingWords = try context.fetch(FetchDescriptor<WordRecord>())
        var existingWordIDs = Set(existingWords.map(\.id))

        var decksInserted = 0
        var wordsInserted = 0
        var cardsInserted = 0
        let scheduler = LeitnerScheduler()

        for deck in collection.decks {
            var wordIDs = existingDecksByID[deck.id].map { decodeWordIDs(from: $0.wordIDsJSON) } ?? []
            var deckWordIDSet = Set(wordIDs)

            for seedWord in deck.words {
                let wordID = stableUUID(from: seedWord.id)
                if !deckWordIDSet.contains(wordID.uuidString) {
                    wordIDs.append(wordID.uuidString)
                    deckWordIDSet.insert(wordID.uuidString)
                }

                guard !existingWordIDs.contains(wordID) else {
                    continue
                }

                try insertWord(seedWord, wordID: wordID, into: context, now: now)
                existingWordIDs.insert(wordID)
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
                        dueAt: .distantFuture,
                        lapses: state.lapses,
                        lastReviewedAt: state.lastReviewedAt,
                        easeHint: state.easeHint
                    ))
                    cardsInserted += 1
                }
            }

            if let existingDeck = existingDecksByID[deck.id] {
                existingDeck.name = deck.name
                existingDeck.deckDescription = deck.description
                existingDeck.isStarter = deck.isStarter
                existingDeck.wordIDsJSON = try encodeJSONString(wordIDs)
            } else {
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
        }

        try context.save()
        return SeedImportSummary(decksInserted: decksInserted, wordsInserted: wordsInserted, cardsInserted: cardsInserted)
    }

    private func insertWord(_ seedWord: SeedWord, wordID: UUID, into context: ModelContext, now: Date) throws {
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
            updatedAt: now,
            learningStatusRaw: LearningStatus.new.rawValue,
            learnedAt: nil
        )
        context.insert(word)
    }

    private func encodeJSONString<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder.seedEncoder.encode(value), as: UTF8.self)
    }

    private func decodeWordIDs(from json: String) -> [String] {
        guard let data = json.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
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
