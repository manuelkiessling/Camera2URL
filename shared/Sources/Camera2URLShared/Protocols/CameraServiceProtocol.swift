//
//  CameraServiceProtocol.swift
//  Camera2URLShared
//

import AVFoundation
import Foundation

/// Protocol for camera device information needed by the ViewModel
public protocol CameraDeviceInfo: Identifiable, Equatable, Sendable {
    var id: String { get }
    var name: String { get }
    var displayName: String { get }
    var iconName: String { get }
}

/// Delegate protocol for camera service events
@MainActor
public protocol CameraServiceDelegate: AnyObject {
    func cameraServiceDidCapturePhoto(_ data: Data)
    func cameraServiceDidEncounterError(_ error: Error)
    func cameraServiceDidUpdateAvailableCameras()
}

/// Protocol defining camera service interface for cross-platform use
@MainActor
public protocol CameraServiceProtocol: AnyObject {
    associatedtype CameraDeviceType: CameraDeviceInfo
    
    var session: AVCaptureSession? { get }
    var availableCameras: [CameraDeviceType] { get }
    var currentCamera: CameraDeviceType? { get }
    var delegate: CameraServiceDelegate? { get set }
    
    func prepareIfNeeded() async throws
    func start()
    func stop()
    func capturePhoto()
    func switchCamera(to camera: CameraDeviceType) throws
}

