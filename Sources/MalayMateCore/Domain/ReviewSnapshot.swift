import Foundation

public struct ReviewSnapshot: Equatable, Sendable {
    public var box: Int
    public var dueAt: Date
    public var lapses: Int
    public var lastReviewedAt: Date?
    public var easeHint: Double

    public init(box: Int, dueAt: Date, lapses: Int, lastReviewedAt: Date?, easeHint: Double) {
        self.box = box
        self.dueAt = dueAt
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
        self.easeHint = easeHint
    }
}

public struct ReviewUpdate: Equatable, Sendable {
    public var rating: ReviewRating
    public var reviewedAt: Date
    public var previousBox: Int
    public var nextBox: Int
    public var previousDueAt: Date
    public var nextDueAt: Date
    public var lapses: Int
    public var easeHint: Double
}
