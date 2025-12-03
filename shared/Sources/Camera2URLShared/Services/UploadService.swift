//
//  UploadService.swift
//  Camera2URLShared
//

import Foundation

public final class UploadService: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func upload(photoData: Data, using config: RequestConfig) async throws -> UploadExchange {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = try makeURL(from: config.url)
        var request = URLRequest(url: url)
        request.httpMethod = config.verb.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var builder = MultipartBodyBuilder(boundary: boundary)
        let filename = "photo-\(Int(Date().timeIntervalSince1970)).jpg"
        if !config.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            builder.addText(name: "note", value: config.note)
        }
        builder.addFile(name: "file", filename: filename, mimeType: "image/jpeg", data: photoData)
        request.httpBody = builder.build()
        request.setValue(String(request.httpBody?.count ?? 0), forHTTPHeaderField: "Content-Length")

        let requestSummary = builder.buildRequestSummary(
            method: request.httpMethod ?? "POST",
            url: url,
            headers: request.allHTTPHeaderFields ?? [:]
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UploadErrorReport(
                    message: "Unexpected response type.",
                    requestSummary: requestSummary,
                    responseSummary: nil
                )
            }
            let responseSummary = describeResponse(httpResponse, body: data)
            if (200...299).contains(httpResponse.statusCode) {
                return UploadExchange(
                    statusCode: httpResponse.statusCode,
                    requestSummary: requestSummary,
                    responseSummary: responseSummary
                )
            } else {
                throw UploadErrorReport(
                    message: "Server returned status \(httpResponse.statusCode).",
                    requestSummary: requestSummary,
                    responseSummary: responseSummary
                )
            }
        } catch let report as UploadErrorReport {
            throw report
        } catch {
            throw UploadErrorReport(
                message: "Network error: \(error.localizedDescription)",
                requestSummary: requestSummary,
                responseSummary: nil
            )
        }
    }

    private func makeURL(from string: String) throws -> URL {
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            throw UploadErrorReport(
                message: "Invalid URL.",
                requestSummary: "Could not build request for \(string).",
                responseSummary: nil
            )
        }
        return url
    }

    private func describeResponse(_ response: HTTPURLResponse, body: Data) -> String {
        let headers = response.allHeaderFields
            .compactMap { key, value -> String? in
                guard let key = key as? String else { return nil }
                return "\(key): \(value)"
            }
            .sorted()
            .joined(separator: "\n")
        let bodyString: String
        if body.isEmpty {
            bodyString = "(empty body)"
        } else if let string = String(data: body, encoding: .utf8) {
            bodyString = string
        } else {
            bodyString = body.base64EncodedString()
        }

        return """
        HTTP \(response.statusCode)
        Headers:
        \(headers.isEmpty ? "(none)" : headers)

        Body:
        \(bodyString)
        """
    }
}

private struct MultipartBodyBuilder {
    let boundary: String
    private var components: [Data] = []
    private var summaryParts: [String] = []

    init(boundary: String) {
        self.boundary = boundary
    }

    mutating func addText(name: String, value: String) {
        var part = Data()
        part.appendString("--\(boundary)\r\n")
        part.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        part.appendString("\(value)\r\n")
        components.append(part)

        summaryParts.append("""
        --\(boundary)
        Content-Disposition: form-data; name="\(name)"

        \(value)
        """)
    }

    mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        var part = Data()
        part.appendString("--\(boundary)\r\n")
        part.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        part.appendString("Content-Type: \(mimeType)\r\n\r\n")
        part.append(data)
        part.appendString("\r\n")
        components.append(part)

        summaryParts.append("""
        --\(boundary)
        Content-Disposition: form-data; name="\(name)"; filename="\(filename)"
        Content-Type: \(mimeType)

        <\(data.count) bytes, image data omitted>
        """)
    }

    func build() -> Data {
        var data = Data()
        components.forEach { data.append($0) }
        data.appendString("--\(boundary)--\r\n")
        return data
    }

    func buildRequestSummary(method: String, url: URL, headers: [String: String]) -> String {
        let headersString = headers
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")

        let summaryBody = (summaryParts + ["--\(boundary)--"])
            .joined(separator: "\n")

        return """
        \(method) \(url.absoluteString)
        Headers:
        \(headersString.isEmpty ? "(none)" : headersString)

        Body:
        \(summaryBody)
        """
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

