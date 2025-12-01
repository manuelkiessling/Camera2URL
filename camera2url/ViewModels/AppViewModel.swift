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
    @Published private(set) var availableCameras: [CameraDevice] = []
    @Published private(set) var currentCamera: CameraDevice?
    
    // Timer mode state
    @Published var timerConfig: TimerConfig = TimerConfig()
    @Published private(set) var isTimerActive: Bool = false
    @Published private(set) var timerCaptureCount: Int = 0
    @Published private(set) var lastTimerPhoto: CapturedPhoto?
    @Published private(set) var lastTimerCaptureTime: Date?
    @Published private(set) var nextTimerCaptureTime: Date?
    let timerUploadHistory = TimerUploadHistory()

    let configStore: ConfigStore
    private let cameraService: CameraService
    private let uploadService: UploadService
    private var timerTask: Task<Void, Never>?
    private var isTimerCapture: Bool = false

    var session: AVCaptureSession? {
        cameraService.session
    }
    
    var hasMultipleCameras: Bool {
        availableCameras.count > 1
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
            updateCameraState()
        } catch {
            cameraError = error.localizedDescription
            isCameraReady = false
        }
    }
    
    func switchCamera(to camera: CameraDevice) {
        do {
            try cameraService.switchCamera(to: camera)
            currentCamera = cameraService.currentCamera
            cameraError = nil
        } catch {
            cameraError = error.localizedDescription
        }
    }
    
    private func updateCameraState() {
        availableCameras = cameraService.availableCameras
        currentCamera = cameraService.currentCamera
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
    
    // MARK: - Timer Mode
    
    func startTimer() {
        guard !isTimerActive else { return }
        guard currentConfig != nil else {
            editConfig()
            return
        }
        guard isCameraReady else {
            Task { await prepareCameraIfNeeded() }
            return
        }
        
        isTimerActive = true
        timerCaptureCount = 0
        lastTimerPhoto = nil
        lastTimerCaptureTime = nil
        timerUploadHistory.clear()
        
        timerTask = Task {
            await runTimerLoop()
        }
    }
    
    func stopTimer() {
        isTimerActive = false
        timerTask?.cancel()
        timerTask = nil
        nextTimerCaptureTime = nil
    }
    
    private func runTimerLoop() async {
        // Take first photo immediately
        await captureTimerPhoto()
        
        while !Task.isCancelled && isTimerActive {
            let interval = timerConfig.intervalInSeconds
            nextTimerCaptureTime = Date().addingTimeInterval(interval)
            
            do {
                try await Task.sleep(for: .seconds(interval))
                if !Task.isCancelled && isTimerActive {
                    await captureTimerPhoto()
                }
            } catch {
                // Task was cancelled
                break
            }
        }
        
        nextTimerCaptureTime = nil
    }
    
    private func captureTimerPhoto() async {
        guard isCameraReady else { return }
        isTimerCapture = true
        cameraService.capturePhoto()
    }
    
    private func handleTimerCapture(photoData: Data, image: NSImage) {
        lastTimerPhoto = CapturedPhoto(image: image, data: photoData)
        lastTimerCaptureTime = Date()
        timerCaptureCount += 1
        
        let captureNumber = timerCaptureCount
        
        // Upload in background and track result
        guard let config = currentConfig else { return }
        Task {
            do {
                let exchange = try await uploadService.upload(photoData: photoData, using: config)
                timerUploadHistory.addSuccess(captureNumber: captureNumber, exchange: exchange)
            } catch {
                if let report = error as? UploadErrorReport {
                    timerUploadHistory.addFailure(captureNumber: captureNumber, error: report)
                } else {
                    timerUploadHistory.addFailure(captureNumber: captureNumber, message: error.localizedDescription)
                }
            }
        }
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
            if !isTimerCapture {
                let report = UploadErrorReport(
                    message: "Failed to read captured image.",
                    requestSummary: "No request sent.",
                    responseSummary: "Camera produced unreadable data."
                )
                uploadStatus = .failure(report)
            }
            isTimerCapture = false
            return
        }
        
        if isTimerCapture {
            isTimerCapture = false
            handleTimerCapture(photoData: data, image: image)
        } else {
            upload(photoData: data, image: image)
        }
    }

    func cameraService(_ service: CameraService, didEncounter error: Error) {
        cameraError = error.localizedDescription
        if !isTimerCapture {
            let report = UploadErrorReport(
                message: "Camera error: \(error.localizedDescription)",
                requestSummary: "No request sent.",
                responseSummary: nil
            )
            uploadStatus = .failure(report)
        }
        isTimerCapture = false
    }
    
    func cameraServiceDidUpdateAvailableCameras(_ service: CameraService) {
        updateCameraState()
    }
}

