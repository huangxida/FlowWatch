//
//  LaunchAtLoginManager.swift
//  FlowWatch
//
//  Created by FlowWatch Assistant on 2026/01/09.
//

import Foundation
import ServiceManagement
import AppKit

@MainActor
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    private let hasPromptedKey = "LaunchAtLogin.hasPrompted"
    
    // 仅支持 macOS 13.0+
    @available(macOS 13.0, *)
    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    @available(macOS 13.0, *)
    var isEnabled: Bool {
        status == .enabled
    }

    @available(macOS 13.0, *)
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status == .enabled { return }
            try SMAppService.mainApp.register()
        } else {
            if SMAppService.mainApp.status == .notRegistered { return }
            try SMAppService.mainApp.unregister()
        }
    }
    
    func checkAndPrompt() {
        guard #available(macOS 13.0, *) else { return }
        LogManager.shared.log("Check launch at login status")
        // 如果已经开启，无需提示
        if isEnabled { return }
        
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: hasPromptedKey) { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showPrompt()
        }
    }
    
    @available(macOS 13.0, *) 
    private func showPrompt() {
        let alert = NSAlert()
        alert.messageText = LocalizationManager.shared.t("launch.prompt.title")
        alert.informativeText = LocalizationManager.shared.t("launch.prompt.message")
        alert.addButton(withTitle: LocalizationManager.shared.t("launch.prompt.enable"))
        alert.addButton(withTitle: LocalizationManager.shared.t("launch.prompt.notNow"))
        
        // 确保弹窗在最前
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        LogManager.shared.log("Launch at login prompt response: \(response.rawValue)")
        
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: hasPromptedKey)
        
        if response == .alertFirstButtonReturn {
            // 允许
            do {
                try setEnabled(true)
                LogManager.shared.log("Launch at login enabled by user")
            } catch {
                LogManager.shared.log("Failed to enable launch at login: \(error)", level: .error)
            }
        }
    }
}
