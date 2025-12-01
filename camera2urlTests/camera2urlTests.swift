//
//  camera2urlTests.swift
//  camera2urlTests
//
//

import Foundation
import Testing
@testable import camera2url

@Suite("Camera2urlTests", .serialized)
struct Camera2urlTests {
    @MainActor
    @Test("ConfigStore de-duplicates entries and persists to UserDefaults")
    func configStoreDeduplicatesAndPersists() throws {
        let suiteName = "ConfigStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create UserDefaults suite.")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = ConfigStore(userDefaults: defaults)
        let first = store.upsert(verb: .post, url: "https://example.com/upload", note: "hello")
        #expect(store.configs.count == 1)

        let duplicate = store.upsert(verb: .post, url: "https://example.com/upload", note: "hello")
        #expect(store.configs.count == 1)
        #expect(first.id == duplicate.id)

        let restored = ConfigStore(userDefaults: defaults)
        #expect(restored.configs.count == 1)
        #expect(restored.configs.first?.id == first.id)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("TimerConfig clamps invalid timer values to a minimum of 1 second")
    func timerConfigClampsToMinimumInterval() throws {
        var config = TimerConfig(value: 10, unit: .seconds)
        config.value = 0
        #expect(config.value == 1)
        config.value = -5
        #expect(config.value == 1)

        config.value = 5
        #expect(config.value == 5)
        #expect(config.intervalInSeconds == 5)
    }

    @Test("UploadService builds multipart requests and reports success")
    func uploadServiceReturnsSuccess() async throws {
        let session = makeInterceptedSession()
        let service = UploadService(session: session)

        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: ["X-Test": "ok"]
            )!
            let body = Data(#"{"status":"ok"}"#.utf8)
            return (response, body)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let config = RequestConfig(verb: .post, url: "https://example.com/upload", note: "demo")
        let data = Data(repeating: 0xFF, count: 32)

        let exchange = try await service.upload(photoData: data, using: config)
        #expect(exchange.statusCode == 204)
        #expect(exchange.requestSummary.contains("POST https://example.com/upload"))
        #expect(exchange.responseSummary.contains("HTTP 204"))
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
    }

    @Test("UploadService surfaces HTTP failures with detailed report")
    func uploadServiceEmitsErrorReport() async throws {
        let session = makeInterceptedSession()
        let service = UploadService(session: session)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
            let body = Data("boom".utf8)
            return (response, body)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let config = RequestConfig(verb: .post, url: "https://example.com/fail", note: "")
        let data = Data([0x00, 0x01, 0x02])

        do {
            _ = try await service.upload(photoData: data, using: config)
            Issue.record("Expected upload to throw an UploadErrorReport.")
        } catch let report as UploadErrorReport {
            #expect(report.message.contains("Server returned status 500"))
            #expect(report.requestSummary.contains("POST https://example.com/fail"))
            #expect(report.responseSummary?.contains("HTTP 500") == true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeInterceptedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
