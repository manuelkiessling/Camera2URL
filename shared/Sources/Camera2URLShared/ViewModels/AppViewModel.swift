//
//  AppViewModel.swift
//  Camera2URLShared
//

import AVFoundation
import Combine
import SwiftUI

@MainActor
public final class AppViewModel<CameraService: CameraServiceProtocol>: NSObject, ObservableObject {
    public enum UploadStatus: Equatable {
        case idle
        case capturing
        case uploading
        case success(UploadExchange)
        case failure(UploadErrorReport)
    }

    public struct CapturedPhoto: Identifiable {
        public let id = UUID()
        public let image: PlatformImage
        public let data: Data
        
        public init(image: PlatformImage, data: Data) {
            self.image = image
            self.data = data
        }
    }

    @Published public var showingConfigSheet: Bool = true
    @Published public private(set) var currentConfig: RequestConfig?
    @Published public private(set) var uploadStatus: UploadStatus = .idle
    @Published public private(set) var capturedPhoto: CapturedPhoto?
    @Published public private(set) var cameraError: String?
    @Published public private(set) var isCameraReady: Bool = false
    @Published public private(set) var availableCameras: [CameraService.CameraDeviceType] = []
    @Published public private(set) var currentCamera: CameraService.CameraDeviceType?
    
    // Timer mode state
    @Published public var timerConfig: TimerConfig = TimerConfig()
    @Published public private(set) var isTimerActive: Bool = false
    @Published public private(set) var timerCaptureCount: Int = 0
    @Published public private(set) var lastTimerPhoto: CapturedPhoto?
    @Published public private(set) var lastTimerCaptureTime: Date?
    @Published public private(set) var nextTimerCaptureTime: Date?
    @Published public private(set) var manualCaptureCount: Int = 0
    public let uploadHistory = UploadHistory()

    public let configStore: ConfigStore
    private let cameraService: CameraService
    private let uploadService: UploadService
    private var timerTask: Task<Void, Never>?
    private var isTimerCapture: Bool = false

    public var session: AVCaptureSession? {
        cameraService.session
    }
    
    public var hasMultipleCameras: Bool {
        availableCameras.count > 1
    }

    public init(
        configStore: ConfigStore,
        cameraService: CameraService,
        uploadService: UploadService = UploadService()
    ) {
        self.configStore = configStore
        self.cameraService = cameraService
        self.uploadService = uploadService
        showingConfigSheet = true
        currentConfig = configStore.configs.first
        super.init()
        self.cameraService.delegate = self
    }

    nonisolated public func cleanUp() {
        Task { @MainActor in
            cameraService.stop()
        }
    }

    public func handleConfigSubmitted(_ config: RequestConfig) {
        currentConfig = config
        showingConfigSheet = false
        Task {
            await prepareCameraIfNeeded()
        }
    }

    public func editConfig() {
        showingConfigSheet = true
    }

    public func prepareCameraIfNeeded() async {
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
    
    public func switchCamera(to camera: CameraService.CameraDeviceType) {
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

    public func stopCamera() {
        cameraService.stop()
        isCameraReady = false
    }

    public func takeAndSendPhoto() {
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

    public func resetForNextCapture() {
        capturedPhoto = nil
        uploadStatus = .idle
    }
    
    // MARK: - Timer Mode
    
    public func startTimer() {
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
        
        timerTask = Task {
            await runTimerLoop()
        }
    }
    
    public func stopTimer() {
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
    
    private func handleTimerCapture(photoData: Data, image: PlatformImage) {
        lastTimerPhoto = CapturedPhoto(image: image, data: photoData)
        lastTimerCaptureTime = Date()
        timerCaptureCount += 1
        
        let captureNumber = timerCaptureCount
        
        // Upload in background and track result
        guard let config = currentConfig else { return }
        Task {
            do {
                let exchange = try await uploadService.upload(photoData: photoData, using: config)
                uploadHistory.addSuccess(captureNumber: captureNumber, exchange: exchange, isTimerCapture: true)
            } catch {
                if let report = error as? UploadErrorReport {
                    uploadHistory.addFailure(captureNumber: captureNumber, error: report, isTimerCapture: true)
                } else {
                    uploadHistory.addFailure(captureNumber: captureNumber, message: error.localizedDescription, isTimerCapture: true)
                }
            }
        }
    }

    private func upload(photoData: Data, image: PlatformImage) {
        guard let config = currentConfig else { return }
        capturedPhoto = CapturedPhoto(image: image, data: photoData)
        uploadStatus = .uploading
        manualCaptureCount += 1
        let captureNumber = manualCaptureCount
        
        Task {
            do {
                let exchange = try await uploadService.upload(photoData: photoData, using: config)
                uploadStatus = .success(exchange)
                uploadHistory.addSuccess(captureNumber: captureNumber, exchange: exchange, isTimerCapture: false)
            } catch {
                if let report = error as? UploadErrorReport {
                    uploadStatus = .failure(report)
                    uploadHistory.addFailure(captureNumber: captureNumber, error: report, isTimerCapture: false)
                } else {
                    let report = UploadErrorReport(
                        message: error.localizedDescription,
                        requestSummary: "Request was not created.",
                        responseSummary: nil
                    )
                    uploadStatus = .failure(report)
                    uploadHistory.addFailure(captureNumber: captureNumber, message: error.localizedDescription, isTimerCapture: false)
                }
            }
        }
    }
}

extension AppViewModel: CameraServiceDelegate {
    public func cameraServiceDidCapturePhoto(_ data: Data) {
        guard let image = PlatformImage(data: data) else {
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

    public func cameraServiceDidEncounterError(_ error: Error) {
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
    
    public func cameraServiceDidUpdateAvailableCameras() {
        updateCameraState()
    }
}

