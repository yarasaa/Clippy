//
//  ClippyApp.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 17.09.2025.
//


import SwiftUI

@main
struct ClippyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = SettingsManager.shared

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(settings)
        }
    }
}
