import MalayMateCore
import SwiftData
import SwiftUI

struct LearnView: View {
    private static let allDecksID = "__all_decks__"

    @Environment(\.modelContext) private var modelContext
    @AppStorage("dailyNewWordLimit") private var dailyLimit = 10

    @Query(sort: \DeckRecord.name) private var decks: [DeckRecord]
    @Query(sort: \WordRecord.createdAt) private var words: [WordRecord]

    @State private var selectedDeckID = LearnView.allDecksID
    @State private var skippedWordIDs: Set<UUID> = []
    @State private var statusMessage: String?
    @State private var speechService = SpeechService()

    private var effectiveDeckID: String? {
        selectedDeckID == Self.allDecksID ? nil : selectedDeckID
    }

    private var plan: LearnPlan {
        LearnSession.plan(
            decks: decks,
            words: words,
            selectedDeckID: effectiveDeckID,
            dailyLimit: dailyLimit,
            now: .now
        )
    }

    private var visibleWords: [WordRecord] {
        plan.words.filter { !skippedWordIDs.contains($0.id) }
    }

    private var currentWord: WordRecord? {
        visibleWords.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            controls

            if let currentWord {
                wordCard(for: currentWord)
            } else {
                emptyState
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Learn")
        .onAppear(perform: clampDailyLimit)
        .onChange(of: selectedDeckID) { _, _ in
            skippedWordIDs.removeAll()
            statusMessage = nil
        }
        .onChange(of: dailyLimit) { _, _ in
            clampDailyLimit()
            skippedWordIDs.removeAll()
            statusMessage = nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Learn")
                .font(.largeTitle.weight(.semibold))
            Text("\(plan.learnedTodayCount) learned today · \(plan.remainingNewWordSlots) new-word slots left")
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 18) {
            Picker("Deck", selection: $selectedDeckID) {
                Text("All decks").tag(Self.allDecksID)
                ForEach(decks) { deck in
                    Text(deck.name).tag(deck.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 240)

            Stepper(value: $dailyLimit, in: 0...100, step: 1) {
                Text("每天 \(dailyLimit) 个新词")
                    .monospacedDigit()
            }
            .frame(width: 190, alignment: .leading)

            Spacer()

            if !skippedWordIDs.isEmpty {
                Button {
                    skippedWordIDs.removeAll()
                    statusMessage = nil
                } label: {
                    Label("显示跳过", systemImage: "arrow.uturn.backward")
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    private func wordCard(for word: WordRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(word.term)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .textSelection(.enabled)

                    HStack(spacing: 8) {
                        if !word.partOfSpeech.isEmpty {
                            Text(word.partOfSpeech)
                        }
                        if !word.pronunciationNotes.isEmpty {
                            Text(word.pronunciationNotes)
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    playAudio(for: word)
                } label: {
                    Label("发音", systemImage: "speaker.wave.2")
                }
                .disabled(!speechService.canSpeakMalay)
                .help(speechService.canSpeakMalay ? "Malay voice: \(speechService.availableMalayVoice?.name ?? "system")" : "No Malay system voice available")
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(word.chineseMeaning)
                    .font(.title2.weight(.medium))
                    .textSelection(.enabled)

                let examples = VocabularyLibrary.examples(for: word)
                if !examples.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(examples.prefix(2)) { example in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(example.malay)
                                    .textSelection(.enabled)
                                Text(example.chinese)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .font(.callout)
                    .padding(.top, 4)
                }
            }

            HStack(spacing: 12) {
                Button {
                    skip(word)
                } label: {
                    Label("跳过", systemImage: "forward")
                }

                Spacer()

                Button {
                    markLearned(word)
                } label: {
                    Label("学会了", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(maxWidth: 760, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            ContentUnavailableView(
                emptyTitle,
                systemImage: emptySystemImage,
                description: Text(emptyDescription)
            )

            if !skippedWordIDs.isEmpty && !plan.words.isEmpty {
                Button {
                    skippedWordIDs.removeAll()
                    statusMessage = nil
                } label: {
                    Label("显示跳过的词", systemImage: "arrow.uturn.backward")
                }
            }
        }
        .frame(maxWidth: 760, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyTitle: String {
        if plan.remainingNewWordSlots == 0 {
            return "今日新词已完成"
        }
        if !skippedWordIDs.isEmpty && !plan.words.isEmpty {
            return "这一组已跳过"
        }
        return "没有可学习的新词"
    }

    private var emptyDescription: String {
        if plan.remainingNewWordSlots == 0 {
            return "到 Review 里复习已经进入队列的词。"
        }
        if !skippedWordIDs.isEmpty && !plan.words.isEmpty {
            return "重新显示跳过的词，或切换词库。"
        }
        return "切换词库，或先导入/添加更多词。"
    }

    private var emptySystemImage: String {
        plan.remainingNewWordSlots == 0 ? "checkmark.circle" : "graduationcap"
    }

    private func markLearned(_ word: WordRecord) {
        do {
            try LearnSession(context: modelContext).markLearned(wordID: word.id, now: .now)
            skippedWordIDs.remove(word.id)
            statusMessage = "\(word.term) 已加入 Review，10 分钟后出现。"
        } catch {
            statusMessage = "Could not save learning progress: \(error.localizedDescription)"
        }
    }

    private func skip(_ word: WordRecord) {
        skippedWordIDs.insert(word.id)
        statusMessage = nil
    }

    private func playAudio(for word: WordRecord) {
        guard speechService.canSpeakMalay else {
            statusMessage = "No Malay system voice available. Audio is disabled."
            return
        }

        if !speechService.speak(word.term) {
            statusMessage = "No Malay system voice available. Audio was not played."
        }
    }

    private func clampDailyLimit() {
        dailyLimit = min(max(dailyLimit, 0), 100)
    }
}
