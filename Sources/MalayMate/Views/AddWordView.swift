import MalayMateCore
import SwiftData
import SwiftUI

struct AddWordView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("openaiModelName") private var modelName = "gpt-5.4-mini"

    @State private var term = ""
    @State private var chineseMeaning = ""
    @State private var note = ""
    @State private var isSaving = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section("New Word") {
                TextField("Malay word", text: $term)
                    .disabled(isSaving)
                TextField("中文意思", text: $chineseMeaning)
                    .disabled(isSaving)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .disabled(isSaving)
            }

            Section {
                Button {
                    save()
                } label: {
                    Label(isSaving ? "Saving..." : "Save", systemImage: "plus.circle")
                }
                .disabled(isSaving || term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let statusMessage {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .navigationTitle("Add Word")
    }

    private func save() {
        let submittedTerm = term
        let submittedMeaning = chineseMeaning
        let submittedNote = note
        let trimmedSubmittedNote = submittedNote.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true
        statusMessage = nil

        Task { @MainActor in
            do {
                let settings = SettingsStore(secretStore: KeychainStore(), modelName: modelName)
                let apiKey = try settings.apiKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
                let provider: AIProvider? = if let apiKey, !apiKey.isEmpty {
                    OpenAIClient(apiKey: apiKey, model: settings.modelName)
                } else {
                    nil
                }
                let service = AddWordService(context: modelContext, aiProvider: provider)
                let wordID = try await service.addWord(
                    term: submittedTerm,
                    userMeaning: submittedMeaning,
                    note: trimmedSubmittedNote.isEmpty ? nil : submittedNote
                )
                let savedWord = try modelContext.fetch(FetchDescriptor<WordRecord>())
                    .first { $0.id == wordID }
                term = ""
                chineseMeaning = ""
                note = ""
                statusMessage = statusMessage(for: savedWord?.reviewStatus, usedProvider: provider != nil)
            } catch {
                statusMessage = "Could not save word: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }

    private func statusMessage(for reviewStatus: String?, usedProvider: Bool) -> String {
        switch reviewStatus {
        case "aiGenerated":
            return "Saved with AI enrichment."
        case "needsEnrichment":
            return usedProvider ? "Saved with local template fallback after AI failed." : "Saved with local template fallback."
        default:
            return "Saved."
        }
    }
}
