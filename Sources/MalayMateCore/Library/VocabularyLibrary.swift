import Foundation

public struct VocabularyLibrarySection: Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var isStarter: Bool
    public var words: [WordRecord]

    public init(id: String, name: String, description: String, isStarter: Bool, words: [WordRecord]) {
        self.id = id
        self.name = name
        self.description = description
        self.isStarter = isStarter
        self.words = words
    }
}

public enum VocabularyLibrary {
    public static let personalSectionID = "personal-words"

    public static func sections(decks: [DeckRecord], words: [WordRecord]) -> [VocabularyLibrarySection] {
        let wordsByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id.uuidString, $0) })
        var assignedWordIDs = Set<UUID>()

        var sections = decks.map { deck in
            let deckWordIDs = decodeWordIDs(from: deck.wordIDsJSON)
            let deckWords = deckWordIDs.compactMap { wordID -> WordRecord? in
                guard let word = wordsByID[wordID.uuidString] else {
                    return nil
                }
                assignedWordIDs.insert(word.id)
                return word
            }
            return VocabularyLibrarySection(
                id: deck.id,
                name: deck.name,
                description: deck.deckDescription,
                isStarter: deck.isStarter,
                words: deckWords
            )
        }

        let personalWords = words
            .filter { !assignedWordIDs.contains($0.id) }
            .sorted { left, right in
                if left.createdAt != right.createdAt {
                    return left.createdAt < right.createdAt
                }
                return left.term.localizedStandardCompare(right.term) == .orderedAscending
            }

        if !personalWords.isEmpty {
            sections.append(VocabularyLibrarySection(
                id: personalSectionID,
                name: "Personal Words",
                description: "Words you added yourself.",
                isStarter: false,
                words: personalWords
            ))
        }

        return sections
    }

    public static func examples(for word: WordRecord) -> [SeedExample] {
        guard let data = word.examplesJSON.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder.seedDecoder.decode([SeedExample].self, from: data)) ?? []
    }

    private static func decodeWordIDs(from json: String) -> [UUID] {
        guard let data = json.data(using: .utf8),
              let rawIDs = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return rawIDs.compactMap(UUID.init(uuidString:))
    }
}
