//
//  UploadRecord.swift
//  Camera2URLShared
//

import Combine
import Foundation

/// Record of a single upload attempt
public struct UploadRecord: Identifiable, Hashable, Sendable {
    public let id = UUID()
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: UploadRecord, rhs: UploadRecord) -> Bool {
        lhs.id == rhs.id
    }
    
    public let captureNumber: Int
    public let timestamp: Date
    public let success: Bool
    public let statusCode: Int?
    public let errorMessage: String?
    public let requestSummary: String
    public let responseSummary: String?
    public let isTimerCapture: Bool
    
    public init(
        captureNumber: Int,
        timestamp: Date,
        success: Bool,
        statusCode: Int?,
        errorMessage: String?,
        requestSummary: String,
        responseSummary: String?,
        isTimerCapture: Bool
    ) {
        self.captureNumber = captureNumber
        self.timestamp = timestamp
        self.success = success
        self.statusCode = statusCode
        self.errorMessage = errorMessage
        self.requestSummary = requestSummary
        self.responseSummary = responseSummary
        self.isTimerCapture = isTimerCapture
    }
    
    public var displayStatus: String {
        if success {
            return "✓ Success (\(statusCode ?? 0))"
        } else {
            return "✗ Failed"
        }
    }
    
    public var captureTypeLabel: String {
        isTimerCapture ? "Timer" : "Manual"
    }
}

/// Manages a rolling history of upload records
@MainActor
public class UploadHistory: ObservableObject {
    public static let maxRecords = 100
    
    @Published public private(set) var records: [UploadRecord] = []
    @Published public private(set) var successCount: Int = 0
    @Published public private(set) var failureCount: Int = 0
    
    public init() {}
    
    public var lastRecord: UploadRecord? {
        records.first
    }
    
    public var lastSuccessful: Bool? {
        records.first?.success
    }
    
    public func addSuccess(captureNumber: Int, exchange: UploadExchange, isTimerCapture: Bool) {
        let record = UploadRecord(
            captureNumber: captureNumber,
            timestamp: Date(),
            success: true,
            statusCode: exchange.statusCode,
            errorMessage: nil,
            requestSummary: exchange.requestSummary,
            responseSummary: exchange.responseSummary,
            isTimerCapture: isTimerCapture
        )
        addRecord(record)
    }
    
    public func addFailure(captureNumber: Int, error: UploadErrorReport, isTimerCapture: Bool) {
        let record = UploadRecord(
            captureNumber: captureNumber,
            timestamp: Date(),
            success: false,
            statusCode: nil,
            errorMessage: error.message,
            requestSummary: error.requestSummary,
            responseSummary: error.responseSummary,
            isTimerCapture: isTimerCapture
        )
        addRecord(record)
    }
    
    public func addFailure(captureNumber: Int, message: String, isTimerCapture: Bool) {
        let record = UploadRecord(
            captureNumber: captureNumber,
            timestamp: Date(),
            success: false,
            statusCode: nil,
            errorMessage: message,
            requestSummary: "Request may not have been sent.",
            responseSummary: nil,
            isTimerCapture: isTimerCapture
        )
        addRecord(record)
    }
    
    private func addRecord(_ record: UploadRecord) {
        records.insert(record, at: 0)
        if records.count > Self.maxRecords {
            records.removeLast()
        }
        recomputeCounts()
    }
    
    public func clear() {
        records.removeAll()
        successCount = 0
        failureCount = 0
    }

    private func recomputeCounts() {
        successCount = records.reduce(into: 0) { partial, record in
            if record.success {
                partial += 1
            }
        }
        failureCount = records.count - successCount
    }
}

