import Foundation
import SwiftData

@Model
public final class DeckRecord {
    @Attribute(.unique) public var id: String
    public var name: String
    public var deckDescription: String
    public var isStarter: Bool
    public var wordIDsJSON: String
    public var createdAt: Date

    public init(id: String, name: String, deckDescription: String, isStarter: Bool, wordIDsJSON: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.deckDescription = deckDescription
        self.isStarter = isStarter
        self.wordIDsJSON = wordIDsJSON
        self.createdAt = createdAt
    }
}

@Model
public final class WordRecord {
    @Attribute(.unique) public var id: UUID
    public var term: String
    public var languageCode: String
    public var chineseMeaning: String
    public var partOfSpeech: String
    public var pronunciationNotes: String
    public var syllablesJSON: String
    public var examplesJSON: String
    public var sourceRefsJSON: String
    public var reviewStatus: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, term: String, languageCode: String, chineseMeaning: String, partOfSpeech: String, pronunciationNotes: String, syllablesJSON: String, examplesJSON: String, sourceRefsJSON: String, reviewStatus: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.term = term
        self.languageCode = languageCode
        self.chineseMeaning = chineseMeaning
        self.partOfSpeech = partOfSpeech
        self.pronunciationNotes = pronunciationNotes
        self.syllablesJSON = syllablesJSON
        self.examplesJSON = examplesJSON
        self.sourceRefsJSON = sourceRefsJSON
        self.reviewStatus = reviewStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class CardRecord {
    @Attribute(.unique) public var id: UUID
    public var wordID: UUID
    public var directionRaw: String
    public var prompt: String
    public var answer: String
    public var hint: String
    public var createdAt: Date

    public init(id: UUID, wordID: UUID, directionRaw: String, prompt: String, answer: String, hint: String, createdAt: Date) {
        self.id = id
        self.wordID = wordID
        self.directionRaw = directionRaw
        self.prompt = prompt
        self.answer = answer
        self.hint = hint
        self.createdAt = createdAt
    }
}

@Model
public final class ReviewStateRecord {
    @Attribute(.unique) public var cardID: UUID
    public var box: Int
    public var dueAt: Date
    public var lapses: Int
    public var lastReviewedAt: Date?
    public var easeHint: Double

    public init(cardID: UUID, box: Int, dueAt: Date, lapses: Int, lastReviewedAt: Date?, easeHint: Double) {
        self.cardID = cardID
        self.box = box
        self.dueAt = dueAt
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
        self.easeHint = easeHint
    }
}

@Model
public final class ReviewLogRecord {
    @Attribute(.unique) public var id: UUID
    public var cardID: UUID
    public var ratingRaw: String
    public var reviewedAt: Date
    public var previousBox: Int
    public var nextBox: Int
    public var previousDueAt: Date
    public var nextDueAt: Date

    public init(id: UUID, cardID: UUID, ratingRaw: String, reviewedAt: Date, previousBox: Int, nextBox: Int, previousDueAt: Date, nextDueAt: Date) {
        self.id = id
        self.cardID = cardID
        self.ratingRaw = ratingRaw
        self.reviewedAt = reviewedAt
        self.previousBox = previousBox
        self.nextBox = nextBox
        self.previousDueAt = previousDueAt
        self.nextDueAt = nextDueAt
    }
}
