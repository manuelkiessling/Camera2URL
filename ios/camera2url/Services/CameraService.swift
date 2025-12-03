//
//  CameraService.swift
//  camera2url
//

import AVFoundation
import Camera2URLShared
import Foundation

/// Represents an available camera device on iOS
struct CameraDevice: CameraDeviceInfo {
    let id: String
    let name: String
    let deviceType: AVCaptureDevice.DeviceType
    let position: AVCaptureDevice.Position
    
    var isUltraWide: Bool {
        deviceType == .builtInUltraWideCamera
    }
    
    var isTelephoto: Bool {
        deviceType == .builtInTelephotoCamera
    }
    
    var displayName: String {
        switch deviceType {
        case .builtInUltraWideCamera:
            return "Ultra Wide"
        case .builtInWideAngleCamera:
            return "Wide"
        case .builtInTelephotoCamera:
            return "Telephoto"
        default:
            return name
        }
    }
    
    var iconName: String {
        switch position {
        case .front:
            return "camera.rotate"
        default:
            switch deviceType {
            case .builtInUltraWideCamera:
                return "camera.aperture"
            case .builtInTelephotoCamera:
                return "scope"
            default:
                return "camera.fill"
            }
        }
    }
}

@MainActor
final class CameraService: NSObject, CameraServiceProtocol {
    typealias CameraDeviceType = CameraDevice
    
    enum CameraError: LocalizedError {
        case permissionDenied
        case configurationFailed
        case noCameraFound
        case captureFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Camera permission was denied. Enable camera access in Settings."
            case .configurationFailed:
                return "Unable to configure the camera session."
            case .noCameraFound:
                return "No compatible camera device was found."
            case .captureFailed:
                return "Unable to capture photo."
            }
        }
    }

    private(set) var session: AVCaptureSession?
    private(set) var availableCameras: [CameraDevice] = []
    private(set) var currentCamera: CameraDevice?
    
    weak var delegate: CameraServiceDelegate?

    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private let discoverySession: AVCaptureDevice.DiscoverySession

    override init() {
        // Discover all video devices on iOS including front/back cameras
        self.discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera
            ],
            mediaType: .video,
            position: .unspecified
        )
        super.init()
        
        refreshAvailableCameras()
        setupDeviceNotifications()
    }

    func prepareIfNeeded() async throws {
        try await ensureAuthorization()
        if !isConfigured {
            try configureSession()
            isConfigured = true
        }
    }

    func start() {
        guard let session = session else { return }
        if !session.isRunning {
            session.startRunning()
        }
    }

    func stop() {
        guard let session = session else { return }
        if session.isRunning {
            session.stopRunning()
        }
    }

    func capturePhoto() {
        guard isConfigured else {
            delegate?.cameraServiceDidEncounterError(CameraError.configurationFailed)
            return
        }

        let settings = AVCapturePhotoSettings()
        if photoOutput.maxPhotoDimensions.width > 0 {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    /// Switch to a different camera
    func switchCamera(to camera: CameraDevice) throws {
        guard let session = session else {
            throw CameraError.configurationFailed
        }
        
        guard let device = AVCaptureDevice(uniqueID: camera.id) else {
            throw CameraError.noCameraFound
        }
        
        let newInput = try AVCaptureDeviceInput(device: device)
        
        session.beginConfiguration()
        
        // Remove current input
        if let currentInput = currentInput {
            session.removeInput(currentInput)
        }
        
        // Add new input
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            currentInput = newInput
            currentCamera = camera
        } else {
            // Restore previous input if we can't add the new one
            if let currentInput = currentInput, session.canAddInput(currentInput) {
                session.addInput(currentInput)
            }
            session.commitConfiguration()
            throw CameraError.configurationFailed
        }
        
        session.commitConfiguration()
    }

    private func ensureAuthorization() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                throw CameraError.permissionDenied
            }
        default:
            throw CameraError.permissionDenied
        }
    }

    private func configureSession() throws {
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Use the back wide-angle camera by default on iOS
        let device: AVCaptureDevice?
        if let backWide = availableCameras.first(where: { 
            $0.position == .back && $0.deviceType == .builtInWideAngleCamera 
        }),
           let dev = AVCaptureDevice(uniqueID: backWide.id) {
            device = dev
            currentCamera = backWide
        } else if let firstCamera = availableCameras.first,
                  let dev = AVCaptureDevice(uniqueID: firstCamera.id) {
            device = dev
            currentCamera = firstCamera
        } else {
            device = AVCaptureDevice.default(for: .video)
            if let dev = device {
                currentCamera = CameraDevice(
                    id: dev.uniqueID,
                    name: dev.localizedName,
                    deviceType: dev.deviceType,
                    position: dev.position
                )
            }
        }
        
        guard let device = device else {
            throw CameraError.noCameraFound
        }

        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        } else {
            throw CameraError.configurationFailed
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            throw CameraError.configurationFailed
        }

        session.commitConfiguration()
        self.session = session
    }
    
    private func refreshAvailableCameras() {
        availableCameras = discoverySession.devices.map { device in
            CameraDevice(
                id: device.uniqueID,
                name: device.localizedName,
                deviceType: device.deviceType,
                position: device.position
            )
        }
    }
    
    private func setupDeviceNotifications() {
        // Observe when devices are connected/disconnected
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWasConnected),
            name: AVCaptureDevice.wasConnectedNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWasDisconnected),
            name: AVCaptureDevice.wasDisconnectedNotification,
            object: nil
        )
    }
    
    @objc private func deviceWasConnected(_ notification: Notification) {
        handleDeviceChange()
    }
    
    @objc private func deviceWasDisconnected(_ notification: Notification) {
        handleDeviceChange()
    }
    
    private func handleDeviceChange() {
        refreshAvailableCameras()
        delegate?.cameraServiceDidUpdateAvailableCameras()
        
        // If current camera was disconnected, switch to first available
        if let current = currentCamera,
           !availableCameras.contains(where: { $0.id == current.id }),
           let firstCamera = availableCameras.first {
            try? switchCamera(to: firstCamera)
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            delegate?.cameraServiceDidEncounterError(error)
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            delegate?.cameraServiceDidEncounterError(CameraError.captureFailed)
            return
        }

        delegate?.cameraServiceDidCapturePhoto(data)
    }
}
