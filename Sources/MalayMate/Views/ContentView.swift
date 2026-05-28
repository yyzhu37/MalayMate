import SwiftUI

struct ContentView: View {
    enum Selection: Hashable {
        case review
        case library(deckID: String?)
        case addWord
        case settings
    }

    @State private var selection: Selection = .review

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .review:
                ReviewView()
            case .library(let deckID):
                LibraryView(selectedDeckID: deckID)
            case .addWord:
                AddWordView()
            case .settings:
                SettingsView()
            }
        }
    }
}
