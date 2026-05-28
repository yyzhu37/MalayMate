import MalayMateCore
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: ContentView.Selection

    @Query(sort: \DeckRecord.name) private var decks: [DeckRecord]
    @Query private var reviewStates: [ReviewStateRecord]
    @State private var now = Date.now

    private var dueCount: Int {
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

                NavigationLink(value: ContentView.Selection.library(deckID: nil)) {
                    Label("Library", systemImage: "books.vertical")
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
                        NavigationLink(value: ContentView.Selection.library(deckID: deck.id)) {
                            Label(deck.name, systemImage: deck.isStarter ? "sparkles" : "person.crop.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle("MalayMate")
        .task {
            await updateNowPeriodically()
        }
    }

    private func updateNowPeriodically() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else {
                return
            }
            now = .now
        }
    }
}
