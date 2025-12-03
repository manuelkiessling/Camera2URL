# Camera2URL Architecture and Code Design

This document provides an overview of the Camera2URL codebase architecture, helping developers understand the project structure, design patterns, and code organization.

## Project Overview

Camera2URL is a native camera application for iOS and macOS that captures photos and uploads them to a configurable HTTP endpoint. The app supports:

- Manual photo capture with immediate upload
- Automatic timed capture at configurable intervals
- Multiple camera selection (front/back on iOS, external/continuity on macOS)
- Upload history tracking with request/response details

## Repository Structure

```
camera2url/
├── shared/              # Shared Swift Package (cross-platform code)
├── ios/                 # iOS application
├── macos/               # macOS application
└── docs/                # Documentation
```

### Shared Package (`shared/`)

A Swift Package containing all platform-agnostic business logic:

```
shared/
├── Package.swift
├── Sources/Camera2URLShared/
│   ├── Models/          # Data models (RequestConfig, TimerConfig, etc.)
│   ├── Protocols/       # Platform abstraction protocols
│   ├── Services/        # Network services (UploadService)
│   ├── Stores/          # Persistence (ConfigStore)
│   ├── ViewModels/      # Main app state (AppViewModel)
│   └── PlatformImage.swift  # Cross-platform image typealias
└── Tests/
```

### Platform Apps (`ios/` and `macos/`)

Each platform app contains only platform-specific code:

```
{platform}/
├── camera2url.xcodeproj/
├── camera2url/
│   ├── Services/        # Platform-specific CameraService
│   ├── Views/           # SwiftUI views
│   ├── ContentView.swift
│   └── camera2urlApp.swift
└── camera2urlTests/
```

## Architecture Overview

### Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                        │
│                  (Platform-specific UI)                     │
├─────────────────────────────────────────────────────────────┤
│                       AppViewModel                          │
│              (Shared state management)                      │
├───────────────────────┬─────────────────────────────────────┤
│    CameraService      │         UploadService               │
│  (Platform-specific)  │          (Shared)                   │
├───────────────────────┴─────────────────────────────────────┤
│                    Models & Stores                          │
│                       (Shared)                              │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **Protocol-based abstraction for platform code**: The `CameraServiceProtocol` defines the camera interface, allowing the shared `AppViewModel` to work with platform-specific camera implementations.

2. **Generic ViewModel**: `AppViewModel` is generic over the camera service type, enabling type-safe platform-specific camera device handling while sharing all business logic.

3. **Platform image typealias**: `PlatformImage` resolves to `UIImage` on iOS and `NSImage` on macOS, enabling the ViewModel to work with images without platform conditionals.

## Code Sharing Strategy

### What's Shared (~60% of code)

| Component | Description |
|-----------|-------------|
| **Models** | All data structures (RequestConfig, TimerConfig, UploadRecord, etc.) |
| **UploadService** | HTTP multipart upload logic |
| **ConfigStore** | UserDefaults-based configuration persistence |
| **AppViewModel** | All app state, timer logic, upload orchestration |
| **Protocols** | CameraServiceProtocol, CameraDeviceInfo |

### What's Platform-Specific

| Component | Why Platform-Specific |
|-----------|----------------------|
| **CameraService** | Different device types (iOS: front/back cameras; macOS: external/continuity) |
| **CameraPreviewView** | UIViewRepresentable vs NSViewRepresentable |
| **Config UI** | iOS uses NavigationStack/Form; macOS uses dialog-style layout |
| **ContentView** | Different layouts, safe areas, window management |
| **UploadHistoryView** | iOS uses push navigation; macOS uses split view |

## Key Abstractions

### CameraServiceProtocol

Defines the contract for camera operations:

```swift
protocol CameraServiceProtocol {
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
```

### CameraServiceDelegate

Callback interface for camera events:

