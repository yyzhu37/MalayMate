import Foundation

public struct OpenAIClient: AIProvider {
    public var apiKey: String
    public var model: String
    public var urlSession: URLSession

    public init(apiKey: String, model: String = "gpt-5.4-mini", urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.urlSession = urlSession
    }

    public func enrich(term: String, userMeaning: String, note: String?) async throws -> AIEnrichment {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(term: term, userMeaning: userMeaning, note: note))

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenAIClientError.badHTTPResponse
        }
        return try Self.parseEnrichmentResponse(data: data)
    }

    public func requestBody(term: String, userMeaning: String, note: String?) -> [String: Any] {
        [
            "model": model,
            "input": [
                [
                    "role": "system",
                    "content": "Return strict JSON for a Malay vocabulary learning card for a Chinese-speaking learner. Keep Malay examples simple and natural."
                ],
                [
                    "role": "user",
                    "content": "Malay term: \(term)\nKnown Chinese meaning: \(userMeaning)\nUser note: \(note ?? "")"
                ]
            ],
            "max_output_tokens": 800,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "malay_vocab_enrichment",
                    "strict": true,
                    "schema": enrichmentSchema
                ]
            ]
        ]
    }

    public static func parseEnrichmentResponse(data: Data) throws -> AIEnrichment {
        let response = try JSONDecoder().decode(ResponsesEnvelope.self, from: data)
        let outputText = response.outputText.flatMap { $0.isEmpty ? nil : $0 }
        let contentText = response.output?
            .flatMap { $0.content ?? [] }
            .compactMap { $0.text }
            .first { !$0.isEmpty }

        guard let text = outputText ?? contentText else {
            throw OpenAIClientError.missingOutputText
        }
        let payload = Data(text.utf8)
        return try JSONDecoder.seedDecoder.decode(AIEnrichment.self, from: payload)
    }

    private var enrichmentSchema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "chineseMeaning": ["type": "string"],
                "partOfSpeech": ["type": "string"],
                "pronunciationNotes": ["type": "string"],
                "syllables": ["type": "array", "items": ["type": "string"]],
                "examples": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "id": ["type": "string"],
                            "malay": ["type": "string"],
                            "chinese": ["type": "string"],
                            "sourceRefs": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "additionalProperties": false,
                                    "properties": [
                                        "field": ["type": "string"],
                                        "sourceName": ["type": "string"],
                                        "sourceUrl": ["type": "string"],
                                        "license": ["type": "string"],
                                        "attribution": ["type": "string"],
                                        "retrievedAt": ["type": "string"],
                                        "reviewStatus": ["type": "string"]
                                    ],
                                    "required": [
                                        "field",
                                        "sourceName",
                                        "sourceUrl",
                                        "license",
                                        "attribution",
                                        "retrievedAt",
                                        "reviewStatus"
                                    ]
                                ]
                            ]
                        ],
                        "required": ["id", "malay", "chinese", "sourceRefs"]
                    ]
                ],
                "practicePrompts": ["type": "array", "items": ["type": "string"]]
            ],
            "required": ["chineseMeaning", "partOfSpeech", "pronunciationNotes", "syllables", "examples", "practicePrompts"]
        ]
    }
}

private struct ResponsesEnvelope: Decodable {
    var outputText: String?
    var output: [ResponsesOutputItem]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

private struct ResponsesOutputItem: Decodable {
    var content: [ResponsesContentItem]?
}

private struct ResponsesContentItem: Decodable {
    var text: String?
}

public enum OpenAIClientError: Error, Equatable {
    case badHTTPResponse
    case missingOutputText
}
