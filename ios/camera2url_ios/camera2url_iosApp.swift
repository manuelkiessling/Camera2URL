//
//  camera2url_iosApp.swift
//  camera2url_ios
//
//  Created by Manuel Kießling on 01.12.25.
//

import SwiftUI

@main
struct camera2url_iosApp: App {
    @StateObject private var viewModel: AppViewModel

    init() {
        let store = ConfigStore()
        _viewModel = StateObject(wrappedValue: AppViewModel(configStore: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
    }
}