```swift
protocol CameraServiceDelegate {
    func cameraServiceDidCapturePhoto(_ data: Data)
    func cameraServiceDidEncounterError(_ error: Error)
    func cameraServiceDidUpdateAvailableCameras()
}
```

### AppViewModel

The central state manager, generic over the camera service:

```swift
class AppViewModel<CameraService: CameraServiceProtocol>: ObservableObject {
    // Published state for UI binding
    @Published var uploadStatus: UploadStatus
    @Published var isTimerActive: Bool
    @Published var capturedPhoto: CapturedPhoto?
    // ... etc
}
```

## Data Flow

### Manual Capture Flow

```
User taps "Take Photo"
    → AppViewModel.takeAndSendPhoto()
        → CameraService.capturePhoto()
            → [AVFoundation captures image]
                → CameraServiceDelegate.cameraServiceDidCapturePhoto(data)
                    → AppViewModel creates PlatformImage
                        → UploadService.upload(photoData:using:)
                            → [HTTP request]
                                → UploadHistory.addSuccess/addFailure()
                                    → UI updates via @Published
```

### Timer Capture Flow

```
User starts timer
    → AppViewModel.startTimer()
        → Task loop with configurable interval
            → captureTimerPhoto() [immediate + repeated]
                → CameraService.capturePhoto()
                    → Upload runs in background Task
                        → UploadHistory tracks results
```

## State Management

The app uses SwiftUI's native state management:

- **@StateObject**: App-level ViewModel instance (in App struct)
- **@ObservedObject**: ViewModel reference in views
- **@Published**: Observable state properties in ViewModel
- **@State**: View-local UI state (sheets, selections)

### Key State Properties

| Property | Purpose |
|----------|---------|
| `showingConfigSheet` | Controls config sheet/dialog presentation |
| `currentConfig` | Active upload target configuration |
| `uploadStatus` | Current upload state (idle/capturing/uploading/success/failure) |
| `isCameraReady` | Camera session prepared and running |
| `isTimerActive` | Auto-capture timer running |
| `uploadHistory` | Rolling history of upload attempts |

## Persistence

### ConfigStore

Persists request configurations to UserDefaults as JSON. Implements:

- **Upsert**: Add new or move existing config to front
- **Deduplication**: Matches by verb + URL + note
- **Auto-persist**: Saves on every mutation

### Upload History

In-memory rolling buffer (max 100 records) tracking:

- Success/failure status
- Request/response summaries
- Timestamp and capture number
- Manual vs timer capture flag

## Error Handling

Errors are modeled as structured types:

- **CameraError**: Permission denied, configuration failed, no camera found, capture failed
- **UploadErrorReport**: Network errors, HTTP errors, includes request/response summaries for debugging

Errors flow through the delegate pattern (camera) or are thrown and caught (upload), then surfaced to the UI via `uploadStatus`.

## Testing Strategy

### Shared Package Tests

Located in `shared/Tests/`, these test:

- ConfigStore persistence and deduplication
- TimerConfig value clamping
- UploadService request building and error handling
- UploadHistory record management

### Platform Tests

Each platform has a `camera2urlTests` target that imports the shared package and can test platform-specific behavior.

### Running Tests

```bash
# Shared package tests
cd shared && swift test

# iOS tests
cd ios && make test

# macOS tests
cd macos && make test
```

## Build System

Each platform uses:

- **Xcode project** with the shared package as a local dependency
- **Makefile** for common operations (`make build`, `make test`, `make ui-test`)
- **File system synchronized groups** for automatic source file inclusion

### Adding the Shared Package

Both Xcode projects reference the shared package via local path (`../shared`). The package is automatically resolved and linked.

## Future Considerations

When extending the codebase:

1. **New shared logic**: Add to the shared package under appropriate directory
2. **New platform-specific feature**: Implement in each platform app
3. **New camera capability**: Extend CameraServiceProtocol and both implementations
4. **New model**: Add to shared/Models with public access modifiers
5. **New UI**: Implement separately per platform, sharing ViewModel interactions
