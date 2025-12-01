//
//  RequestConfig.swift
//  camera2url_ios
//

import Foundation

enum HTTPVerb: String, CaseIterable, Codable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"

    var id: String { rawValue }

    static var defaultVerb: HTTPVerb { .post }
}

struct RequestConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var verb: HTTPVerb
    var url: String
    var note: String

    init(id: UUID = UUID(), verb: HTTPVerb, url: String, note: String) {
        self.id = id
        self.verb = verb
        self.url = url
        self.note = note
    }

    var summary: String {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNote.isEmpty {
            return "\(verb.rawValue) · \(url)"
        }
        return "\(verb.rawValue) · \(url) · \(trimmedNote)"
    }

    func matches(verb: HTTPVerb, url: String, note: String) -> Bool {
        let normalizedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return self.verb == verb
            && self.url.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedUrl
            && self.note.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedNote
    }
}

