import Foundation
import SwiftData

public struct DueReviewItem: Identifiable {
    public var id: UUID { card.id }
    public var word: WordRecord
    public var card: CardRecord
    public var state: ReviewStateRecord
}

@MainActor
public final class ReviewSession {
    private let context: ModelContext
    private let scheduler: LeitnerScheduler

    public init(context: ModelContext, scheduler: LeitnerScheduler = LeitnerScheduler()) {
        self.context = context
        self.scheduler = scheduler
    }

    public func dueCards(now: Date, limit: Int = 100) throws -> [DueReviewItem] {
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>()).filter { $0.dueAt <= now }
        let cards = try context.fetch(FetchDescriptor<CardRecord>())
        let words = try context.fetch(FetchDescriptor<WordRecord>())
        let cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        let wordsByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })

        return states
            .sorted { left, right in
                if left.dueAt != right.dueAt {
                    return left.dueAt < right.dueAt
                }
                return left.cardID.uuidString < right.cardID.uuidString
            }
            .compactMap { state in
                guard let card = cardsByID[state.cardID], let word = wordsByID[card.wordID] else {
                    return nil
                }
                return DueReviewItem(word: word, card: card, state: state)
            }
            .prefix(limit)
            .map { $0 }
    }

    public func apply(rating: ReviewRating, to cardID: UUID, now: Date) throws {
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
        guard let state = states.first(where: { $0.cardID == cardID }) else {
            throw ReviewSessionError.missingReviewState(cardID)
        }

        let snapshot = ReviewSnapshot(
            box: state.box,
            dueAt: state.dueAt,
            lapses: state.lapses,
            lastReviewedAt: state.lastReviewedAt,
            easeHint: state.easeHint
        )
        let update = scheduler.update(from: snapshot, rating: rating, now: now)

        state.box = update.nextBox
        state.dueAt = update.nextDueAt
        state.lapses = update.lapses
        state.lastReviewedAt = update.reviewedAt
        state.easeHint = update.easeHint

        context.insert(ReviewLogRecord(
            id: UUID(),
            cardID: cardID,
            ratingRaw: rating.rawValue,
            reviewedAt: update.reviewedAt,
            previousBox: update.previousBox,
            nextBox: update.nextBox,
            previousDueAt: update.previousDueAt,
            nextDueAt: update.nextDueAt
        ))
        try context.save()
    }
}

public enum ReviewSessionError: Error, Equatable {
    case missingReviewState(UUID)
}
