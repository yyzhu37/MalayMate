import SwiftUI

struct ContentView: View {
    enum Selection: Hashable {
        case today
        case review
        case learn
        case library(deckID: String?)
        case addWord
        case settings
    }

    @State private var selection: Selection = .today

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .today:
                TodayView(selection: $selection)
            case .review:
                ReviewView()
            case .learn:
                LearnView()
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
