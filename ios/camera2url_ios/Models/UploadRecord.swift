//
//  UploadRecord.swift
//  camera2url_ios
//

import Combine
import Foundation

/// Record of a single upload attempt
struct UploadRecord: Identifiable, Hashable {
    let id = UUID()
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: UploadRecord, rhs: UploadRecord) -> Bool {
        lhs.id == rhs.id
    }
    
    let captureNumber: Int
    let timestamp: Date
    let success: Bool
    let statusCode: Int?
    let errorMessage: String?
    let requestSummary: String
    let responseSummary: String?
    let isTimerCapture: Bool
    
    var displayStatus: String {
        if success {
            return "✓ Success (\(statusCode ?? 0))"
        } else {
            return "✗ Failed"
        }
    }
    
    var captureTypeLabel: String {
        isTimerCapture ? "Timer" : "Manual"
    }
}

/// Manages a rolling history of upload records
class UploadHistory: ObservableObject {
    static let maxRecords = 100
    
    @Published private(set) var records: [UploadRecord] = []
    @Published private(set) var successCount: Int = 0
    @Published private(set) var failureCount: Int = 0
    
    var lastRecord: UploadRecord? {
        records.first
    }
    
    var lastSuccessful: Bool? {
        records.first?.success
    }
    
    func addSuccess(captureNumber: Int, exchange: UploadExchange, isTimerCapture: Bool) {
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
    
    func addFailure(captureNumber: Int, error: UploadErrorReport, isTimerCapture: Bool) {
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
    
    func addFailure(captureNumber: Int, message: String, isTimerCapture: Bool) {
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
    
    func clear() {
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

