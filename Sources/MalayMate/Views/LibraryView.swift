import MalayMateCore
import SwiftData
import SwiftUI

struct LibraryView: View {
    let selectedDeckID: String?
    private let pageSize = 100

    @Query(sort: \DeckRecord.name) private var decks: [DeckRecord]
    @Query(sort: \WordRecord.term) private var words: [WordRecord]
    @State private var searchText = ""
    @State private var statusFilter = VocabularyLibraryStatusFilter.all
    @State private var sort = VocabularyLibrarySort.deckOrder
    @State private var visibleLimit = 100

    private var browseResult: VocabularyLibraryBrowseResult {
        VocabularyLibrary.browseSections(
            decks: decks,
            words: words,
            selectedDeckID: selectedDeckID,
            query: VocabularyLibraryQuery(
                searchText: searchText,
                statusFilter: statusFilter,
                sort: sort,
                visibleLimit: visibleLimit
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            controls

            if browseResult.sections.isEmpty {
                ContentUnavailableView(
                    "没有词条",
                    systemImage: "books.vertical",
                    description: Text(searchText.isEmpty ? "Add a word or import a starter deck." : "换一个搜索词或筛选条件。")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(browseResult.sections) { section in
                            deckSection(section)
                        }

                        if browseResult.hasMore {
                            Button {
                                visibleLimit += pageSize
                            } label: {
                                Label("显示更多", systemImage: "chevron.down")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Library")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedDeckID == nil ? "词库" : (browseResult.sections.first?.name ?? selectedDeckName ?? "词库"))
                .font(.largeTitle.weight(.semibold))
            Text("\(browseResult.sections.count) 个词库 · 显示 \(browseResult.visibleCount) / \(browseResult.totalMatches) 个词")
                .foregroundStyle(.secondary)
        }
    }

    private var selectedDeckName: String? {
        guard let selectedDeckID else {
            return nil
        }
        return decks.first { $0.id == selectedDeckID }?.name
    }

    private var controls: some View {
        HStack(spacing: 12) {
            TextField("搜索词、中文、词性或发音", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .onChange(of: searchText) { _, _ in resetVisibleLimit() }

            Picker("Status", selection: $statusFilter) {
                ForEach(VocabularyLibraryStatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 310)
            .onChange(of: statusFilter) { _, _ in resetVisibleLimit() }

            Picker("Sort", selection: $sort) {
                ForEach(VocabularyLibrarySort.allCases) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .onChange(of: sort) { _, _ in resetVisibleLimit() }

            Spacer()
        }
        .frame(maxWidth: 820, alignment: .leading)
    }

    private func deckSection(_ section: VocabularyLibrarySection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(section.name, systemImage: section.isStarter ? "sparkles" : "person.crop.circle")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(section.words.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if !section.description.isEmpty {
                Text(section.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(section.words) { word in
                    LibraryWordRow(word: word)
                    if word.id != section.words.last?.id {
                        Divider()
                    }
                }
            }
            .background(.background)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
        }
    }

    private func resetVisibleLimit() {
        visibleLimit = pageSize
    }
}

private struct LibraryWordRow: View {
    let word: WordRecord

    private var examples: [SeedExample] {
        VocabularyLibrary.examples(for: word)
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                if examples.isEmpty {
                    Text("No examples")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(examples) { example in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.malay)
                                .textSelection(.enabled)
                            Text(example.chinese)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .font(.callout)
            .padding(.top, 8)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.term)
                        .font(.headline)
                        .textSelection(.enabled)
                    Text(word.chineseMeaning)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if !word.partOfSpeech.isEmpty {
                        Text(word.partOfSpeech)
                    }
                    if !word.pronunciationNotes.isEmpty {
                        Text(word.pronunciationNotes)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 14)
    }
}

private extension VocabularyLibraryStatusFilter {
    var title: String {
        switch self {
        case .all:
            return "全部"
        case .new:
            return "新词"
        case .inReview:
            return "复习中"
        case .mastered:
            return "已掌握"
        }
    }
}

private extension VocabularyLibrarySort {
    var title: String {
        switch self {
        case .deckOrder:
            return "词库顺序"
        case .term:
            return "字母"
        case .status:
            return "状态"
        case .createdNewest:
            return "新添加"
        }
    }
}
