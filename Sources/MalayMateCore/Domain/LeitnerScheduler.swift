import Foundation

public struct LeitnerScheduler: Sendable {
    public static let maximumBox = 10
    public static let defaultEase = 2.5
    public static let minimumEase = 1.3
    public static let relearnInterval: TimeInterval = 10 * 60
    public static let maximumInterval: TimeInterval = 365 * 24 * 60 * 60

    public init() {}

    public func initialState(now: Date) -> ReviewSnapshot {
        ReviewSnapshot(box: 1, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: Self.defaultEase)
    }

    public func update(from snapshot: ReviewSnapshot, rating: ReviewRating, now: Date) -> ReviewUpdate {
        let nextBox: Int
        let lapses: Int
        let easeHint: Double
        let interval: TimeInterval
        let currentBox = min(Self.maximumBox, max(1, snapshot.box))
        let currentEase = max(Self.minimumEase, snapshot.easeHint > 0 ? snapshot.easeHint : Self.defaultEase)

        switch rating {
        case .again:
            nextBox = 1
            lapses = snapshot.lapses + 1
            easeHint = max(Self.minimumEase, currentEase - 0.20)
            interval = Self.relearnInterval
        case .good:
            nextBox = min(Self.maximumBox, currentBox + 1)
            lapses = snapshot.lapses
            easeHint = currentEase
            interval = Self.interval(forStage: nextBox, ease: easeHint, rating: rating)
        case .easy:
            nextBox = min(Self.maximumBox, currentBox + 2)
            lapses = snapshot.lapses
            easeHint = min(3.0, currentEase + 0.15)
            interval = Self.interval(forStage: nextBox, ease: easeHint, rating: rating)
        }

        return ReviewUpdate(
            rating: rating,
            reviewedAt: now,
            previousBox: snapshot.box,
            nextBox: nextBox,
            previousDueAt: snapshot.dueAt,
            nextDueAt: now.addingTimeInterval(interval),
            lapses: lapses,
            easeHint: easeHint
        )
    }

    private static func interval(forStage stage: Int, ease: Double, rating: ReviewRating) -> TimeInterval {
        let days: Double
        switch stage {
        case ...1:
            return relearnInterval
        case 2:
            days = 1
        case 3:
            days = 6
        default:
            days = 6 * pow(ease, Double(stage - 3))
        }

        let multiplier = rating == .easy ? 1.3 : 1.0
        return min(maximumInterval, days * multiplier * 24 * 60 * 60)
    }
}
