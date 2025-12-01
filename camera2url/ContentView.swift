//
//  ContentView.swift
//  camera2url
//
//  Created by Manuel Kießling on 01.12.25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

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
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: viewModel.session)
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
                        Button("Edit target URL", action: viewModel.editConfig)
                            .controlSize(.large)
                    }
                }

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
                        if camera.isContinuityCamera {
                            Image(systemName: "iphone")
                        } else {
                            Image(systemName: "video.fill")
                        }
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
                systemImage: currentCamera?.isContinuityCamera == true ? "iphone" : "video.fill"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .controlSize(.large)
    }
}
