//
//  ClipAIApp.swift
//  ClipAI
//
//  Created by Michael Hait on 29/07/2025.
//

import SwiftUI
import AppKit
import QuartzCore

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var clipboardStore: ClipboardStore?
    private var popupController: PopupController?
    private var hotKeyListener: HotKeyListener?
    private var settingsWindowController: LLMSettingsWindowController?
    private var generalSettingsViewModel: GeneralSettingsViewModel?
    private var aiActivityCount: Int = 0
    private var spinnerLayer: CALayer?
    private var spinnerSymbolImage: NSImage?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize clipboard store and start monitoring
        clipboardStore = ClipboardStore()
        clipboardStore?.startMonitoring()
        
        // Initialize general settings view model
        generalSettingsViewModel = GeneralSettingsViewModel()
        
        // Initialize popup controller
        if let store = clipboardStore, let generalSettings = generalSettingsViewModel {
            popupController = PopupController(clipboardStore: store, generalSettingsViewModel: generalSettings)
            
            // Initialize hotkey listener with popup controller
            if let popup = popupController {
                hotKeyListener = HotKeyListener(popupController: popup)
                // Load persisted shortcuts or defaults
                let showSpec = SettingsStorage.loadShortcut(for: .showShortcut) ?? HotKeyListener.defaultShowShortcut
                
                // Handle migration from legacy one-click shortcut to action 1
                let oneClick1Spec: ShortcutSpec
                if let legacySpec = SettingsStorage.loadShortcut(for: .oneClickShortcut) {
                    // Migrate legacy shortcut to action 1
                    oneClick1Spec = legacySpec
                    SettingsStorage.saveShortcut(legacySpec, for: .oneClickShortcut1)
                    // Remove legacy key
                    UserDefaults.standard.removeObject(forKey: GeneralSettingsKeys.oneClickShortcut.rawValue)
                } else {
                    oneClick1Spec = SettingsStorage.loadShortcut(for: .oneClickShortcut1) ?? HotKeyListener.defaultOneClickShortcut1
                }
                
                let oneClick2Spec = SettingsStorage.loadShortcut(for: .oneClickShortcut2) ?? HotKeyListener.defaultOneClickShortcut2
                let oneClick3Spec = SettingsStorage.loadShortcut(for: .oneClickShortcut3) ?? HotKeyListener.defaultOneClickShortcut3
                
                // Defer registration to next runloop to ensure system is ready
                DispatchQueue.main.async { [weak self] in
                    guard let listener = self?.hotKeyListener else { return }
                    listener.update(showShortcut: showSpec, oneClickShortcut1: oneClick1Spec, oneClickShortcut2: oneClick2Spec, oneClickShortcut3: oneClick3Spec)
                    listener.enable()
                }
                
                // Observe changes from settings
                NotificationCenter.default.addObserver(forName: .generalShortcutsChanged, object: nil, queue: .main) { [weak self] _ in
                    guard let self = self, let listener = self.hotKeyListener else { return }
                    let newShow = SettingsStorage.loadShortcut(for: .showShortcut) ?? HotKeyListener.defaultShowShortcut
                    let newOneClick1 = SettingsStorage.loadShortcut(for: .oneClickShortcut1) ?? HotKeyListener.defaultOneClickShortcut1
                    let newOneClick2 = SettingsStorage.loadShortcut(for: .oneClickShortcut2) ?? HotKeyListener.defaultOneClickShortcut2
                    let newOneClick3 = SettingsStorage.loadShortcut(for: .oneClickShortcut3) ?? HotKeyListener.defaultOneClickShortcut3
                    listener.update(showShortcut: newShow, oneClickShortcut1: newOneClick1, oneClickShortcut2: newOneClick2, oneClickShortcut3: newOneClick3)
                }
            }
        }
        
        // Create status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set the status item button image and title
        if let statusButton: NSStatusBarButton = statusItem?.button {
            statusButton.image = NSImage(named: "clipboard-status")
            statusButton.image?.isTemplate = true // Ensures image is tinted by system
            statusButton.image?.size = NSSize(width: 18, height: 18)
            statusButton.imageScaling = .scaleProportionallyUpOrDown
            
            // Add click action to show popup
            statusButton.action = #selector(statusBarButtonClicked)
            statusButton.target = self
        }
        
        // Create the menu
        let menu = NSMenu()
        
        // Add Show ClipAI menu item
        let showItem = NSMenuItem(title: "Show ClipAI", action: #selector(showPopup), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add Settings menu item
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add About menu item
        let aboutItem = NSMenuItem(title: "About ClipAI", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add Quit menu item
        let quitItem = NSMenuItem(title: "Quit ClipAI", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Assign the menu to the status item (right-click menu)
        statusItem?.menu = menu
        
        // Hide the main window since this is a menu bar app
        NSApp.setActivationPolicy(.accessory)

        // Observe AI activity notifications to update status bar icon/animation
        NotificationCenter.default.addObserver(forName: .aiActivityDidStart, object: nil, queue: .main) { [weak self] _ in
            self?.incrementAIActivity()
        }
        NotificationCenter.default.addObserver(forName: .aiActivityDidFinish, object: nil, queue: .main) { [weak self] _ in
            self?.decrementAIActivity()
        }
    }
    
    @objc func statusBarButtonClicked() {
        // Show the popup when status bar icon is clicked
        popupController?.togglePopup()
    }
    
    @objc func showPopup() {
        popupController?.showPopup()
    }
    
    @objc func showSettings() {
        if settingsWindowController == nil, let generalSettings = generalSettingsViewModel {
            settingsWindowController = LLMSettingsWindowController(generalSettingsViewModel: generalSettings)
        }
        settingsWindowController?.showWindow()
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About ClipAI"
        alert.informativeText = "ClipAI - A smart clipboard manager for macOS\nVersion 1.0\n\nKeep your clipboard history at your fingertips."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func quitApp() {
        Task { @MainActor in
            clipboardStore?.stopMonitoring()
            hotKeyListener?.disable()
        }
        NSApplication.shared.terminate(nil)
    }

    // MARK: - AI Activity / Status Bar Animation
    private func incrementAIActivity() {
        aiActivityCount += 1
        updateStatusBarForAIActivity(isActive: aiActivityCount > 0)
    }
    
    private func decrementAIActivity() {
        aiActivityCount = max(0, aiActivityCount - 1)
        updateStatusBarForAIActivity(isActive: aiActivityCount > 0)
    }
    
    private func updateStatusBarForAIActivity(isActive: Bool) {
        guard let statusButton = statusItem?.button else { return }
        if isActive {
            let primarySymbol = NSImage(systemSymbolName: "arrow.trianglehead.2.clockwise.rotate.90", accessibilityDescription: "AI Processing")
            let fallbackSymbol = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "AI Processing")
            if let baseImage = (primarySymbol ?? fallbackSymbol) {
                let sizeConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                var configured = baseImage.withSymbolConfiguration(sizeConfig) ?? baseImage
                if let colorConfigured = configured.withSymbolConfiguration(.init(hierarchicalColor: .labelColor)) {
                    configured = colorConfigured
                    
                }
                
                
                spinnerSymbolImage = configured
                statusButton.image = nil
                startSpinning(statusButton)
            }
        } else {
            stopSpinning(statusButton)
            statusButton.image = NSImage(named: "clipboard-status")
            statusButton.image?.isTemplate = true
            statusButton.image?.size = NSSize(width: 18, height: 18)
        }
    }
    
    private func startSpinning(_ button: NSStatusBarButton) {
        guard let symbol = spinnerSymbolImage else { return }
        button.wantsLayer = true
        if button.layer == nil {
            button.layer = CALayer()
        }
        let backingScale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let size = CGSize(width: 18, height: 18)
        let cgImage = symbol.cgImage(forProposedRect: nil, context: nil, hints: nil)
        let layer: CALayer
        if let existing = spinnerLayer {
            layer = existing
        } else {
            let newLayer = CALayer()
            newLayer.bounds = CGRect(origin: .zero, size: size)
            newLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            newLayer.contentsGravity = .resizeAspect
            newLayer.contentsScale = backingScale
            newLayer.position = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
            spinnerLayer = newLayer
            button.layer?.addSublayer(newLayer)
            layer = newLayer
        }
        layer.contents = cgImage
        if layer.animation(forKey: "rotateAnimation") != nil { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = 1.0
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        layer.add(rotation, forKey: "rotateAnimation")
    }
    
    private func stopSpinning(_ button: NSStatusBarButton) {
        if let layer = spinnerLayer {
            layer.removeAnimation(forKey: "rotateAnimation")
            layer.removeFromSuperlayer()
            spinnerLayer = nil
        }
        spinnerSymbolImage = nil
    }
}

@main
struct ClipAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty WindowGroup that won't be shown - this is a menu bar only app
        WindowGroup {
            EmptyView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 0, height: 0)
        .windowResizability(.contentSize)
    }
}
