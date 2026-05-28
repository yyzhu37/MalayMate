import XCTest
@testable import MalayMateCore

final class SettingsStoreTests: XCTestCase {
    func testSettingsReportsMissingKeyAndDefaultModel() throws {
        let keychain = InMemorySecretStore()
        let store = SettingsStore(secretStore: keychain)

        XCTAssertFalse(try store.hasAPIKey())
        XCTAssertEqual(store.modelName, "gpt-5.4-mini")
    }

    func testSettingsStoresAndClearsAPIKey() throws {
        let keychain = InMemorySecretStore()
        let store = SettingsStore(secretStore: keychain)

        try store.saveAPIKey("sk-test")
        XCTAssertTrue(try store.hasAPIKey())
        XCTAssertEqual(try keychain.read(service: SettingsStore.keychainService, account: SettingsStore.apiKeyAccount), "sk-test")

        try store.clearAPIKey()
        XCTAssertFalse(try store.hasAPIKey())
    }
}
