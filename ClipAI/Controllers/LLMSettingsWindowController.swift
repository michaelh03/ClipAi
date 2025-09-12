//
//  LLMSettingsWindowController.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import SwiftUI
import AppKit

/// NSWindowController for presenting the LLM settings window
class LLMSettingsWindowController: NSWindowController {
    private let generalSettingsViewModel: GeneralSettingsViewModel
    
    init(generalSettingsViewModel: GeneralSettingsViewModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.generalSettingsViewModel = generalSettingsViewModel
        
        super.init(window: window)
        
        setupWindow()
        setupContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "LLM Settings"
        window.center()
        window.setFrameAutosaveName("LLMSettingsWindow")
        window.isReleasedWhenClosed = false
        
        // Set minimum size
        window.minSize = NSSize(width: 450, height: 500)
        window.maxSize = NSSize(width: 600, height: 800)
    }
    
    private func setupContent() {
        guard let window = window else { return }
        
        let settingsView = LLMSettingsView(generalSettingsViewModel: generalSettingsViewModel)
        let hostingView = NSHostingView(rootView: settingsView)
        
        window.contentView = hostingView
    }
    
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}