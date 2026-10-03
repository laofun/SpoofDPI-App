//
//  MainScene.ContentView.swift
//  SpoofDPI App
//

import SwiftUI

extension MainScene {
    struct ContentView: View {
        private typealias LocalizedString = SpoofDPI_App.LocalizedString.Scene.Main
        
        @ObservedObject private var protectionService = ProtectionService.instance
        @ObservedObject private var settingsService = SettingsService.instance
        
        @State private var areSettingsVisible = false
        
        @State private var settingsLibraryParameters = ""
        @State private var settingsLibraryParametersTextFieldID = 0
        
        var body: some View {
            VStack(spacing: 14) {
                HStack {
                    let settingsSymbol = SystemSymbol.gearshape
                    
                    Toggle(LocalizedString.protectionToggle, isOn: $settingsService.isProtectionEnabled)
                        .toggleStyle(.switch)
                    
                    Button("", systemImage: settingsSymbol.name) {
                        settingsLibraryParameters = settingsService.libraryParameters
                        areSettingsVisible = true
                    }
                    .buttonStyle(.borderless)
                    .padding(.bottom, 4)
                    .alert("", isPresented: $areSettingsVisible) {
                        let fixLibraryParametersTextFieldInitialStates = {
                            // Fixes a mysterious SwiftUI bug
                            settingsLibraryParametersTextFieldID += 1
                        }
                        
                        TextField(
                            LocalizedString.SettingsAlert.libraryParameters,
                            text: $settingsLibraryParameters
                        )
                        .autocorrectionDisabled()
                        .id(settingsLibraryParametersTextFieldID)
                        
                        Button(LocalizedString.SettingsAlert.Buttons.save) {
                            settingsService.libraryParameters = settingsLibraryParameters
                            
                            areSettingsVisible = false
                            fixLibraryParametersTextFieldInitialStates()
                        }
                        
                        Button(LocalizedString.SettingsAlert.Buttons.editConfig) {
                            openConfigFile()

                            areSettingsVisible = false
                            fixLibraryParametersTextFieldInitialStates()
                        }

                        Button(LocalizedString.SettingsAlert.Buttons.cancel) {
                            areSettingsVisible = false
                            fixLibraryParametersTextFieldInitialStates()
                        }
                    }
                    .dialogIcon(
                        .init(nsImage: settingsSymbol.image)
                    )
                }
                
                switch protectionService.status {
                    case .active:
                        HStack(spacing: 6) {
                            Text("😎")
                            
                            Text(LocalizedString.Status.active)
                                .bold()
                        }
                        .padding(.top, -8)
                        
                    case .initializing:
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                
                                Text(LocalizedString.Status.initialization)
                            }
                            
                            Text(LocalizedString.vpnHint)
                                .bold()
                        }
                        
                    case .stopped, .unknown:
                        EmptyView()
                }
                
                VStack {
                    Toggle(LocalizedString.Toggles.automaticLaunch, isOn: $settingsService.isAutomaticLaunchEnabled)
                    Toggle(LocalizedString.Toggles.menuBarIcon, isOn: $settingsService.isMenuBarIconEnabled)
                }
            }
            .fixedSize()
            .padding()
        }

        private func openConfigFile() {
            let url = Constants.libraryConfigURL

            if !FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? """
                # SpoofDPI config: https://spoofdpi.xvzc.dev/user-guide/rules/
                # Toggle DPI protection off and on to apply changes.
                # Avoid fake-count: it needs root (pcap) and stops the proxy from starting.

                # [[rules]]
                # name = "example"
                # priority = 50
                # match = { domains = ["example.com", "*.example.com"] }
                # https = { disorder = true, split-mode = "chunk", chunk-size = 1 }

                """.write(to: url, atomically: true, encoding: .utf8)
            }

            // .toml usually has no default app, so fall back to TextEdit
            let editorURL = NSWorkspace.shared.urlForApplication(toOpen: url)
                ?? URL(filePath: "/System/Applications/TextEdit.app")
            NSWorkspace.shared.open([url], withApplicationAt: editorURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

#Preview {
    MainScene.ContentView()
}
