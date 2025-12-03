//
//  UploadModels.swift
//  Camera2URLShared
//

import Foundation

public struct UploadExchange: Equatable, Sendable {
    public let statusCode: Int
    public let requestSummary: String
    public let responseSummary: String
    
    public init(statusCode: Int, requestSummary: String, responseSummary: String) {
        self.statusCode = statusCode
        self.requestSummary = requestSummary
        self.responseSummary = responseSummary
    }
}

public struct UploadErrorReport: Equatable, Error, Identifiable, Sendable {
    public let id = UUID()
    public let message: String
    public let requestSummary: String
    public let responseSummary: String?
    
    public init(message: String, requestSummary: String, responseSummary: String?) {
        self.message = message
        self.requestSummary = requestSummary
        self.responseSummary = responseSummary
    }
}

