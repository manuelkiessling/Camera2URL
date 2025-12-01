# Complete camera2url Implementation

## Current State

The codebase has a solid foundation with all major components implemented:

- Config dialog with verb/URL/note fields and history dropdown
- ConfigStore with UserDefaults persistence and idempotent upsert
- CameraService with AVFoundation photo capture
- UploadService with multipart/form-data file upload
- Full success/failure UI with detailed request/response reporting
- Unit tests for ConfigStore and UploadService

## Outstanding Issues

### 1. Missing Entitlements File (Critical)

App Sandbox is enabled (`ENABLE_APP_SANDBOX = YES`) but no `.entitlements` file exists. The app will fail at runtime when accessing camera or network.

**Fix:** Create `camera2url/camera2url.entitlements` with:

- `com.apple.security.device.camera` - camera access
- `com.apple.security.network.client` - outbound HTTP requests

Then reference it in the Xcode project build settings.

### 2. Config Dialog Should Always Show on Launch

In [camera2url/ViewModels/AppViewModel.swift](camera2url/ViewModels/AppViewModel.swift), line 49:

```swift
showingConfigDialog = configStore.configs.isEmpty
```

**Fix:** Change to `showingConfigDialog = true` so dialog appears on every launch.

### 3. Hide Empty History Picker (Minor UX)

The "Reuse previous" picker in [camera2url/Views/ConfigDialogView.swift](camera2url/Views/ConfigDialogView.swift) shows even when there are no stored configs, displaying only "New entry".

**Fix:** Conditionally hide the picker when `configStore.configs.isEmpty`.

## Files to Modify

| File | Change |

|------|--------|

| `camera2url/camera2url.entitlements` | Create new file with camera + network entitlements |

| `camera2url.xcodeproj/project.pbxproj` | Add entitlements file reference and build setting |

| `camera2url/ViewModels/AppViewModel.swift` | Set `showingConfigDialog = true` |

| `camera2url/Views/ConfigDialogView.swift` | Hide "Reuse previous" picker when empty |
