//
//  ContentView.swift
//  camera2url
//
//  Created by Manuel Kießling on 01.12.25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            if viewModel.capturedPhoto == nil {
                cameraPreviewSection
            } else if let photo = viewModel.capturedPhoto {
                CaptureResultView(
                    photo: photo,
                    status: viewModel.uploadStatus,
                    onNext: viewModel.resetForNextCapture,
                    onEdit: viewModel.editConfig
                )
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .sheet(isPresented: $viewModel.showingConfigDialog) {
            ConfigDialogView(
                configStore: viewModel.configStore,
                initialConfig: viewModel.currentConfig,
                onComplete: viewModel.handleConfigSubmitted
            )
        }
        .frame(minWidth: 760, minHeight: 560)
        .task {
            await viewModel.prepareCameraIfNeeded()
        }
    }

    private var cameraPreviewSection: some View {
        VStack(spacing: 0) {
            // Camera preview - fills remaining space above UI controls
            CameraPreviewView(session: viewModel.session)
                .overlay(alignment: .topTrailing) {
                    // Show latest timer photo thumbnail when timer is active
                    if viewModel.isTimerActive, let photo = viewModel.lastTimerPhoto {
                        TimerPhotoThumbnail(
                            photo: photo,
                            captureCount: viewModel.timerCaptureCount,
                            captureTime: viewModel.lastTimerCaptureTime
                        )
                        .padding(16)
                    }
                }
                .overlay {
                    if !viewModel.isCameraReady {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(viewModel.cameraError ?? "Preparing camera…")
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

            // UI controls - fixed size at bottom
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configured target")
                            .font(.headline)
                        if let config = viewModel.currentConfig {
                            Text(config.summary)
                                .font(.body)
                        } else {
                            Text("No target selected. Please configure first.")
                                .font(.body)
                        }
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 14) {
                        if viewModel.hasMultipleCameras {
                            CameraPicker(
                                cameras: viewModel.availableCameras,
                                currentCamera: viewModel.currentCamera,
                                onSelect: viewModel.switchCamera
                            )
                        }
                        
                        HStack(spacing: 12) {
                            if viewModel.uploadHistory.records.count > 0 {
                                Button {
                                    openWindow(id: "upload-history")
                                } label: {
                                    Label("History", systemImage: "clock.arrow.circlepath")
                                }
                                .controlSize(.large)
                            }
                            
                            Button("Edit target URL", action: viewModel.editConfig)
                                .controlSize(.large)
                        }
                    }
                }

                if !viewModel.isTimerActive {
                    // Status for manual captures
                    VStack(alignment: .leading, spacing: 8) {
                        switch viewModel.uploadStatus {
                        case .capturing:
                            Label("Capturing photo…", systemImage: "camera.fill")
                        case .uploading:
                            Label("Uploading photo…", systemImage: "icloud.and.arrow.up.fill")
                        case .failure(let report):
                            Label(report.message, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        case .success(let exchange):
                            Label("Last upload succeeded (\(exchange.statusCode)).", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        default:
                            EmptyView()
                        }
                    }
                    .font(.callout)
                }

                // Main capture button or timer status
                if viewModel.isTimerActive {
                    TimerStatusView(
                        config: viewModel.timerConfig,
                        captureCount: viewModel.timerCaptureCount,
                        nextCaptureTime: viewModel.nextTimerCaptureTime,
                        uploadHistory: viewModel.uploadHistory,
                        onStop: viewModel.stopTimer,
                        onShowHistory: { openWindow(id: "upload-history") }
                    )
                } else {
                    Button {
                        viewModel.takeAndSendPhoto()
                    } label: {
                        Label("Take and send photo", systemImage: "camera.on.rectangle")
                            .font(.title.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.isCameraReady || viewModel.uploadStatus == .capturing || viewModel.uploadStatus == .uploading)
                }
                
                // Timer controls
                TimerControlsView(
                    config: $viewModel.timerConfig,
                    isTimerActive: viewModel.isTimerActive,
                    isCameraReady: viewModel.isCameraReady,
                    onStart: viewModel.startTimer,
                    onStop: viewModel.stopTimer
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
    }
}

private struct CaptureResultView: View {
    let photo: AppViewModel.CapturedPhoto
    let status: AppViewModel.UploadStatus
    let onNext: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: photo.image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()

            statusView
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            HStack(spacing: 16) {
                Button {
                    onNext()
                } label: {
                    Label("Take next photo", systemImage: "camera.fill")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Edit target URL", action: onEdit)
                    .controlSize(.large)
            }
            .padding(.bottom, 20)
        }
        .background(Color.black.opacity(0.05))
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .uploading:
            Label("Uploading photo…", systemImage: "icloud.and.arrow.up.fill")
        case .success(let exchange):
            VStack(alignment: .leading, spacing: 8) {
                Label("Upload successful (\(exchange.statusCode))", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                DisclosureGroup("View response details") {
                    ScrollView {
                        Text(exchange.responseSummary)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 180)
                }
            }
        case .failure(let report):
            VStack(alignment: .leading, spacing: 12) {
                Label(report.message, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text("Request")
                    .font(.headline)
                ScrollView {
                    Text(report.requestSummary)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.background.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 160)

                if let responseSummary = report.responseSummary {
                    Text("Response")
                        .font(.headline)
                    ScrollView {
                        Text(responseSummary)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.background.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(height: 160)
                }
            }
        default:
            EmptyView()
        }
    }
}

/// Camera picker for switching between available cameras
private struct CameraPicker: View {
    let cameras: [CameraDevice]
    let currentCamera: CameraDevice?
    let onSelect: (CameraDevice) -> Void
    
    var body: some View {
        Menu {
            ForEach(cameras) { camera in
                Button {
                    onSelect(camera)
                } label: {
                    HStack {
                        Image(systemName: camera.iconName)
                        Text(camera.displayName)
                        if camera.id == currentCamera?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(
                currentCamera?.displayName ?? "Select Camera",
                systemImage: currentCamera?.iconName ?? "video.fill"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .controlSize(.large)
    }
}

// MARK: - Timer Components

/// Thumbnail showing the latest photo captured by the timer
private struct TimerPhotoThumbnail: View {
    let photo: AppViewModel.CapturedPhoto
    let captureCount: Int
    let captureTime: Date?
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Image(nsImage: photo.image)
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(radius: 8)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Photo #\(captureCount)")
                    .font(.caption.weight(.semibold))
                if let time = captureTime {
                    Text(time, style: .time)
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white)
            .shadow(radius: 4)
        }
        .padding(8)
        .background(.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Shows timer status and stop button when timer is active
private struct TimerStatusView: View {
    let config: TimerConfig
    let captureCount: Int
    let nextCaptureTime: Date?
    @ObservedObject var uploadHistory: UploadHistory
    let onStop: () -> Void
    let onShowHistory: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .foregroundStyle(.green)
                        Text("Timer active")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                    
                    Text("\(captureCount) photo\(captureCount == 1 ? "" : "s") captured \(config.displayString)")
                        .font(.callout)
                    
                    if let nextTime = nextCaptureTime {
                        HStack(spacing: 4) {
                            Text("Next capture:")
                            Text(nextTime, style: .relative)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    onStop()
                } label: {
                    Label("Stop Timer", systemImage: "stop.fill")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
            
            // Upload status row
            if uploadHistory.successCount > 0 || uploadHistory.failureCount > 0 {
                Divider()
                
                HStack(spacing: 16) {
                    // Last upload status
                    if let lastRecord = uploadHistory.lastRecord {
                        HStack(spacing: 6) {
                            Image(systemName: lastRecord.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(lastRecord.success ? .green : .red)
                            Text("Last upload: \(lastRecord.success ? "OK" : "Failed")")
                                .font(.callout)
                        }
                    }
                    
                    // Success/failure counts
                    HStack(spacing: 12) {
                        Label("\(uploadHistory.successCount)", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                        Label("\(uploadHistory.failureCount)", systemImage: "xmark.circle")
                            .foregroundStyle(uploadHistory.failureCount > 0 ? .red : .secondary)
                    }
                    .font(.callout)
                    
                    Spacer()
                    
                    // View history button
                    Button {
                        onShowHistory()
                    } label: {
                        Label("View History", systemImage: "list.bullet.rectangle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.green.opacity(0.1))
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Controls for configuring and starting/stopping the timer
private struct TimerControlsView: View {
    @Binding var config: TimerConfig
    let isTimerActive: Bool
    let isCameraReady: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Timer configuration
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundStyle(.secondary)
                
                Text("Auto-capture")
                    .font(.subheadline)
                
                TextField("", value: $config.value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .disabled(isTimerActive)
                
                Picker("", selection: $config.unit) {
                    ForEach(TimerUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
                .disabled(isTimerActive)
            }
            
            Spacer()
            
            // Start/Stop button
            if isTimerActive {
                Button {
                    onStop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
            } else {
                Button {
                    onStart()
                } label: {
                    Label("Start Timer", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!isCameraReady)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Timer History View

/// Shows the history of timer upload attempts
struct UploadHistoryView: View {
    @ObservedObject var history: UploadHistory
    @State private var selectedRecord: UploadRecord?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Upload History")
                    .font(.title2.weight(.semibold))
                
                Spacer()
                
                HStack(spacing: 16) {
                    Label("\(history.successCount) succeeded", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("\(history.failureCount) failed", systemImage: "xmark.circle.fill")
                        .foregroundStyle(history.failureCount > 0 ? .red : .secondary)
                }
                .font(.callout)
            }
            .padding()
            .background(.bar)
            
            Divider()
            
            if history.records.isEmpty {
                ContentUnavailableView(
                    "No Uploads Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Upload history will appear here as photos are captured.")
                )
            } else {
                HSplitView {
                    // Records list
                    List(history.records, selection: $selectedRecord) { record in
                        UploadHistoryRow(record: record)
                            .tag(record)
                    }
                    .frame(minWidth: 300)
                    
                    // Detail view
                    if let record = selectedRecord {
                        UploadHistoryDetailView(record: record)
                            .frame(minWidth: 400)
                    } else {
                        ContentUnavailableView(
                            "Select an Upload",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Select an upload from the list to view request and response details.")
                        )
                        .frame(minWidth: 400)
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
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
                        .font(.headline)
                    
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
                HStack {
                    Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(record.success ? .green : .red)
                        .font(.title)
                    
                    VStack(alignment: .leading) {
                        Text("Photo #\(record.captureNumber)")
                            .font(.title2.weight(.semibold))
                        Text(record.timestamp, format: .dateTime)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let error = record.errorMessage {
                    GroupBox("Error") {
                        Text(error)
                            .font(.body)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                GroupBox("Request") {
                    ScrollView(.horizontal) {
                        Text(record.requestSummary)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                
                if let response = record.responseSummary {
                    GroupBox("Response") {
                        ScrollView(.horizontal) {
                            Text(response)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding()
        }
    }
}
