//
//  SupportingClasses.swift
//  StikJIT
//
//  Created to provide required supporting classes for the USB implementation
//

import Foundation
import SwiftUI

// MARK: - InstalledAppsViewModel
class InstalledAppsViewModel: ObservableObject {
    @Published var apps: [String: String] = [:]
    
    init() {
        loadApps()
    }
    
    func loadApps() {
        do {
            self.apps = try JITEnableContext.shared().getAppList()
        } catch {
            print(error)
            self.apps = [:]
        }
    }
}

// MARK: - LogManager
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

// MARK: - LogManagerBridge
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

// MARK: - MountingProgress
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

// MARK: - Helper Functions
func isMounted() -> Bool {
    // This would check if the Developer Disk Image is mounted
    // For now, return true if there's a pairing file
    let fileManager = FileManager.default
    return fileManager.fileExists(atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path)
}

func startHeartbeatInBackground() {
    // Start the heartbeat process in the background
    DispatchQueue.global(qos: .background).async {
        JITEnableContext.shared().startHeartbeatWithCompletionHandler({ result, message in
            DispatchQueue.main.async {
                if result == 0 {
                    LogManager.shared.addInfoLog("Heartbeat started successfully: \(message)")
                } else {
                    LogManager.shared.addErrorLog("Failed to start heartbeat: \(message)")
                }
            }
        }, logger: { message in
            if let message = message {
                LogManager.shared.addInfoLog(message)
            }
        })
    }
}

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
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alertController, animated: true, completion: nil)
        }
    }
}

// MARK: - Color Extensions
extension Color {
    static let primaryBackground = Color(UIColor.systemBackground)
    static let secondaryText = Color(UIColor.secondaryLabel)
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != 1.0 {
            return String(format: "#%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
    
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }
        
        if hexString.count != 6 && hexString.count != 8 {
            return nil
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)
        
        let r, g, b, a: CGFloat
        
        if hexString.count == 6 {
            r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgbValue & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgbValue & 0x000000FF) / 255.0
        }
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - ConsoleLogsView
struct ConsoleLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logManager = LogManager.shared
    @State private var autoScroll = true
    @State private var scrollView: ScrollViewProxy? = nil
    
    // Alert handling
    @State private var showingExportAlert = false
    @State private var showingCopyAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Terminal logs area
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // Device Information
                                ForEach(["Version: \(UIDevice.current.systemVersion)",
                                         "Name: \(UIDevice.current.name)",
                                         "Model: \(UIDevice.current.model)",
                                         "StikJIT Version: 1.0"], id: \.self) { info in
                                    Text("[\(timeString())] ℹ️ \(info)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 4)
                                }
                                
                                Spacer()
                                
                                // Log entries 
                                ForEach(logManager.logs) { logEntry in
                                    Text(createLogAttributedString(logEntry))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(colorForLogType(logEntry.type))
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 1)
                                        .padding(.horizontal, 4)
                                        .id(logEntry.id)
                                }
                            }
                        }
                        .onAppear {
                            scrollView = proxy
                        }
                        .onChange(of: logManager.logs.count) { _ in
                            if autoScroll, let lastLog = logManager.logs.last {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        // Error count with red theme
                        HStack {
                            Text("\(logManager.errorCount) Critical Errors.")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Action buttons with dark background
                        VStack(spacing: 1) {
                            // Export button
                            Button(action: {
                                exportLogs()
                            }) {
                                HStack {
                                    Text("Export Logs")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "square.and.arrow.down")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                                .contentShape(Rectangle())
                            }
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                            
                            Divider()
                                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                            
                            // Copy button
                            Button(action: {
                                copyLogs()
                            }) {
                                HStack {
                                    Text("Copy Logs")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                                .contentShape(Rectangle())
                            }
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                        }
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Console Logs")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Settings")
                                .fontWeight(.regular)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        logManager.clearLogs()
                    }) {
                        Text("Clear")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(alertTitle, isPresented: $showingExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert(alertTitle, isPresented: $showingCopyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // Creates a formatted string for logs
    private func createLogAttributedString(_ logEntry: LogManager.LogEntry) -> String {
        return "[\(formatTime(date: logEntry.timestamp))] [\(logEntry.type.rawValue)] \(logEntry.message)"
    }
    
    // Helper to display current time
    private func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    // Helper to format Date objects to time strings
    private func formatTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // Return color based on log type
    private func colorForLogType(_ type: LogManager.LogEntry.LogType) -> Color {
        switch type {
        case .info:
            return .green
        case .error:
            return .red
        case .debug:
            return .blue
        case .warning:
            return .orange
        }
    }
    
    // Export logs to a file
    private func exportLogs() {
        // Create logs content with device information
        var logsContent = "=== DEVICE INFORMATION ===\n"
        logsContent += "Version: \(UIDevice.current.systemVersion)\n"
        logsContent += "Name: \(UIDevice.current.name)\n" 
        logsContent += "Model: \(UIDevice.current.model)\n"
        logsContent += "StikJIT Version: App Version: 1.0\n\n"
        logsContent += "=== LOG ENTRIES ===\n"
        
        // Add all log entries with proper formatting
        logsContent += logManager.logs.map { 
            "[\(formatTime(date: $0.timestamp))] [\($0.type.rawValue)] \($0.message)" 
        }.joined(separator: "\n")
        
        // Save to document directory (accessible in Files app)
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileURL = documentsDirectory.appendingPathComponent("StikJIT_Logs_\(timestamp).txt")
        
        do {
            // Write the logs to the file
            try logsContent.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Set alert variables and show the alert
            alertTitle = "Logs Exported"
            alertMessage = "Logs have been saved to Files app in StikJIT folder."
            isError = false
            showingExportAlert = true
        } catch {
            // Set error alert variables and show the alert
            alertTitle = "Export Failed"
            alertMessage = "Failed to save logs: \(error.localizedDescription)"
            isError = true
            showingExportAlert = true
        }
    }
    
    // Copy logs to clipboard
    private func copyLogs() {
        // Create logs content with device information
        var logsContent = "=== DEVICE INFORMATION ===\n"
        logsContent += "Version: \(UIDevice.current.systemVersion)\n"
        logsContent += "Name: \(UIDevice.current.name)\n" 
        logsContent += "Model: \(UIDevice.current.model)\n"
        logsContent += "StikJIT Version: App Version: 1.0\n\n"
        logsContent += "=== LOG ENTRIES ===\n"
        
        // Add all log entries with proper formatting
        logsContent += logManager.logs.map { 
            "[\(formatTime(date: $0.timestamp))] [\($0.type.rawValue)] \($0.message)" 
        }.joined(separator: "\n")
        
        // Copy to clipboard
        UIPasteboard.general.string = logsContent
        
        // Show success alert
        alertTitle = "Logs Copied"
        alertMessage = "Logs have been copied to clipboard."
        isError = false
        showingCopyAlert = true
    }
}

// MARK: - Extensions for URL
extension URL {
    static var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

// MARK: - HapticFeedbackHelper
class HapticFeedbackHelper {
    static func trigger() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}
