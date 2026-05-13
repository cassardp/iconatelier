import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var didLoad: Bool = false
    @State private var isSaving: Bool = false
    @State private var isRevealed: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if isRevealed {
                                TextField("sk-...", text: $apiKey)
                            } else {
                                SecureField("sk-...", text: $apiKey)
                            }
                        }
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(save)

                        Button {
                            isRevealed.toggle()
                        } label: {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isRevealed ? "Hide API key" : "Show API key")
                    }
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("Stored securely in the iOS Keychain on this device. Used to generate icons via OpenAI.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(!didLoad || isSaving)
                }
            }
            .task {
                guard !didLoad else { return }
                apiKey = await APIKeyStore.shared.load() ?? ""
                didLoad = true
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let value = apiKey
        Task {
            await APIKeyStore.shared.save(value)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}
