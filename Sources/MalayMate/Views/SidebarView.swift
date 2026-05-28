import MalayMateCore
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: ContentView.Selection

    @Query(sort: \DeckRecord.name) private var decks: [DeckRecord]
    @Query private var reviewStates: [ReviewStateRecord]

    private var dueCount: Int {
        let now = Date.now
        return reviewStates.filter { $0.dueAt <= now }.count
    }

    var body: some View {
        List(selection: $selection) {
            Section("Today") {
                NavigationLink(value: ContentView.Selection.review) {
                    Label {
                        HStack {
                            Text("Review")
                            Spacer()
                            Text("\(dueCount)")
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "rectangle.stack")
                    }
                }

                NavigationLink(value: ContentView.Selection.addWord) {
                    Label("Add Word", systemImage: "plus.circle")
                }

                NavigationLink(value: ContentView.Selection.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }

            if !decks.isEmpty {
                Section("Decks") {
                    ForEach(decks) { deck in
                        Label(deck.name, systemImage: deck.isStarter ? "sparkles" : "person.crop.circle")
                    }
                }
            }
        }
        .navigationTitle("MalayMate")
    }
}
