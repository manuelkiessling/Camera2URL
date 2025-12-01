//
//  CameraService.swift
//  camera2url
//

import AVFoundation
import Foundation

protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didCapturePhoto data: Data)
    func cameraService(_ service: CameraService, didEncounter error: Error)
}

@MainActor
final class CameraService: NSObject {
    enum CameraError: LocalizedError {
        case permissionDenied
        case configurationFailed
        case noCameraFound
        case captureFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Camera permission was denied. Enable camera access in System Settings."
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
    weak var delegate: CameraServiceDelegate?

    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false

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
            delegate?.cameraService(self, didEncounter: CameraError.configurationFailed)
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = photoOutput.isHighResolutionCaptureEnabled
        photoOutput.capturePhoto(with: settings, delegate: self)
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

        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraError.noCameraFound
        }

        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            throw CameraError.configurationFailed
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        } else {
            throw CameraError.configurationFailed
        }

        session.commitConfiguration()
        self.session = session
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            delegate?.cameraService(self, didEncounter: error)
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            delegate?.cameraService(self, didEncounter: CameraError.captureFailed)
            return
        }

        delegate?.cameraService(self, didCapturePhoto: data)
    }
}

