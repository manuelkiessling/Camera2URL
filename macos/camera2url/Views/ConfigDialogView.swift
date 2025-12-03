//
//  ConfigDialogView.swift
//  camera2url
//

import Camera2URLShared
import SwiftUI

struct ConfigDialogView: View {
    @ObservedObject var configStore: ConfigStore
    let initialConfig: RequestConfig?
    let onComplete: (RequestConfig) -> Void

    @State private var selectedVerb: HTTPVerb
    @State private var url: String
    @State private var note: String
    @State private var selectedExistingId: RequestConfig.ID?
    @State private var validationMessage: String?

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
        VStack(alignment: .leading, spacing: 20) {
            Text("Configure request")
                .font(.title2)
                .bold()

            if !configStore.configs.isEmpty {
                Picker("Reuse previous", selection: $selectedExistingId) {
                    Text("New entry")
                        .tag(RequestConfig.ID?.none)
                    ForEach(configStore.configs) { config in
                        Text(config.summary)
                            .tag(Optional(config.id))
                    }
                }
                .controlSize(.large)
                .onChange(of: selectedExistingId) { _, newValue in
                    handleExistingSelection(newValue)
                }
            }

            Picker("HTTP Verb", selection: $selectedVerb) {
                ForEach(HTTPVerb.allCases) { verb in
                    Text(verb.rawValue)
                        .tag(verb)
                }
            }
            .controlSize(.large)

            TextField("https://example.com/endpoint", text: $url)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)

            TextField("Optional note", text: $note)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button {
                    handleNext()
                } label: {
                    Text("Next")
                        .font(.title3.weight(.medium))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 460)
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
    }
}

#Preview {
    ConfigDialogView(
        configStore: ConfigStore(),
        initialConfig: nil,
        onComplete: { _ in }
    )
}
