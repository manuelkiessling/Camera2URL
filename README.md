# Camera2URL

A macOS desktop app that captures photos from your Mac's camera and uploads them to a configurable HTTP endpoint. Perfect for automated photo capture workflows, time-lapse photography with remote storage, and webhook-based photo integrations.

## Features

### Photo Capture & Upload
- Configure HTTP verb (GET, POST, PUT, PATCH, DELETE), URL, and optional note
- Reuse previously configured endpoints from a dropdown
- Live camera preview with real-time feed
- One-click photo capture and upload
- Photos uploaded as multipart/form-data file attachments

### Camera Support
- Built-in Mac camera support
- **Continuity Camera** - use your iPhone as a wireless camera
- Switch between multiple cameras when available
- Automatic camera detection when devices connect/disconnect

### Timer Mode
- Automated photo capture at configurable intervals
- Supports seconds, minutes, hours, or days
- Live thumbnail preview of latest captured photo
- Upload status tracking with success/failure counts
- Upload history window showing last 100 attempts with full request/response details

### Error Handling
- Detailed success/failure reporting
- Full HTTP request and response details for debugging
- Persistent configuration storage across app launches

## Requirements

- macOS 15.7+
- Xcode 26.1+ (with Swift 6) for building

## Building and Testing

### Build via Command Line

```bash
xcodebuild -scheme camera2url -configuration Debug build
```

### Run Unit Tests

```bash
xcodebuild -scheme camera2url -configuration Debug test -destination 'platform=macOS,arch=arm64'
```

### Run UI Tests

```bash
xcodebuild -scheme camera2urlUITests -configuration Debug test -destination 'platform=macOS,arch=arm64'
```

UI tests launch the app in a separate automation runner and require camera permission to be granted in an interactive desktop session.

### Run All Tests

```bash
xcodebuild -scheme camera2url -configuration Debug test -destination 'platform=macOS,arch=arm64'
```

### Build via Xcode

1. Open `camera2url.xcodeproj` in Xcode
2. Select the `camera2url` scheme
3. Press ⌘B to build or ⌘R to run
4. Press ⌘U to run all tests

## Project Structure

```
camera2url/
├── Models/
│   ├── RequestConfig.swift       # HTTP verb, URL, note configuration
│   ├── UploadModels.swift        # Upload result types
│   ├── TimerConfig.swift         # Timer interval configuration
│   └── TimerUploadRecord.swift   # Timer upload history tracking
├── Services/
│   ├── CameraService.swift       # AVFoundation camera handling
│   └── UploadService.swift       # HTTP multipart upload
├── Stores/
│   └── ConfigStore.swift         # UserDefaults persistence
├── ViewModels/
│   └── AppViewModel.swift        # Main app state coordination
├── Views/
│   ├── CameraPreviewView.swift   # NSViewRepresentable camera preview
│   └── ConfigDialogView.swift    # Configuration dialog
├── ContentView.swift             # Main app view
└── camera2urlApp.swift           # App entry point
```

## Permissions

The app requires the following permissions (configured in entitlements):

- **Camera access** (`com.apple.security.device.camera`) - to capture photos
- **Network access** (`com.apple.security.network.client`) - to upload photos to configured endpoints

## License

Copyright © 2025 Manuel Kießling. All rights reserved.
