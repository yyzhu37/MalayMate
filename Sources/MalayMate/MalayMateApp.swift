import MalayMateCore
import SwiftData
import SwiftUI

@main
struct MalayMateApp: App {
    private let container: ModelContainer

    @MainActor
    init() {
        do {
            let container = try ModelContainerFactory.makeAppContainer()
            _ = try SeedImporter().importBundledSeed(into: container.mainContext)
            self.container = container
        } catch {
            fatalError("MalayMate startup failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .frame(minWidth: 980, minHeight: 620)
        }
    }
}
