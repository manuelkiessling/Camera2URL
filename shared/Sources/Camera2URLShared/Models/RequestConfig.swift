//
//  RequestConfig.swift
//  Camera2URLShared
//

import Foundation

public enum HTTPVerb: String, CaseIterable, Codable, Identifiable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"

    public var id: String { rawValue }

    public static var defaultVerb: HTTPVerb { .post }
}

public struct RequestConfig: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var verb: HTTPVerb
    public var url: String
    public var note: String

    public init(id: UUID = UUID(), verb: HTTPVerb, url: String, note: String) {
        self.id = id
        self.verb = verb
        self.url = url
        self.note = note
    }

    public var summary: String {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNote.isEmpty {
            return "\(verb.rawValue) · \(url)"
        }
        return "\(verb.rawValue) · \(url) · \(trimmedNote)"
    }

    public func matches(verb: HTTPVerb, url: String, note: String) -> Bool {
        let normalizedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return self.verb == verb
            && self.url.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedUrl
            && self.note.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedNote
    }
}

