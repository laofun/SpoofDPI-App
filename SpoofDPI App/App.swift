//
//  App.swift
//  SpoofDPI App
//

import SwiftUI

@main
struct App: SwiftUI.App {
    @NSApplicationDelegateAdaptor(Delegate.self) private var delegate
    
    var body: some Scene {
        MainScene()
    }
}

private extension App {
    final class Delegate: NSObject, NSApplicationDelegate {
        func applicationDidFinishLaunching(_ notification: Notification) {
            _ = AutoLaunchService.instance
            _ = MenuBarIconService.instance
            _ = ProtectionService.instance
            _ = UpdateService.instance
            _ = WindowService.instance
        }
        
        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
            return false
        }
        
        func applicationWillTerminate(_ notification: Notification) {
            ProtectionService.instance.prepareForTermination()
        }
    }
}
