//
//  TimerUploadRecord.swift
//  camera2url
//

import Combine
import Foundation

/// Record of a single upload attempt during timer mode
struct TimerUploadRecord: Identifiable, Hashable {
    let id = UUID()
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TimerUploadRecord, rhs: TimerUploadRecord) -> Bool {
        lhs.id == rhs.id
    }
    let captureNumber: Int
    let timestamp: Date
    let success: Bool
    let statusCode: Int?
    let errorMessage: String?
    let requestSummary: String
    let responseSummary: String?
    
    var displayStatus: String {
        if success {
            return "✓ Success (\(statusCode ?? 0))"
        } else {
            return "✗ Failed"
        }
    }
}

/// Manages a rolling history of timer upload records
class TimerUploadHistory: ObservableObject {
    static let maxRecords = 100
    
    @Published private(set) var records: [TimerUploadRecord] = []
    @Published private(set) var successCount: Int = 0
    @Published private(set) var failureCount: Int = 0
    
    var lastRecord: TimerUploadRecord? {
        records.first
    }
    
    var lastSuccessful: Bool? {
        records.first?.success
    }
    
    func addSuccess(captureNumber: Int, exchange: UploadExchange) {
        let record = TimerUploadRecord(
            captureNumber: captureNumber,
            timestamp: Date(),
            success: true,
            statusCode: exchange.statusCode,
            errorMessage: nil,
            requestSummary: exchange.requestSummary,
            responseSummary: exchange.responseSummary
        )
        addRecord(record)
        successCount += 1
    }
    
    func addFailure(captureNumber: Int, error: UploadErrorReport) {
        let record = TimerUploadRecord(
            captureNumber: captureNumber,
            timestamp: Date(),
            success: false,
            statusCode: nil,
            errorMessage: error.message,
            requestSummary: error.requestSummary,
            responseSummary: error.responseSummary
        )
        addRecord(record)
        failureCount += 1
    }
    
    func addFailure(captureNumber: Int, message: String) {
        let record = TimerUploadRecord(
            captureNumber: captureNumber,
            timestamp: Date(),
            success: false,
            statusCode: nil,
            errorMessage: message,
            requestSummary: "Request may not have been sent.",
            responseSummary: nil
        )
        addRecord(record)
        failureCount += 1
    }
    
    private func addRecord(_ record: TimerUploadRecord) {
        records.insert(record, at: 0)
        if records.count > Self.maxRecords {
            records.removeLast()
        }
    }
    
    func clear() {
        records.removeAll()
        successCount = 0
        failureCount = 0
    }
}

