import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Section("Today") {
                    Label("Review", systemImage: "rectangle.stack")
                    Label("Add Word", systemImage: "plus.circle")
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .navigationTitle("MalayMate")
        } detail: {
            VStack(spacing: 16) {
                Text("MalayMate")
                    .font(.largeTitle.weight(.semibold))
                Text("Review-first Malay vocabulary practice")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
