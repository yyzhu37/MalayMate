import Foundation

public protocol SecretStore {
    func save(_ value: String, service: String, account: String) throws
    func read(service: String, account: String) throws -> String?
    func delete(service: String, account: String) throws
}

public final class SettingsStore {
    public static let keychainService = "local.zhuyingtao.MalayMate"
    public static let apiKeyAccount = "openai-api-key"

    private let secretStore: SecretStore
    public var modelName: String

    public init(secretStore: SecretStore, modelName: String = "gpt-5.4-mini") {
        self.secretStore = secretStore
        self.modelName = modelName
    }

    public func saveAPIKey(_ key: String) throws {
        try secretStore.save(key, service: Self.keychainService, account: Self.apiKeyAccount)
    }

    public func hasAPIKey() throws -> Bool {
        try secretStore.read(service: Self.keychainService, account: Self.apiKeyAccount)?.isEmpty == false
    }

    public func apiKey() throws -> String? {
        try secretStore.read(service: Self.keychainService, account: Self.apiKeyAccount)
    }

    public func clearAPIKey() throws {
        try secretStore.delete(service: Self.keychainService, account: Self.apiKeyAccount)
    }
}

public final class InMemorySecretStore: SecretStore {
    private var values: [String: String] = [:]

    public init() {}

    public func save(_ value: String, service: String, account: String) throws {
        values["\(service):\(account)"] = value
    }

    public func read(service: String, account: String) throws -> String? {
        values["\(service):\(account)"]
    }

    public func delete(service: String, account: String) throws {
        values.removeValue(forKey: "\(service):\(account)")
    }
}
