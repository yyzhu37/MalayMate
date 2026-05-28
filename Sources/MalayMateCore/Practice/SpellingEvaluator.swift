import Foundation

public enum SpellingResult: Equatable, Sendable {
    case correct
    case close
    case incorrect
}

public struct SpellingEvaluation: Equatable, Sendable {
    public let result: SpellingResult
    public let normalizedAnswer: String
    public let normalizedExpected: String
    public let distance: Int

    public init(result: SpellingResult, normalizedAnswer: String, normalizedExpected: String, distance: Int) {
        self.result = result
        self.normalizedAnswer = normalizedAnswer
        self.normalizedExpected = normalizedExpected
        self.distance = distance
    }
}

public enum SpellingEvaluator {
    public static func evaluate(answer: String, expected: String) -> SpellingEvaluation {
        let normalizedAnswer = normalize(answer)
        let normalizedExpected = normalize(expected)
        let distance = editDistance(normalizedAnswer, normalizedExpected)
        let result: SpellingResult

        if normalizedAnswer == normalizedExpected {
            result = .correct
        } else if !normalizedAnswer.isEmpty && distance <= closeMatchThreshold(for: normalizedExpected) {
            result = .close
        } else {
            result = .incorrect
        }

        return SpellingEvaluation(
            result: result,
            normalizedAnswer: normalizedAnswer,
            normalizedExpected: normalizedExpected,
            distance: distance
        )
    }

    public static func normalize(_ value: String) -> String {
        let folded = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ms_MY"))
            .lowercased()
        var scalars: [UnicodeScalar] = []
        var lastWasSpace = true

        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                scalars.append(scalar)
                lastWasSpace = false
            } else if CharacterSet.whitespacesAndNewlines.contains(scalar), !lastWasSpace {
                scalars.append(" ")
                lastWasSpace = true
            }
        }

        while scalars.last == " " {
            scalars.removeLast()
        }

        return String(String.UnicodeScalarView(scalars))
    }

    private static func closeMatchThreshold(for expected: String) -> Int {
        expected.count <= 5 ? 1 : 2
    }

    private static func editDistance(_ left: String, _ right: String) -> Int {
        let leftCharacters = Array(left)
        let rightCharacters = Array(right)
        guard !leftCharacters.isEmpty else {
            return rightCharacters.count
        }
        guard !rightCharacters.isEmpty else {
            return leftCharacters.count
        }

        var previous = Array(0...rightCharacters.count)
        var current = Array(repeating: 0, count: rightCharacters.count + 1)

        for leftIndex in 1...leftCharacters.count {
            current[0] = leftIndex
            for rightIndex in 1...rightCharacters.count {
                if leftCharacters[leftIndex - 1] == rightCharacters[rightIndex - 1] {
                    current[rightIndex] = previous[rightIndex - 1]
                } else {
                    current[rightIndex] = min(
                        previous[rightIndex] + 1,
                        current[rightIndex - 1] + 1,
                        previous[rightIndex - 1] + 1
                    )
                }
            }
            previous = current
        }

        return previous[rightCharacters.count]
    }
}
