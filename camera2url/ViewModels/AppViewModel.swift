//
//  AppViewModel.swift
//  camera2url
//

import AppKit
import AVFoundation
import Combine
import SwiftUI

@MainActor
final class AppViewModel: NSObject, ObservableObject {
    enum UploadStatus: Equatable {
        case idle
        case capturing
        case uploading
        case success(UploadExchange)
        case failure(UploadErrorReport)
    }

    struct CapturedPhoto: Identifiable {
        let id = UUID()
        let image: NSImage
        let data: Data
    }

    @Published var showingConfigDialog: Bool = true
    @Published private(set) var currentConfig: RequestConfig?
    @Published private(set) var uploadStatus: UploadStatus = .idle
    @Published private(set) var capturedPhoto: CapturedPhoto?
    @Published private(set) var cameraError: String?
    @Published private(set) var isCameraReady: Bool = false

    let configStore: ConfigStore
    private let cameraService: CameraService
    private let uploadService: UploadService

    var session: AVCaptureSession? {
        cameraService.session
    }

    init(
        configStore: ConfigStore,
        cameraService: CameraService? = nil,
        uploadService: UploadService? = nil
    ) {
        let camera = cameraService ?? CameraService()
        let upload = uploadService ?? UploadService()
        self.configStore = configStore
        self.cameraService = camera
        self.uploadService = upload
        showingConfigDialog = true
        currentConfig = configStore.configs.first
        super.init()
        self.cameraService.delegate = self
    }

    nonisolated func cleanUp() {
        Task { @MainActor in
            cameraService.stop()
        }
    }

    func handleConfigSubmitted(_ config: RequestConfig) {
        currentConfig = config
        showingConfigDialog = false
        Task {
            await prepareCameraIfNeeded()
        }
    }

    func editConfig() {
        showingConfigDialog = true
    }

    func prepareCameraIfNeeded() async {
        do {
            try await cameraService.prepareIfNeeded()
            cameraService.start()
            cameraError = nil
            isCameraReady = true
        } catch {
            cameraError = error.localizedDescription
            isCameraReady = false
        }
    }

    func stopCamera() {
        cameraService.stop()
        isCameraReady = false
    }

    func takeAndSendPhoto() {
        guard currentConfig != nil else {
            editConfig()
            return
        }
        guard isCameraReady else {
            Task { await prepareCameraIfNeeded() }
            return
        }
        capturedPhoto = nil
        uploadStatus = .capturing
        cameraService.capturePhoto()
    }

    func resetForNextCapture() {
        capturedPhoto = nil
        uploadStatus = .idle
    }

    private func upload(photoData: Data, image: NSImage) {
        guard let config = currentConfig else { return }
        capturedPhoto = CapturedPhoto(image: image, data: photoData)
        uploadStatus = .uploading
        Task {
            do {
                let exchange = try await uploadService.upload(photoData: photoData, using: config)
                uploadStatus = .success(exchange)
            } catch {
                if let report = error as? UploadErrorReport {
                    uploadStatus = .failure(report)
                } else {
                    let report = UploadErrorReport(
                        message: error.localizedDescription,
                        requestSummary: "Request was not created.",
                        responseSummary: nil
                    )
                    uploadStatus = .failure(report)
                }
            }
        }
    }
}

extension AppViewModel: CameraServiceDelegate {
    func cameraService(_ service: CameraService, didCapturePhoto data: Data) {
        guard let image = NSImage(data: data) else {
            let report = UploadErrorReport(
                message: "Failed to read captured image.",
                requestSummary: "No request sent.",
                responseSummary: "Camera produced unreadable data."
            )
            uploadStatus = .failure(report)
            return
        }
        upload(photoData: data, image: image)
    }

    func cameraService(_ service: CameraService, didEncounter error: Error) {
        cameraError = error.localizedDescription
        let report = UploadErrorReport(
            message: "Camera error: \(error.localizedDescription)",
            requestSummary: "No request sent.",
            responseSummary: nil
        )
        uploadStatus = .failure(report)
    }
}

