import Foundation

public struct TodaySummary: Equatable, Sendable {
    public let dueReviewCount: Int
    public let learnedTodayCount: Int
    public let remainingNewWordSlots: Int
    public let newWordCount: Int
    public let nextDueAt: Date?

    public init(dueReviewCount: Int, learnedTodayCount: Int, remainingNewWordSlots: Int, newWordCount: Int, nextDueAt: Date?) {
        self.dueReviewCount = dueReviewCount
        self.learnedTodayCount = learnedTodayCount
        self.remainingNewWordSlots = remainingNewWordSlots
        self.newWordCount = newWordCount
        self.nextDueAt = nextDueAt
    }

    public static func make(
        words: [WordRecord],
        cards: [CardRecord],
        reviewStates: [ReviewStateRecord],
        dailyLimit: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> TodaySummary {
        let safeDailyLimit = max(0, dailyLimit)
        let wordsByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        let cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        let learnedTodayCount = words.filter { word in
            guard let learnedAt = word.learnedAt else {
                return false
            }
            return calendar.isDate(learnedAt, inSameDayAs: now)
        }.count
        let reviewableStates = reviewStates.compactMap { state -> ReviewStateRecord? in
            guard
                let card = cardsByID[state.cardID],
                let word = wordsByID[card.wordID],
                LearningStatus(word: word) != .new
            else {
                return nil
            }
            return state
        }
        let nextDueAt = reviewableStates
            .map(\.dueAt)
            .filter { $0 > now }
            .min()

        return TodaySummary(
            dueReviewCount: reviewableStates.filter { $0.dueAt <= now }.count,
            learnedTodayCount: learnedTodayCount,
            remainingNewWordSlots: max(0, safeDailyLimit - learnedTodayCount),
            newWordCount: words.filter { LearningStatus(word: $0) == .new }.count,
            nextDueAt: nextDueAt
        )
    }
}
