import XCTest
@testable import MalayMateCore

final class SpellingEvaluatorTests: XCTestCase {
    func testExactMatchIgnoresCaseWhitespaceAndPunctuation() {
        let evaluation = SpellingEvaluator.evaluate(answer: "  Makan! ", expected: "makan")

        XCTAssertEqual(evaluation.result, .correct)
        XCTAssertEqual(evaluation.normalizedAnswer, "makan")
    }

    func testNearMissAllowsSmallTypo() {
        let evaluation = SpellingEvaluator.evaluate(answer: "makn", expected: "makan")

        XCTAssertEqual(evaluation.result, .close)
        XCTAssertEqual(evaluation.distance, 1)
    }

    func testDifferentAnswerIsIncorrect() {
        let evaluation = SpellingEvaluator.evaluate(answer: "minum", expected: "makan")

        XCTAssertEqual(evaluation.result, .incorrect)
    }
}
