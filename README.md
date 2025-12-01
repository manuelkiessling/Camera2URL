# camera2url

A macOS desktop app that captures photos from your Mac's camera and uploads them to a configurable HTTP endpoint.

## Features

- Configure HTTP verb (GET, POST, PUT, PATCH, DELETE), URL, and optional note
- Reuse previously configured endpoints from a dropdown
- Live camera preview
- One-click photo capture and upload
- Detailed success/failure reporting with full HTTP request/response details
- Persistent configuration storage

## Requirements

- macOS 15.7+
- Xcode 26.1+ (with Swift 6)

## Building and Testing

### Build via Command Line

```bash
xcodebuild -scheme camera2url -configuration Debug build
```

### Run Unit Tests

```bash
xcodebuild -scheme camera2url -configuration Debug test -only-testing:camera2urlTests
```

### Run UI Tests

```bash
xcodebuild -scheme camera2url -configuration Debug test -only-testing:camera2urlUITests
```

UI tests launch the app and interact with it automatically. They require camera permission to be granted.

### Run All Tests

```bash
xcodebuild -scheme camera2url -configuration Debug test
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
│   ├── RequestConfig.swift      # HTTP verb, URL, note configuration
│   └── UploadModels.swift       # Upload result types
├── Services/
│   ├── CameraService.swift      # AVFoundation camera handling
│   └── UploadService.swift      # HTTP multipart upload
├── Stores/
│   └── ConfigStore.swift        # UserDefaults persistence
├── ViewModels/
│   └── AppViewModel.swift       # Main app state coordination
├── Views/
│   ├── CameraPreviewView.swift  # NSViewRepresentable camera preview
│   └── ConfigDialogView.swift   # Configuration dialog
├── ContentView.swift            # Main app view
└── camera2urlApp.swift          # App entry point
```

## Permissions

The app requires:
- **Camera access** - to capture photos
- **Network access** - to upload photos to configured endpoints

