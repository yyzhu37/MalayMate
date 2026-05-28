import MalayMateCore
import SwiftData
import SwiftUI

struct LibraryView: View {
    let selectedDeckID: String?

    @Query(sort: \DeckRecord.name) private var decks: [DeckRecord]
    @Query(sort: \WordRecord.term) private var words: [WordRecord]

    private var sections: [VocabularyLibrarySection] {
        VocabularyLibrary.sections(decks: decks, words: words)
    }

    private var visibleSections: [VocabularyLibrarySection] {
        guard let selectedDeckID else {
            return sections
        }
        return sections.filter { $0.id == selectedDeckID }
    }

    private var wordCount: Int {
        visibleSections.reduce(0) { $0 + $1.words.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if visibleSections.isEmpty {
                ContentUnavailableView(
                    "没有词条",
                    systemImage: "books.vertical",
                    description: Text("Add a word or import a starter deck.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(visibleSections) { section in
                            deckSection(section)
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
            Text(selectedDeckID == nil ? "词库" : (visibleSections.first?.name ?? "词库"))
                .font(.largeTitle.weight(.semibold))
            Text("\(visibleSections.count) decks · \(wordCount) words")
                .foregroundStyle(.secondary)
        }
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
