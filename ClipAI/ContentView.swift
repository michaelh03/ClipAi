//
//  ContentView.swift
//  ClipAI
//
//  Created by Michael Hait on 29/07/2025.
//

import SwiftUI

struct ContentView: View {
    private let clipboardStore: ClipboardStore
    @StateObject private var viewModel: PopupViewModel
    
    init() {
        let store = ClipboardStore()
        self.clipboardStore = store
        let generalSettings = GeneralSettingsViewModel()
        _viewModel = StateObject(wrappedValue: PopupViewModel(clipboardStore: store, generalSettingsViewModel: generalSettings))
    }
    
    var body: some View {
        PopupView(viewModel: viewModel)
            .onAppear {
                clipboardStore.startMonitoring()
            }
            .onDisappear {
                clipboardStore.stopMonitoring()
            }
    }
}

#Preview {
    ContentView()
}
