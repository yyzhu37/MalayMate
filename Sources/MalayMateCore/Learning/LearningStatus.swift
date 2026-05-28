public enum LearningStatus: String, Codable, Equatable, Sendable {
    case new
    case inReview
    case mastered

    public init(word: WordRecord) {
        if let rawValue = word.learningStatusRaw, let status = LearningStatus(rawValue: rawValue) {
            self = status
        } else if word.reviewStatus == "reviewed" {
            self = .new
        } else {
            self = .inReview
        }
    }
}
