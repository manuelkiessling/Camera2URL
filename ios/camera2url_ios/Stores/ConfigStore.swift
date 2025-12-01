//
//  ConfigStore.swift
//  camera2url_ios
//

import Combine
import Foundation

@MainActor
final class ConfigStore: ObservableObject {
    @Published private(set) var configs: [RequestConfig] = []

    private let storageKey = "camera2url.requestConfigs"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func upsert(verb: HTTPVerb, url: String, note: String) -> RequestConfig {
        let normalizedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = configs.firstIndex(where: { $0.matches(verb: verb, url: normalizedUrl, note: normalizedNote) }) {
            let existing = configs.remove(at: index)
            configs.insert(existing, at: 0)
            persist()
            return existing
        }

        let config = RequestConfig(verb: verb, url: normalizedUrl, note: normalizedNote)
        configs.insert(config, at: 0)
        persist()
        return config
    }

    func updateSelection(_ config: RequestConfig) {
        guard let index = configs.firstIndex(where: { $0.id == config.id }) else { return }
        configs.remove(at: index)
        configs.insert(config, at: 0)
        persist()
    }

    func deleteAll() {
        configs.removeAll()
        persist()
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            configs = []
            return
        }
        do {
            configs = try JSONDecoder().decode([RequestConfig].self, from: data)
        } catch {
            configs = []
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(configs) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

