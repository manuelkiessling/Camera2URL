//
//  camera2urlApp.swift
//  camera2url
//
//  Created by Manuel Kießling on 01.12.25.
//

import SwiftUI

@main
struct camera2urlApp: App {
    @StateObject private var viewModel: AppViewModel

    init() {
        let store = ConfigStore()
        _viewModel = StateObject(wrappedValue: AppViewModel(configStore: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        
        Window("Upload History", id: "upload-history") {
            TimerHistoryView(history: viewModel.uploadHistory)
        }
        .defaultSize(width: 900, height: 600)
    }
}
