import XCTest
@testable import MalayMateCore

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

    func testMalayVoiceSelectionPrefersHyphenatedMsMY() {
        let voices = [
            SpeechVoice(identifier: "ms", name: "Malay", language: "ms"),
            SpeechVoice(identifier: "ms-MY", name: "Amira", language: "ms-MY")
        ]

        let voice = SpeechService.chooseMalayVoice(from: voices)

        XCTAssertEqual(voice?.identifier, "ms-MY")
    }

    func testMalayVoiceSelectionFallsBackToMalayName() {
        let voices = [
            SpeechVoice(identifier: "id", name: "Damayanti", language: "id_ID"),
            SpeechVoice(identifier: "melayu", name: "Bahasa Melayu", language: "und"),
            SpeechVoice(identifier: "malay", name: "Malay", language: "und")
        ]

        let voice = SpeechService.chooseMalayVoice(from: voices)

        XCTAssertEqual(voice?.identifier, "melayu")
    }

    func testMalayVoiceSelectionReturnsNilWhenNoMalayMatchExists() {
        let voices = [
            SpeechVoice(identifier: "en", name: "Samantha", language: "en_US"),
            SpeechVoice(identifier: "id", name: "Damayanti", language: "id_ID")
        ]

        let voice = SpeechService.chooseMalayVoice(from: voices)

        XCTAssertNil(voice)
    }
}
