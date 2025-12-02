//
//  UploadHistoryView.swift
//  camera2url
//

import SwiftUI

struct UploadHistoryView: View {
    @ObservedObject var history: UploadHistory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if history.records.isEmpty {
                    ContentUnavailableView(
                        "No Uploads Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Upload history will appear here as photos are captured.")
                    )
                } else {
                    List {
                        ForEach(history.records) { record in
                            NavigationLink(value: record) {
                                UploadHistoryRow(record: record)
                            }
                        }
                    }
                    .navigationDestination(for: UploadRecord.self) { record in
                        UploadHistoryDetailView(record: record)
                    }
                }
            }
            .navigationTitle("Upload History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Label("\(history.successCount)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Label("\(history.failureCount)", systemImage: "xmark.circle.fill")
                            .foregroundStyle(history.failureCount > 0 ? .red : .secondary)
                    }
                    .font(.caption)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct UploadHistoryRow: View {
    let record: UploadRecord
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(record.success ? .green : .red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Photo #\(record.captureNumber)")
                        .font(.subheadline.weight(.medium))
                    
                    Text(record.captureTypeLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(record.isTimerCapture ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                if record.success {
                    Text("Status \(record.statusCode ?? 0)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(record.errorMessage ?? "Unknown error")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(record.timestamp, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct UploadHistoryDetailView: View {
    let record: UploadRecord
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(record.success ? .green : .red)
                        .font(.title)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photo #\(record.captureNumber)")
                            .font(.title3.weight(.semibold))
                        Text(record.timestamp, format: .dateTime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(record.captureTypeLabel)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(record.isTimerCapture ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if let error = record.errorMessage {
                    DetailSection(title: "Error") {
                        Text(error)
                            .font(.body)
                            .foregroundStyle(.red)
                    }
                }
                
                DetailSection(title: "Request") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(record.requestSummary)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                
                if let response = record.responseSummary {
                    DetailSection(title: "Response") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(response)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Upload Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    UploadHistoryView(history: UploadHistory())
}

