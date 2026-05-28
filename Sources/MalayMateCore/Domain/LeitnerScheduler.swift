import Foundation

public struct LeitnerScheduler: Sendable {
    public static let maximumBox = 6
    private static let fallbackInterval: TimeInterval = 10 * 60

    private let intervals: [Int: TimeInterval]

    public init(intervals: [Int: TimeInterval] = LeitnerScheduler.defaultIntervals) {
        self.intervals = intervals
    }

    public static let defaultIntervals: [Int: TimeInterval] = [
        1: 10 * 60,
        2: 24 * 60 * 60,
        3: 3 * 24 * 60 * 60,
        4: 7 * 24 * 60 * 60,
        5: 14 * 24 * 60 * 60,
        6: 30 * 24 * 60 * 60
    ]

    public func initialState(now: Date) -> ReviewSnapshot {
        ReviewSnapshot(box: 1, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0)
    }

    public func update(from snapshot: ReviewSnapshot, rating: ReviewRating, now: Date) -> ReviewUpdate {
        let nextBox: Int
        let lapses: Int

        switch rating {
        case .again:
            nextBox = 1
            lapses = snapshot.lapses + 1
        case .good:
            nextBox = min(Self.maximumBox, max(1, snapshot.box + 1))
            lapses = snapshot.lapses
        case .easy:
            nextBox = min(Self.maximumBox, max(1, snapshot.box + 2))
            lapses = snapshot.lapses
        }

        let interval = intervals[nextBox] ?? Self.defaultIntervals[nextBox] ?? Self.fallbackInterval
        return ReviewUpdate(
            rating: rating,
            reviewedAt: now,
            previousBox: snapshot.box,
            nextBox: nextBox,
            previousDueAt: snapshot.dueAt,
            nextDueAt: now.addingTimeInterval(interval),
            lapses: lapses,
            easeHint: snapshot.easeHint
        )
    }
}
