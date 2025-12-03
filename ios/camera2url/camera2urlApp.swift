//
//  camera2urlApp.swift
//  camera2url
//
//  Created by Manuel Kießling on 01.12.25.
//

import Camera2URLShared
import SwiftUI

/// Type alias for the iOS-specific AppViewModel
typealias IOSAppViewModel = AppViewModel<CameraService>

@main
struct camera2urlApp: App {
    @StateObject private var viewModel: IOSAppViewModel

    init() {
        let store = ConfigStore()
        let camera = CameraService()
        _viewModel = StateObject(wrappedValue: IOSAppViewModel(configStore: store, cameraService: camera))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
    }
}
