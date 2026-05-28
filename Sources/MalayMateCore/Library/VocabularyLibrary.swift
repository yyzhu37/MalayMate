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

public enum VocabularyLibraryStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case new
    case inReview
    case mastered

    public var id: String { rawValue }
}

public enum VocabularyLibrarySort: String, CaseIterable, Identifiable, Sendable {
    case deckOrder
    case term
    case status
    case createdNewest

    public var id: String { rawValue }
}

public struct VocabularyLibraryQuery: Equatable, Sendable {
    public var searchText: String
    public var statusFilter: VocabularyLibraryStatusFilter
    public var sort: VocabularyLibrarySort
    public var visibleLimit: Int

    public init(
        searchText: String = "",
        statusFilter: VocabularyLibraryStatusFilter = .all,
        sort: VocabularyLibrarySort = .deckOrder,
        visibleLimit: Int = 100
    ) {
        self.searchText = searchText
        self.statusFilter = statusFilter
        self.sort = sort
        self.visibleLimit = visibleLimit
    }
}

public struct VocabularyLibraryBrowseResult {
    public var sections: [VocabularyLibrarySection]
    public var totalMatches: Int
    public var visibleCount: Int
    public var hasMore: Bool

    public init(sections: [VocabularyLibrarySection], totalMatches: Int, visibleCount: Int, hasMore: Bool) {
        self.sections = sections
        self.totalMatches = totalMatches
        self.visibleCount = visibleCount
        self.hasMore = hasMore
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

    public static func browseSections(
        decks: [DeckRecord],
        words: [WordRecord],
        selectedDeckID: String?,
        query: VocabularyLibraryQuery
    ) -> VocabularyLibraryBrowseResult {
        let normalizedSearchText = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let baseSections = sections(decks: decks, words: words)
        let selectedSections: [VocabularyLibrarySection]
        if let selectedDeckID {
            selectedSections = baseSections.filter { $0.id == selectedDeckID }
        } else {
            selectedSections = baseSections
        }

        let matchedSections = selectedSections.compactMap { section -> VocabularyLibrarySection? in
            let matchedWords = section.words
                .filter { matches($0, searchText: normalizedSearchText) }
                .filter { matches($0, statusFilter: query.statusFilter) }
            let sortedWords = sort(matchedWords, by: query.sort)
            guard !sortedWords.isEmpty else {
                return nil
            }
            return VocabularyLibrarySection(
                id: section.id,
                name: section.name,
                description: section.description,
                isStarter: section.isStarter,
                words: sortedWords
            )
        }

        let totalMatches = matchedSections.reduce(0) { $0 + $1.words.count }
        var remaining = max(0, query.visibleLimit)
        var visibleSections: [VocabularyLibrarySection] = []

        for section in matchedSections where remaining > 0 {
            let visibleWords = Array(section.words.prefix(remaining))
            remaining -= visibleWords.count
            guard !visibleWords.isEmpty else {
                continue
            }
            visibleSections.append(VocabularyLibrarySection(
                id: section.id,
                name: section.name,
                description: section.description,
                isStarter: section.isStarter,
                words: visibleWords
            ))
        }

        let visibleCount = visibleSections.reduce(0) { $0 + $1.words.count }
        return VocabularyLibraryBrowseResult(
            sections: visibleSections,
            totalMatches: totalMatches,
            visibleCount: visibleCount,
            hasMore: visibleCount < totalMatches
        )
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

    private static func matches(_ word: WordRecord, searchText: String) -> Bool {
        guard !searchText.isEmpty else {
            return true
        }

        return [
            word.term,
            word.chineseMeaning,
            word.partOfSpeech,
            word.pronunciationNotes
        ].contains { value in
            value.lowercased().contains(searchText)
        }
    }

    private static func matches(_ word: WordRecord, statusFilter: VocabularyLibraryStatusFilter) -> Bool {
        switch statusFilter {
        case .all:
            return true
        case .new:
            return LearningStatus(word: word) == .new
        case .inReview:
            return LearningStatus(word: word) == .inReview
        case .mastered:
            return LearningStatus(word: word) == .mastered
        }
    }

    private static func sort(_ words: [WordRecord], by sort: VocabularyLibrarySort) -> [WordRecord] {
        switch sort {
        case .deckOrder:
            return words
        case .term:
            return words.sorted {
                $0.term.localizedStandardCompare($1.term) == .orderedAscending
            }
        case .status:
            return words.sorted { left, right in
                let leftRank = statusRank(LearningStatus(word: left))
                let rightRank = statusRank(LearningStatus(word: right))
                if leftRank != rightRank {
                    return leftRank < rightRank
                }
                return left.term.localizedStandardCompare(right.term) == .orderedAscending
            }
        case .createdNewest:
            return words.sorted { left, right in
                if left.createdAt != right.createdAt {
                    return left.createdAt > right.createdAt
                }
                return left.term.localizedStandardCompare(right.term) == .orderedAscending
            }
        }
    }

    private static func statusRank(_ status: LearningStatus) -> Int {
        switch status {
        case .new:
            return 0
        case .inReview:
            return 1
        case .mastered:
            return 2
        }
    }
}
