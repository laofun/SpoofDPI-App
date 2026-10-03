//
//  Constants.swift
//  SpoofDPI App
//

import Foundation

enum Constants {
    static let defaultLanguage = Locale.SupportedLanguage.english
    static let updatesCheckingFrequency: TimeInterval = 259200 // 3 days
    
    static let repositoryURL = URL(string: "https://github.com/laofun/SpoofDPI-App")!
    static let actualBuildNumberURL = URL(string: "https://raw.githubusercontent.com/laofun/SpoofDPI-App/main/Other/ActualBuildNumber.txt")!
    
    static let supportEmailAddress = "SpoofDPIApp@proton.me"
    static let supportEmailURL = URL(string: "mailto:" + supportEmailAddress)!
    
    static let libraryProcessName = "spoofdpi-arm"
    static let libraryVersion = "1.5.4"
    // Since 1.x the system proxy is opt-in and a TUI is shown by default
    static let libraryDefaultParameters = "--no-tui --auto-configure-network"
}
