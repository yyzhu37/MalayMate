import MalayMateCore
import SwiftData
import SwiftUI

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var dueItems: [DueReviewItem] = []
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    @State private var answerText = ""
    @State private var spellingEvaluation: SpellingEvaluation?
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
                    if let spellingEvaluation {
                        Label(spellingResultText(for: spellingEvaluation), systemImage: spellingResultIcon(for: spellingEvaluation))
                            .font(.callout.weight(.medium))
                            .foregroundStyle(spellingResultStyle(for: spellingEvaluation))
                    }
                    if !item.word.pronunciationNotes.isEmpty {
                        Text(item.word.pronunciationNotes)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if isSpellingPractice(item) {
                spellingInput(for: item)
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

                if isSpellingPractice(item) {
                    Button {
                        checkSpelling(for: item)
                    } label: {
                        Label("Check", systemImage: "checkmark.circle")
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnswerRevealed)
                }

                Button {
                    playAudio(for: item)
                } label: {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
                .disabled(!canPlayAudio(for: item))
                .help(audioHelpText(for: item))

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

    private func audioHelpText(for item: DueReviewItem) -> String {
        guard speechService.canSpeakMalay else {
            return "No Malay system voice available"
        }
        guard canPlayVisibleMalayAudio(for: item) else {
            return "Reveal the answer before playing Malay audio."
        }
        if let voice = speechService.availableMalayVoice {
            return "Malay voice: \(voice.name) (\(voice.language))"
        }
        return "Malay audio is available"
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
            resetAnswerState()
            statusMessage = dueItems.isEmpty ? "All caught up." : nil
        } catch {
            statusMessage = "Could not load reviews: \(error.localizedDescription)"
        }
    }

    private func revealAnswer() {
        isAnswerRevealed = true
        statusMessage = nil
    }

    private func resetAnswerState() {
        isAnswerRevealed = false
        answerText = ""
        spellingEvaluation = nil
    }

    private func canPlayAudio(for item: DueReviewItem) -> Bool {
        speechService.canSpeakMalay && canPlayVisibleMalayAudio(for: item)
    }

    private func canPlayVisibleMalayAudio(for item: DueReviewItem) -> Bool {
        CardDirection(rawValue: item.card.directionRaw) == .malayToChinese || isAnswerRevealed
    }

    private func audioText(for item: DueReviewItem) -> String {
        CardDirection(rawValue: item.card.directionRaw) == .malayToChinese ? item.card.prompt : item.card.answer
    }

    private func playAudio(for item: DueReviewItem) {
        guard canPlayVisibleMalayAudio(for: item) else {
            statusMessage = "Reveal the answer before playing Malay audio."
            return
        }
        speak(audioText(for: item))
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

    private func isSpellingPractice(_ item: DueReviewItem) -> Bool {
        CardDirection(rawValue: item.card.directionRaw) == .chineseToMalay
    }

    private func spellingInput(for item: DueReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("输入马来语拼写")
                .font(.headline)
            TextField("Malay answer", text: $answerText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
                .onSubmit {
                    checkSpelling(for: item)
                }
            Text("Check 后再自己评分。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func checkSpelling(for item: DueReviewItem) {
        let evaluation = SpellingEvaluator.evaluate(answer: answerText, expected: item.card.answer)
        spellingEvaluation = evaluation
        isAnswerRevealed = true
        statusMessage = spellingResultText(for: evaluation)
    }

    private func spellingResultText(for evaluation: SpellingEvaluation) -> String {
        switch evaluation.result {
        case .correct:
            return "拼写正确"
        case .close:
            return "接近，差 \(evaluation.distance) 处"
        case .incorrect:
            return "拼写不对，先看正确答案"
        }
    }

    private func spellingResultIcon(for evaluation: SpellingEvaluation) -> String {
        switch evaluation.result {
        case .correct:
            return "checkmark.circle"
        case .close:
            return "exclamationmark.circle"
        case .incorrect:
            return "xmark.circle"
        }
    }

    private func spellingResultStyle(for evaluation: SpellingEvaluation) -> Color {
        switch evaluation.result {
        case .correct:
            return .green
        case .close:
            return .orange
        case .incorrect:
            return .red
        }
    }

    private func apply(_ rating: ReviewRating) {
        guard let currentItem else {
            return
        }

        do {
            let update = try ReviewSession(context: modelContext).apply(rating: rating, to: currentItem.card.id, now: .now)
            let nextReviewMessage = "下次复习：\(update.nextDueAt.formatted(date: .abbreviated, time: .shortened))"
            dueItems.remove(at: currentIndex)
            if dueItems.isEmpty {
                refresh()
                statusMessage = nextReviewMessage
            } else if currentIndex >= dueItems.count {
                currentIndex = max(dueItems.count - 1, 0)
                resetAnswerState()
                statusMessage = nextReviewMessage
            } else {
                resetAnswerState()
                statusMessage = nextReviewMessage
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
