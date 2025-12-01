//
//  UploadModels.swift
//  camera2url_ios
//

import Foundation

struct UploadExchange: Equatable {
    let statusCode: Int
    let requestSummary: String
    let responseSummary: String
}

struct UploadErrorReport: Equatable, Error, Identifiable {
    let id = UUID()
    let message: String
    let requestSummary: String
    let responseSummary: String?
}

