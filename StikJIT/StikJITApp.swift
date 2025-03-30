//
//  StikJITApp.swift
//  StikJIT
//
//  Created by Stephen on 3/26/25.
//

import SwiftUI
import UIKit

// LogManager class for managing and storing logs - only if not defined elsewhere
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    struct LogEntry: Identifiable {
        enum LogType: String {
            case info = "INFO"
            case error = "ERROR"
            case debug = "DEBUG"
            case warning = "WARNING"
        }
        
        let id = UUID()
        let timestamp: Date
        let type: LogType
        let message: String
    }
    
    @Published var logs: [LogEntry] = []
    @Published var errorCount: Int = 0
    
    func addInfoLog(_ message: String) {
        let entry = LogEntry(timestamp: Date(), type: .info, message: message)
        DispatchQueue.main.async {
            self.logs.append(entry)
        }
    }
    
    func addErrorLog(_ message: String) {
        let entry = LogEntry(timestamp: Date(), type: .error, message: message)
        DispatchQueue.main.async {
            self.logs.append(entry)
            self.errorCount += 1
        }
    }
    
    func addDebugLog(_ message: String) {
        let entry = LogEntry(timestamp: Date(), type: .debug, message: message)
        DispatchQueue.main.async {
            self.logs.append(entry)
        }
    }
    
    func addWarningLog(_ message: String) {
        let entry = LogEntry(timestamp: Date(), type: .warning, message: message)
        DispatchQueue.main.async {
            self.logs.append(entry)
        }
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.errorCount = 0
        }
    }
}

// Objective-C bridge for LogManager
@objc class LogManagerBridge: NSObject {
    @objc static let shared = LogManagerBridge()
    
    @objc func addInfoLog(_ message: String) {
        LogManager.shared.addInfoLog(message)
    }
    
    @objc func addErrorLog(_ message: String) {
        LogManager.shared.addErrorLog(message)
    }
    
    @objc func addDebugLog(_ message: String) {
        LogManager.shared.addDebugLog(message)
    }
    
    @objc func addWarningLog(_ message: String) {
        LogManager.shared.addWarningLog(message)
    }
}

// URL extension if not in Color.swift
extension URL {
    static var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

// Define ConnectionMode enum to match Objective-C
enum ConnectionMode: Int {
    case USB = 0
    case TCP = 1
}

// Function to check if Developer Disk Image is mounted
func isMounted() -> Bool {
    // This would check if the Developer Disk Image is mounted
    // For now, return true if there's a pairing file
    let fileManager = FileManager.default
    return fileManager.fileExists(atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path)
}

// Helper to start heartbeat in background
func startHeartbeatInBackground() {
    // Fixed: Use updated method name with Swift parameter syntax
    JITEnableContext.shared().startHeartbeat(completionHandler: { result, message in
        if result == 0 {
            LogManager.shared.addInfoLog("Heartbeat started successfully: \(message ?? "")")
        } else {
            LogManager.shared.addErrorLog("Failed to start heartbeat: \(message ?? "")")
        }
    }, logger: { message in
        if let message = message {
            LogManager.shared.addInfoLog(message)
        }
    })
}

// Helper for showing alerts
func showAlert(title: String, message: String, showOk: Bool, completion: @escaping (Bool) -> Void) {
    DispatchQueue.main.async {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if showOk {
            alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completion(true)
            })
        } else {
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completion(false)
            })
            alertController.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
                completion(true)
            })
        }
        
        // Fix deprecated UIApplication.shared.windows usage
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alertController, animated: true, completion: nil)
        }
    }
}

// Haptic feedback helper
class HapticFeedbackHelper {
    static func trigger() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MountingProgress for tracking Developer Disk Image mounting
class MountingProgress: ObservableObject {
    static let shared = MountingProgress()
    
    @Published var mountProgress: Double = 0
    
    private init() {}
    
    func updateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.mountProgress = progress
        }
    }
    
    func resetProgress() {
        DispatchQueue.main.async {
            self.mountProgress = 0
        }
    }
}

@main
struct StikJITApp: App {
    init() {
        // Initialize connection mode from user defaults on app launch
        let connectionMode = UserDefaults.standard.integer(forKey: "connectionMode")
        let mode: ConnectionMode = connectionMode == 0 ? .USB : .TCP
        JITEnableContext.shared().setConnectionMode(mode)

        
        // Add to logs
        LogManager.shared.addInfoLog("App started in \(connectionMode == 0 ? "USB" : "WiFi/WireGuard") mode")
        
        // Log app launch
        LogManager.shared.addInfoLog("StikJIT launched with iOS \(UIDevice.current.systemVersion)")
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
