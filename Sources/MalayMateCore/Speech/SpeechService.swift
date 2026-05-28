import AVFoundation

public struct SpeechVoice: Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let language: String

    public init(identifier: String, name: String, language: String) {
        self.identifier = identifier
        self.name = name
        self.language = language
    }
}

@MainActor
public final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public var availableMalayVoice: SpeechVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().map {
            SpeechVoice(identifier: $0.identifier, name: $0.name, language: $0.language)
        }

        return Self.chooseMalayVoice(from: voices)
    }

    public var canSpeakMalay: Bool {
        availableMalayVoice != nil
    }

    @discardableResult
    public func speak(_ text: String) -> Bool {
        guard
            let identifier = availableMalayVoice?.identifier,
            let voice = AVSpeechSynthesisVoice(identifier: identifier)
        else {
            return false
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
        return true
    }

    nonisolated public static func chooseMalayVoice(from voices: [SpeechVoice]) -> SpeechVoice? {
        if let exactMalaysiaMalay = voices.first(where: { $0.language.lowercased().replacingOccurrences(of: "-", with: "_") == "ms_my" }) {
            return exactMalaysiaMalay
        }

        if let anyMalay = voices.first(where: { $0.language.lowercased().hasPrefix("ms") }) {
            return anyMalay
        }

        return voices.first {
            let name = $0.name.lowercased()
            return name.contains("malay") || name.contains("melayu")
        }
    }
}
