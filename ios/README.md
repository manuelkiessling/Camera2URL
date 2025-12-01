# Camera2URL for iOS [![iOS CI](https://github.com/manuelkiessling/camera2url/actions/workflows/ios-ci.yml/badge.svg?branch=main)](https://github.com/manuelkiessling/camera2url/actions/workflows/ios-ci.yml)

An iOS app that captures photos from your iPhone's camera and uploads them to a configurable HTTP endpoint. Perfect for automated photo capture workflows, time-lapse photography with remote storage, and webhook-based photo integrations.

## Features

### Photo Capture & Upload
- Configure HTTP verb (GET, POST, PUT, PATCH, DELETE), URL, and optional note
- Reuse previously configured endpoints from a picker
- Live camera preview with real-time feed
- One-tap photo capture and upload
- Photos uploaded as multipart/form-data file attachments

### Camera Support
- Front and back camera support
- Switch between Wide, Ultra Wide, and Telephoto lenses when available
- Automatic camera detection

### Timer Mode
- Automated photo capture at configurable intervals
- Supports seconds, minutes, hours, or days
- Live thumbnail preview of latest captured photo
- Upload status tracking with success/failure counts
- Upload history sheet showing last 100 attempts with full request/response details

### Error Handling
- Detailed success/failure reporting
- Full HTTP request and response details for debugging
- Persistent configuration storage across app launches

## Requirements

- iOS 17.0+
- Xcode 26.1+ (with Swift 6) for building

## Building and Testing

### Build via Command Line

```bash
make build
```

### Run Unit Tests

```bash
make test
```

Unit tests verify ConfigStore, TimerConfig, UploadService, and UploadHistory functionality.

### Run UI Tests

```bash
make ui-test
```

UI tests launch the app through the automation runner. They require an interactive session and camera permission.

### Run All Quality Checks

```bash
make quality
```

### Build via Xcode

1. Open `camera2url_ios.xcodeproj` in Xcode
2. Select the `camera2url_ios` scheme
3. Select an iOS Simulator or device
4. Press ⌘B to build or ⌘R to run
5. Press ⌘U to run all tests

## Project Structure

```
camera2url_ios/
├── Models/
│   ├── RequestConfig.swift       # HTTP verb, URL, note configuration
│   ├── UploadModels.swift        # Upload result types
│   ├── TimerConfig.swift         # Timer interval configuration
│   └── UploadRecord.swift        # Upload history tracking
├── Services/
│   ├── CameraService.swift       # AVFoundation camera handling
│   └── UploadService.swift       # HTTP multipart upload
├── Stores/
│   └── ConfigStore.swift         # UserDefaults persistence
├── ViewModels/
│   └── AppViewModel.swift        # Main app state coordination
├── Views/
│   ├── CameraPreviewView.swift   # UIViewRepresentable camera preview
│   ├── ConfigView.swift          # Configuration sheet
│   └── UploadHistoryView.swift   # Upload history sheet
├── ContentView.swift             # Main app view
└── camera2url_iosApp.swift       # App entry point
```

## Permissions

The app requires the following permissions:

- **Camera access** (`NSCameraUsageDescription`) - to capture photos
- **Network access** - to upload photos to configured endpoints

## License

Copyright © 2025 Manuel Kießling. All rights reserved.

