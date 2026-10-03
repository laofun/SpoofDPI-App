//
//  ProtectionService.swift
//  SpoofDPI App
//

import Foundation
import Combine

final class ProtectionService: ObservableObject {
    static let instance = ProtectionService()
    
    @Published private(set) var status = Status.unknown
    
    private lazy var settingsService = SettingsService.instance
    
    private let fileManager = FileManager.default
    
    private var isEnabledObservation: AnyCancellable?
    private var libraryParametersObservation: AnyCancellable?
    
    private var libraryReactivationTimer: Timer?
    
    private init() {
        guard !ProcessInfo.isPreview else {
            return
        }
        
        updateStatus()
        
        isEnabledObservation = settingsService.$isProtectionEnabled.sink { [weak self] in
            guard let self else { return }
            
            if $0 {
                if libraryReactivationTimer == nil {
                    restartLibraryMaintaining()
                }
            } else {
                stopLibrary()
            }
        }
        
        libraryParametersObservation = settingsService.$libraryParameters.sink { [weak self] _ in
            guard let self else { return }
            
            switch status {
                case .active, .initializing:
                    restartLibraryMaintaining()
                    
                case .stopped, .unknown:
                    break
            }
        }
    }
    
    func prepareForTermination() {
        stopLibrary()
    }
    
    private func restartLibraryMaintaining() {
        let reactivateIfNeeded = { [weak self] in
            guard let self else {
                return
            }
            
            updateStatus()
            
            if status == .initializing {
                activateLibrary()
            }
        }
        
        stopLibrary()
        
        DispatchQueue.main.async {
            reactivateIfNeeded()
        }
        
        let reactivationTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            reactivateIfNeeded()
        }
        
        RunLoop.main.add(reactivationTimer, forMode: .common)
        self.libraryReactivationTimer = reactivationTimer
    }
    
    private func updateStatus() {
        if Utils.executeTerminalCommand("ps -A")?.contains(Constants.libraryProcessName) == true {
            status = .active
        } else {
            status = settingsService.isProtectionEnabled ? .initializing : .stopped
        }
    }
    
    private func activateLibrary() {
        guard let path = Bundle.main.path(forResource: Constants.libraryProcessName, ofType: "") else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let parameters = self.settingsService.libraryParameters
            // SpoofDPI refuses duplicated flags, so skip defaults the user already typed
            let defaultParameters = Constants.libraryDefaultParameters
                .split(separator: " ")
                .filter { !parameters.split(separator: " ").contains($0) }
                .joined(separator: " ")

            Utils.executeTerminalCommand(
                "\"\(path)\" " + defaultParameters + (!parameters.isEmpty ? " " + parameters : "")
            )
        }
    }
    
    private func stopLibrary() {
        libraryReactivationTimer?.invalidate()
        libraryReactivationTimer = nil
        
        Utils.executeTerminalCommand("killall " + Constants.libraryProcessName)
        
        status = .stopped
    }
}

extension ProtectionService {
    enum Status {
        case active
        case initializing
        case stopped
        
        case unknown
    }
}
