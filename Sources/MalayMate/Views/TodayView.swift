import MalayMateCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Binding var selection: ContentView.Selection
    @AppStorage("dailyNewWordLimit") private var dailyLimit = 10

    @Query private var cards: [CardRecord]
    @Query private var words: [WordRecord]
    @Query private var reviewStates: [ReviewStateRecord]
    @State private var now = Date.now

    private var summary: TodaySummary {
        TodaySummary.make(
            words: words,
            cards: cards,
            reviewStates: reviewStates,
            dailyLimit: dailyLimit,
            now: now
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            primaryActions
            metrics
            nextReview
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Today")
        .task {
            await updateNowPeriodically()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.largeTitle.weight(.semibold))
            Text("先学新词，再清复习队列。")
                .foregroundStyle(.secondary)
        }
    }

    private var primaryActions: some View {
        HStack(spacing: 12) {
            Button {
                selection = .learn
            } label: {
                Label("Learn", systemImage: "graduationcap")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(summary.remainingNewWordSlots == 0 || summary.newWordCount == 0)

            Button {
                selection = .review
            } label: {
                Label("Review", systemImage: "rectangle.stack")
            }
            .controlSize(.large)
            .disabled(summary.dueReviewCount == 0)
        }
    }

    private var metrics: some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                metricTile(title: "待复习", value: "\(summary.dueReviewCount)", systemImage: "rectangle.stack")
                metricTile(title: "今日已学", value: "\(summary.learnedTodayCount)", systemImage: "checkmark.circle")
            }
            GridRow {
                metricTile(title: "还可学新词", value: "\(summary.remainingNewWordSlots)", systemImage: "graduationcap")
                metricTile(title: "词库新词", value: "\(summary.newWordCount)", systemImage: "books.vertical")
            }
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func metricTile(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .padding(18)
        .frame(width: 300, height: 104, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }

    @ViewBuilder
    private var nextReview: some View {
        if summary.dueReviewCount > 0 {
            Text("现在可以复习。")
                .foregroundStyle(.secondary)
        } else if let nextDueAt = summary.nextDueAt {
            Text("下一次复习：\(nextDueAt.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.secondary)
        } else {
            Text("还没有已安排的复习。")
                .foregroundStyle(.secondary)
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
