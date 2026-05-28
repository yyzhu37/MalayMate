import Foundation

public struct ReviewSnapshot: Equatable, Sendable {
    public let box: Int
    public let dueAt: Date
    public let lapses: Int
    public let lastReviewedAt: Date?
    public let easeHint: Double

    public init(box: Int, dueAt: Date, lapses: Int, lastReviewedAt: Date?, easeHint: Double) {
        self.box = box
        self.dueAt = dueAt
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
        self.easeHint = easeHint
    }
}

public struct ReviewUpdate: Equatable, Sendable {
    public let rating: ReviewRating
    public let reviewedAt: Date
    public let previousBox: Int
    public let nextBox: Int
    public let previousDueAt: Date
    public let nextDueAt: Date
    public let lapses: Int
    public let easeHint: Double

    public init(
        rating: ReviewRating,
        reviewedAt: Date,
        previousBox: Int,
        nextBox: Int,
        previousDueAt: Date,
        nextDueAt: Date,
        lapses: Int,
        easeHint: Double
    ) {
        self.rating = rating
        self.reviewedAt = reviewedAt
        self.previousBox = previousBox
        self.nextBox = nextBox
        self.previousDueAt = previousDueAt
        self.nextDueAt = nextDueAt
        self.lapses = lapses
        self.easeHint = easeHint
    }
}
