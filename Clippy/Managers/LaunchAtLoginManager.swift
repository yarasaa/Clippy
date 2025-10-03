//
//  LaunchAtLoginManager.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 17.09.2025.
//

import Foundation
import ServiceManagement
import Combine

class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published var isEnabled: Bool = false {
        didSet {
            updateLaunchAtLoginStatus()
        }
    }

    private init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
        
        if UserDefaults.standard.object(forKey: "hasSetLaunchAtLogin") == nil {
            self.isEnabled = true
            UserDefaults.standard.set(true, forKey: "hasSetLaunchAtLogin")
        }
    }

    private func updateLaunchAtLoginStatus() {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login status: \(error)")
            DispatchQueue.main.async {
                self.isEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }
}