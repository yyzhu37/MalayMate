import XCTest
@testable import MalayMateCore

@MainActor
final class SpeechServiceTests: XCTestCase {
    func testMalayVoiceSelectionPrefersMsMY() {
        let voices = [
            SpeechVoice(identifier: "com.apple.voice.compact.en-US.Samantha", name: "Samantha", language: "en_US"),
            SpeechVoice(identifier: "com.apple.voice.compact.ms-MY.Amira", name: "Amira", language: "ms_MY")
        ]

        let voice = SpeechService.chooseMalayVoice(from: voices)

        XCTAssertEqual(voice?.name, "Amira")
    }

    func testMalayVoiceSelectionFallsBackToAnyMalayVoice() {
        let voices = [
            SpeechVoice(identifier: "id", name: "Damayanti", language: "id_ID"),
            SpeechVoice(identifier: "ms", name: "Malay", language: "ms")
        ]

        let voice = SpeechService.chooseMalayVoice(from: voices)

        XCTAssertEqual(voice?.identifier, "ms")
    }
}
