//
//  camera2urlApp.swift
//  camera2url
//
//  Created by Manuel Kießling on 01.12.25.
//

import Camera2URLShared
import SwiftUI

/// Type alias for the macOS-specific AppViewModel
typealias MacOSAppViewModel = AppViewModel<CameraService>

@main
struct camera2urlApp: App {
    @StateObject private var viewModel: MacOSAppViewModel

    init() {
        let store = ConfigStore()
        let camera = CameraService()
        _viewModel = StateObject(wrappedValue: MacOSAppViewModel(configStore: store, cameraService: camera))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        
        Window("Upload History", id: "upload-history") {
            UploadHistoryView(history: viewModel.uploadHistory)
        }
        .defaultSize(width: 900, height: 600)
    }
}
