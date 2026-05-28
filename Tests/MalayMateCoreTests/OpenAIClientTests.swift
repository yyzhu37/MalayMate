import XCTest
@testable import MalayMateCore

final class OpenAIClientTests: XCTestCase {
    func testResponseParserExtractsStructuredEnrichment() throws {
        let json = """
        {
          "output": [
            {
              "type": "message",
              "content": [
                {
                  "type": "output_text",
                  "text": "{\\"chineseMeaning\\":\\"学习\\",\\"partOfSpeech\\":\\"verb\\",\\"pronunciationNotes\\":\\"be-la-jar\\",\\"syllables\\":[\\"be\\",\\"la\\",\\"jar\\"],\\"examples\\":[{\\"id\\":\\"ai-belajar-1\\",\\"malay\\":\\"Saya belajar bahasa Melayu.\\",\\"chinese\\":\\"我学习马来语。\\",\\"sourceRefs\\":[]}],\\"practicePrompts\\":[\\"看到 belajar 时回忆中文意思。\\"]}"
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let enrichment = try OpenAIClient.parseEnrichmentResponse(data: json)

        XCTAssertEqual(enrichment.chineseMeaning, "学习")
        XCTAssertEqual(enrichment.syllables, ["be", "la", "jar"])
        XCTAssertEqual(enrichment.examples.first?.malay, "Saya belajar bahasa Melayu.")
    }
}
