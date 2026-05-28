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
                TextField("中文意思", text: $chineseMeaning)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(3...6)
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
                _ = try await service.addWord(
                    term: term,
                    userMeaning: chineseMeaning,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
                )
                term = ""
                chineseMeaning = ""
                note = ""
                statusMessage = provider == nil ? "Saved with local template fallback." : "Saved with AI enrichment."
            } catch {
                statusMessage = "Could not save word: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }
}
