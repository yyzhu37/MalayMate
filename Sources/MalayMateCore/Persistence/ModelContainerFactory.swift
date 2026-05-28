import SwiftData

public enum ModelContainerFactory {
    public static var schema: Schema {
        Schema([
            DeckRecord.self,
            WordRecord.self,
            CardRecord.self,
            ReviewStateRecord.self,
            ReviewLogRecord.self
        ])
    }

    @MainActor
    public static func makeAppContainer() throws -> ModelContainer {
        try ModelContainer(for: schema)
    }

    @MainActor
    public static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
