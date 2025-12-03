//
//  ContentView.swift
//  camera2url
//

import Camera2URLShared
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: IOSAppViewModel
    @State private var showingHistory = false

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
        .sheet(isPresented: $viewModel.showingConfigSheet) {
            ConfigView(
                configStore: viewModel.configStore,
                initialConfig: viewModel.currentConfig,
                onComplete: viewModel.handleConfigSubmitted
            )
        }
        .sheet(isPresented: $showingHistory) {
            UploadHistoryView(history: viewModel.uploadHistory)
        }
        .task {
            await viewModel.prepareCameraIfNeeded()
        }
    }

    private var cameraPreviewSection: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Camera preview - fills remaining space above UI controls
                CameraPreviewView(session: viewModel.session, topSafeAreaInset: geometry.safeAreaInsets.top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topTrailing) {
                        // Show latest timer photo thumbnail when timer is active
                        if viewModel.isTimerActive, let photo = viewModel.lastTimerPhoto {
                            TimerPhotoThumbnail(
                                photo: photo,
                                captureCount: viewModel.timerCaptureCount,
                                captureTime: viewModel.lastTimerCaptureTime
                            )
                            .padding(16)
                            .padding(.top, geometry.safeAreaInsets.top)
                        }
                    }
                    .overlay {
                        if !viewModel.isCameraReady {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)
                                Text(viewModel.cameraError ?? "Preparing camera…")
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

            // UI controls - fixed size at bottom
            VStack(spacing: 16) {
                // Target info and buttons
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let config = viewModel.currentConfig {
                            Text(config.summary)
                                .font(.subheadline)
                                .lineLimit(2)
                        } else {
                            Text("Not configured")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        if viewModel.uploadHistory.records.count > 0 {
                            Button {
                                showingHistory = true
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title3)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button {
                            viewModel.editConfig()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Camera picker if multiple cameras available
                if viewModel.hasMultipleCameras {
                    CameraPicker(
                        cameras: viewModel.availableCameras,
                        currentCamera: viewModel.currentCamera,
                        onSelect: viewModel.switchCamera
                    )
                }

                if !viewModel.isTimerActive {
                    // Status for manual captures
                    statusView
                }

                // Main capture button or timer status
                if viewModel.isTimerActive {
                    TimerStatusView(
                        config: viewModel.timerConfig,
                        captureCount: viewModel.timerCaptureCount,
                        nextCaptureTime: viewModel.nextTimerCaptureTime,
                        uploadHistory: viewModel.uploadHistory,
                        onStop: viewModel.stopTimer,
                        onShowHistory: { showingHistory = true }
                    )
                } else {
                    Button {
                        viewModel.takeAndSendPhoto()
                    } label: {
                        Label("Take & Send Photo", systemImage: "camera.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
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
            .padding(.bottom, geometry.safeAreaInsets.bottom + 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            }
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch viewModel.uploadStatus {
        case .capturing:
            Label("Capturing photo…", systemImage: "camera.fill")
                .font(.callout)
        case .uploading:
            Label("Uploading photo…", systemImage: "icloud.and.arrow.up.fill")
                .font(.callout)
        case .failure(let report):
            Label(report.message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.callout)
                .lineLimit(2)
        case .success(let exchange):
            Label("Last upload succeeded (\(exchange.statusCode))", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        default:
            EmptyView()
        }
    }
}

// MARK: - Capture Result View

private struct CaptureResultView: View {
    let photo: IOSAppViewModel.CapturedPhoto
    let status: IOSAppViewModel.UploadStatus
    let onNext: () -> Void
    let onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .padding(.top, 60) // Safe area

                statusView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Button {
                        onNext()
                    } label: {
                        Label("Take Next Photo", systemImage: "camera.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Edit Target", action: onEdit)
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemBackground))
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
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 150)
                }
            }
        case .failure(let report):
            VStack(alignment: .leading, spacing: 12) {
                Label(report.message, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                
                DisclosureGroup("Request details") {
                    ScrollView {
                        Text(report.requestSummary)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 120)
                }

                if let responseSummary = report.responseSummary {
                    DisclosureGroup("Response details") {
                        ScrollView {
                            Text(responseSummary)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(height: 120)
                    }
                }
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Camera Picker

private struct CameraPicker: View {
    let cameras: [CameraDevice]
    let currentCamera: CameraDevice?
    let onSelect: (CameraDevice) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cameras) { camera in
                    Button {
                        onSelect(camera)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: camera.iconName)
                            Text(camera.displayName)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(camera.id == currentCamera?.id ? .blue : .secondary)
                }
            }
        }
    }
}

// MARK: - Timer Components

/// Thumbnail showing the latest photo captured by the timer
private struct TimerPhotoThumbnail: View {
    let photo: IOSAppViewModel.CapturedPhoto
    let captureCount: Int
    let captureTime: Date?
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(radius: 6)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Photo #\(captureCount)")
                    .font(.caption2.weight(.semibold))
                if let time = captureTime {
                    Text(time, style: .time)
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white)
            .shadow(radius: 4)
        }
        .padding(6)
        .background(.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .foregroundStyle(.green)
                        Text("Timer active")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    
                    Text("\(captureCount) photo\(captureCount == 1 ? "" : "s") \(config.displayString)")
                        .font(.caption)
                    
                    if let nextTime = nextCaptureTime {
                        HStack(spacing: 4) {
                            Text("Next:")
                            Text(nextTime, style: .relative)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    onStop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            
            // Upload status row
            if uploadHistory.successCount > 0 || uploadHistory.failureCount > 0 {
                Divider()
                
                HStack(spacing: 12) {
                    // Last upload status
                    if let lastRecord = uploadHistory.lastRecord {
                        HStack(spacing: 4) {
                            Image(systemName: lastRecord.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(lastRecord.success ? .green : .red)
                            Text(lastRecord.success ? "OK" : "Failed")
                                .font(.caption)
                        }
                    }
                    
                    // Success/failure counts
                    HStack(spacing: 8) {
                        Label("\(uploadHistory.successCount)", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                        Label("\(uploadHistory.failureCount)", systemImage: "xmark.circle")
                            .foregroundStyle(uploadHistory.failureCount > 0 ? .red : .secondary)
                    }
                    .font(.caption)
                    
                    Spacer()
                    
                    // View history button
                    Button {
                        onShowHistory()
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
        HStack(spacing: 12) {
            // Timer configuration
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $config.value) {
                    ForEach(1...59, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 100)
                .clipped()
                .disabled(isTimerActive)
                
                Picker("", selection: $config.unit) {
                    ForEach(TimerUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .labelsHidden()
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
            } else {
                Button {
                    onStart()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!isCameraReady)
            }
        }
    }
}
