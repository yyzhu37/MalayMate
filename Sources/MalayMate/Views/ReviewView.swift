import MalayMateCore
import SwiftData
import SwiftUI

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var dueItems: [DueReviewItem] = []
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    @State private var statusMessage: String?
    @State private var speechService = SpeechService()

    private var currentItem: DueReviewItem? {
        guard dueItems.indices.contains(currentIndex) else {
            return nil
        }
        return dueItems[currentIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            if let currentItem {
                reviewCard(for: currentItem)
            } else {
                ContentUnavailableView(
                    "今天没有待复习",
                    systemImage: "checkmark.circle",
                    description: Text("Add a word or come back when cards are due.")
                )
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Review")
        .task {
            refresh()
            await refreshPeriodically()
        }
        .toolbar {
            Button {
                refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Review")
                .font(.largeTitle.weight(.semibold))
            Text("\(dueItems.count) loaded due cards")
                .foregroundStyle(.secondary)
        }
    }

    private func reviewCard(for item: DueReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(directionTitle(for: item.card.directionRaw))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(item.card.prompt)
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .textSelection(.enabled)
                if !item.card.hint.isEmpty {
                    Text(item.card.hint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if isAnswerRevealed {
                VStack(alignment: .leading, spacing: 10) {
                    Text("答案")
                        .font(.headline)
                    Text(item.card.answer)
                        .font(.title2.weight(.medium))
                        .textSelection(.enabled)
                    if !item.word.pronunciationNotes.isEmpty {
                        Text(item.word.pronunciationNotes)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("先想答案，再点击 Reveal。")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    revealAnswer()
                } label: {
                    Label("Reveal", systemImage: "eye")
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(isAnswerRevealed)

                Button {
                    speak(item.word.term)
                } label: {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
                .disabled(!speechService.canSpeakMalay)
                .help(audioHelpText)

                Spacer()

                ratingButton("Again", systemImage: "arrow.counterclockwise", rating: .again)
                ratingButton("Good", systemImage: "checkmark", rating: .good)
                ratingButton("Easy", systemImage: "sparkles", rating: .easy)
            }
        }
        .padding(24)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }

    private var audioHelpText: String {
        if let voice = speechService.availableMalayVoice {
            return "Malay voice: \(voice.name) (\(voice.language))"
        }
        return "No Malay system voice available"
    }

    private func ratingButton(_ title: String, systemImage: String, rating: ReviewRating) -> some View {
        Button {
            apply(rating)
        } label: {
            Label(title, systemImage: systemImage)
        }
        .disabled(!isAnswerRevealed)
    }

    private func refresh() {
        do {
            dueItems = try ReviewSession(context: modelContext).dueCards(now: .now)
            currentIndex = 0
            isAnswerRevealed = false
            statusMessage = dueItems.isEmpty ? "All caught up." : nil
        } catch {
            statusMessage = "Could not load reviews: \(error.localizedDescription)"
        }
    }

    private func revealAnswer() {
        isAnswerRevealed = true
        statusMessage = nil
    }

    private func speak(_ text: String) {
        guard speechService.canSpeakMalay else {
            statusMessage = "No Malay system voice available. Audio is disabled."
            return
        }
        if !speechService.speak(text) {
            statusMessage = "No Malay system voice available. Audio was not played."
        }
    }

    private func apply(_ rating: ReviewRating) {
        guard let currentItem else {
            return
        }

        do {
            try ReviewSession(context: modelContext).apply(rating: rating, to: currentItem.card.id, now: .now)
            dueItems.remove(at: currentIndex)
            if dueItems.isEmpty {
                refresh()
            } else if currentIndex >= dueItems.count {
                currentIndex = max(dueItems.count - 1, 0)
                isAnswerRevealed = false
                statusMessage = nil
            } else {
                isAnswerRevealed = false
                statusMessage = nil
            }
        } catch {
            statusMessage = "Could not save review: \(error.localizedDescription)"
        }
    }

    private func refreshPeriodically() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else {
                return
            }
            if currentItem == nil {
                refresh()
            }
        }
    }

    private func directionTitle(for rawValue: String) -> String {
        switch CardDirection(rawValue: rawValue) {
        case .malayToChinese:
            return "Malay -> Chinese"
        case .chineseToMalay:
            return "Chinese -> Malay"
        case nil:
            return "Review"
        }
    }
}
