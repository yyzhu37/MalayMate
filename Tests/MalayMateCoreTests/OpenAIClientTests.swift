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

    func testResponseParserSkipsNonMessageOutputItems() throws {
        let json = """
        {
          "output": [
            {
              "type": "reasoning",
              "summary": []
            },
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
        XCTAssertEqual(enrichment.examples.first?.id, "ai-belajar-1")
    }

    func testRequestBodyUsesStrictCompatibleObjectSchemas() throws {
        let client = OpenAIClient(apiKey: "sk-test")
        let body = client.requestBody(term: "belajar", userMeaning: "学习", note: nil)
        let text = try XCTUnwrap(body["text"] as? [String: Any])
        let format = try XCTUnwrap(text["format"] as? [String: Any])
        let schema = try XCTUnwrap(format["schema"] as? [String: Any])

        try assertStrictObjectSchemas(schema)
    }

    private func assertStrictObjectSchemas(_ schema: [String: Any], path: String = "schema") throws {
        if schema["type"] as? String == "object" {
            XCTAssertEqual(schema["additionalProperties"] as? Bool, false, "\(path) must set additionalProperties to false")

            let properties = try XCTUnwrap(schema["properties"] as? [String: Any], "\(path) must define properties")
            let required = try XCTUnwrap(schema["required"] as? [String], "\(path) must define required")
            XCTAssertEqual(Set(required), Set(properties.keys), "\(path) required keys must exactly match properties")

            for (name, value) in properties {
                try assertNestedStrictObjectSchemas(value, path: "\(path).properties.\(name)")
            }
        }

        if let items = schema["items"] {
            try assertNestedStrictObjectSchemas(items, path: "\(path).items")
        }
    }

    private func assertNestedStrictObjectSchemas(_ value: Any, path: String) throws {
        if let nested = value as? [String: Any] {
            try assertStrictObjectSchemas(nested, path: path)
        } else if let values = value as? [Any] {
            for (index, item) in values.enumerated() {
                try assertNestedStrictObjectSchemas(item, path: "\(path)[\(index)]")
            }
        }
    }
}
