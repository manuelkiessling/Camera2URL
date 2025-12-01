//
//  ConfigView.swift
//  camera2url_ios
//

import SwiftUI

struct ConfigView: View {
    @ObservedObject var configStore: ConfigStore
    let initialConfig: RequestConfig?
    let onComplete: (RequestConfig) -> Void

    @State private var selectedVerb: HTTPVerb
    @State private var url: String
    @State private var note: String
    @State private var selectedExistingId: RequestConfig.ID?
    @State private var validationMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(
        configStore: ConfigStore,
        initialConfig: RequestConfig?,
        onComplete: @escaping (RequestConfig) -> Void
    ) {
        self.configStore = configStore
        self.initialConfig = initialConfig
        self.onComplete = onComplete
        _selectedVerb = State(initialValue: initialConfig?.verb ?? .defaultVerb)
        _url = State(initialValue: initialConfig?.url ?? "")
        _note = State(initialValue: initialConfig?.note ?? "")
        _selectedExistingId = State(initialValue: initialConfig?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !configStore.configs.isEmpty {
                    Section {
                        Picker("Reuse previous", selection: $selectedExistingId) {
                            Text("New entry")
                                .tag(RequestConfig.ID?.none)
                            ForEach(configStore.configs) { config in
                                Text(config.summary)
                                    .lineLimit(2)
                                    .tag(Optional(config.id))
                            }
                        }
                        .onChange(of: selectedExistingId) { _, newValue in
                            handleExistingSelection(newValue)
                        }
                    } header: {
                        Text("Previous Configurations")
                    }
                }

                Section {
                    Picker("HTTP Method", selection: $selectedVerb) {
                        ForEach(HTTPVerb.allCases) { verb in
                            Text(verb.rawValue)
                                .tag(verb)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("HTTP Method")
                }

                Section {
                    TextField("https://example.com/endpoint", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Target URL")
                } footer: {
                    if let validationMessage {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    TextField("Optional description", text: $note)
                } header: {
                    Text("Note")
                } footer: {
                    Text("The note will be sent along with the photo.")
                }
            }
            .navigationTitle("Configure Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        handleNext()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSubmit)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    if initialConfig != nil {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(initialConfig == nil)
        }
    }

    private var canSubmit: Bool {
        guard let url = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              !(url.host?.isEmpty ?? true)
        else {
            return false
        }
        return true
    }

    private func handleExistingSelection(_ id: RequestConfig.ID?) {
        guard let id,
              let config = configStore.configs.first(where: { $0.id == id })
        else { return }
        selectedVerb = config.verb
        url = config.url
        note = config.note
    }

    private func handleNext() {
        guard canSubmit else {
            validationMessage = "Please enter a valid HTTP or HTTPS URL."
            return
        }
        validationMessage = nil
        let config = configStore.upsert(verb: selectedVerb, url: url, note: note)
        onComplete(config)
        dismiss()
    }
}

#Preview {
    ConfigView(
        configStore: ConfigStore(),
        initialConfig: nil,
        onComplete: { _ in }
    )
}

