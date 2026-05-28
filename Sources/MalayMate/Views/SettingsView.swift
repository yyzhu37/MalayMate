import MalayMateCore
import SwiftUI

struct SettingsView: View {
    @AppStorage("openaiModelName") private var modelName = "gpt-5.4-mini"

    @State private var apiKey = ""
    @State private var hasSavedAPIKey = false
    @State private var statusMessage: String?
    @State private var speechService = SpeechService()

    var body: some View {
        Form {
            Section("AI") {
                TextField("Model", text: $modelName)
                SecureField("OpenAI API key", text: $apiKey)
                LabeledContent("Keychain", value: hasSavedAPIKey ? "API key saved" : "No API key saved")

                HStack {
                    Button {
                        saveAPIKey()
                    } label: {
                        Label("Save", systemImage: "key")
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(role: .destructive) {
                        clearAPIKey()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }

            Section("Audio") {
                if speechService.canSpeakMalay, let voice = speechService.availableMalayVoice {
                    LabeledContent("Malay voice", value: "\(voice.name) (\(voice.language))")
                } else {
                    Text("No Malay system voice available.")
                        .foregroundStyle(.secondary)
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .navigationTitle("Settings")
        .task {
            loadAPIKeyStatus()
        }
    }

    private func loadAPIKeyStatus() {
        do {
            let settings = SettingsStore(secretStore: KeychainStore(), modelName: modelName)
            hasSavedAPIKey = try settings.hasAPIKey()
            apiKey = ""
            statusMessage = hasSavedAPIKey ? "API key is saved in Keychain." : nil
        } catch {
            statusMessage = "Could not read Keychain: \(error.localizedDescription)"
        }
    }

    private func saveAPIKey() {
        do {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            try SettingsStore(secretStore: KeychainStore(), modelName: modelName).saveAPIKey(trimmed)
            apiKey = ""
            hasSavedAPIKey = true
            statusMessage = "API key saved."
        } catch {
            statusMessage = "Could not save API key: \(error.localizedDescription)"
        }
    }

    private func clearAPIKey() {
        do {
            try SettingsStore(secretStore: KeychainStore(), modelName: modelName).clearAPIKey()
            apiKey = ""
            hasSavedAPIKey = false
            statusMessage = "API key cleared."
        } catch {
            statusMessage = "Could not clear API key: \(error.localizedDescription)"
        }
    }
}
