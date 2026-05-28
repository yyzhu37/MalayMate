import Foundation
import SwiftData

public struct LearnPlan {
    public var dailyLimit: Int
    public var learnedTodayCount: Int
    public var remainingNewWordSlots: Int
    public var words: [WordRecord]
}

@MainActor
public final class LearnSession {
    public static let defaultFirstReviewDelay: TimeInterval = 10 * 60

    private let context: ModelContext
    private let calendar: Calendar
    private let firstReviewDelay: TimeInterval

    public init(context: ModelContext, calendar: Calendar = .current, firstReviewDelay: TimeInterval = LearnSession.defaultFirstReviewDelay) {
        self.context = context
        self.calendar = calendar
        self.firstReviewDelay = firstReviewDelay
    }

    public func plan(selectedDeckID: String?, dailyLimit: Int, now: Date) throws -> LearnPlan {
        let decks = try context.fetch(FetchDescriptor<DeckRecord>(sortBy: [SortDescriptor(\.name)]))
        let words = try context.fetch(FetchDescriptor<WordRecord>())
        return Self.plan(decks: decks, words: words, selectedDeckID: selectedDeckID, dailyLimit: dailyLimit, now: now, calendar: calendar)
    }

    public static func plan(decks: [DeckRecord], words: [WordRecord], selectedDeckID: String?, dailyLimit: Int, now: Date, calendar: Calendar = .current) -> LearnPlan {
        let safeDailyLimit = max(0, dailyLimit)
        let learnedTodayCount = words.filter { word in
            guard let learnedAt = word.learnedAt else {
                return false
            }
            return calendar.isDate(learnedAt, inSameDayAs: now)
        }.count
        let remainingSlots = max(0, safeDailyLimit - learnedTodayCount)
        let sections = VocabularyLibrary.sections(decks: decks, words: words)
        let selectedSections: [VocabularyLibrarySection]
        if let selectedDeckID {
            selectedSections = sections.filter { $0.id == selectedDeckID }
        } else {
            selectedSections = sections
        }
        let newWords = selectedSections
            .flatMap(\.words)
            .filter { LearningStatus(word: $0) == .new }
            .prefix(remainingSlots)

        return LearnPlan(
            dailyLimit: safeDailyLimit,
            learnedTodayCount: learnedTodayCount,
            remainingNewWordSlots: remainingSlots,
            words: Array(newWords)
        )
    }

    public func markLearned(wordID: UUID, now: Date) throws {
        let words = try context.fetch(FetchDescriptor<WordRecord>())
        guard let word = words.first(where: { $0.id == wordID }) else {
            throw LearnSessionError.missingWord(wordID)
        }

        let cards = try context.fetch(FetchDescriptor<CardRecord>()).filter { $0.wordID == wordID }
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
        let statesByCardID = Dictionary(uniqueKeysWithValues: states.map { ($0.cardID, $0) })
        let firstReviewAt = now.addingTimeInterval(firstReviewDelay)

        word.learningStatusRaw = LearningStatus.inReview.rawValue
        word.learnedAt = now
        word.updatedAt = now

        for card in cards {
            guard let state = statesByCardID[card.id] else {
                throw LearnSessionError.missingReviewState(card.id)
            }
            state.box = 1
            state.dueAt = firstReviewAt
            state.lapses = 0
            state.lastReviewedAt = nil
            state.easeHint = 1.0
        }

        try context.save()
    }
}

public enum LearnSessionError: Error, Equatable {
    case missingWord(UUID)
    case missingReviewState(UUID)
}
