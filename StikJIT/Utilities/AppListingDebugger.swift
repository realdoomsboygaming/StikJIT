import Foundation
import SwiftUI

/// Enhanced version of InstalledAppsViewModel with better error handling and diagnostics
class EnhancedAppsViewModel: ObservableObject {
    @Published var apps: [String: String] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    func loadApps() {
        isLoading = true
        errorMessage = nil
        
        // Log the current connection mode
        let connectionMode = UserDefaults.standard.integer(forKey: "connectionMode") 
        LogManager.shared.addInfoLog("🔍 Debug: Loading apps in mode: \(connectionMode == 0 ? "USB" : "TCP/WiFi")")
        
        // Verify pairing file exists
        let fileManager = FileManager.default
        let pairingFilePath = URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path
        guard fileManager.fileExists(atPath: pairingFilePath) else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Pairing file is missing. Please import a pairing file in Settings."
                LogManager.shared.addErrorLog("❌ Pairing file not found")
            }
            return
        }
        
        // First, ensure the connection mode is set correctly
        let swiftMode: ConnectionModeSwift = connectionMode == 0 ? .USB : .TCP
        JITEnableContext.shared().setConnectionModeSwift(swiftMode)
        LogManager.shared.addInfoLog("🔍 Debug: Connection mode set to \(connectionMode == 0 ? "USB" : "TCP/WiFi")")
        
        // Create a dispatch work item to handle the apps loading
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Perform USB connectivity check if in USB mode
            if connectionMode == 0 {
                let usbConnected = USBConnectivityChecker.shared.checkUSBConnectivity()
                guard usbConnected else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "USB connection failed. Ensure your device is connected and trusted."
                        LogManager.shared.addWarningLog("⚠️ USB connectivity check failed")
                    }
                    return
                }
            }
            
            // Try getAppsSimple method
            LogManager.shared.addInfoLog("🔍 Debug: Attempting getAppsSimple()")
            if let appsSimple = JITEnableContext.shared().getAppsSimple(), !appsSimple.isEmpty {
                DispatchQueue.main.async {
                    self.apps = appsSimple
                    self.isLoading = false
                    LogManager.shared.addInfoLog("✅ Success: Found \(appsSimple.count) apps with getAppsSimple()")
                    
                    if !appsSimple.isEmpty {
                        let sampleApps = Array(appsSimple.keys.prefix(3)).joined(separator: ", ")
                        LogManager.shared.addInfoLog("📱 Apps found: \(sampleApps)...")
                    }
                }
                return
            }
            
            // Last resort - check if there's a connection issue
            DispatchQueue.main.async {
                if connectionMode == 0 {
                    LogManager.shared.addInfoLog("🔍 Debug: USB mode connection check")
                    self.errorMessage = "No apps found in USB mode. Check your USB connection or switch to WiFi mode in Settings."
                } else {
                    LogManager.shared.addInfoLog("🔍 Debug: TCP/WiFi connection check")
                    self.errorMessage = "No apps found in WiFi mode. Ensure WireGuard is connected or try switching to USB mode in Settings."
                }
                self.isLoading = false
                LogManager.shared.addWarningLog("⚠️ Warning: No apps found in \(connectionMode == 0 ? "USB" : "WiFi") mode")
            }
        }
        
        // Execute the work item on a global queue
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
}

// Rest of the implementation remains the same as in the previous version
struct EnhancedAppsListView: View {
    @StateObject private var viewModel = EnhancedAppsViewModel()
    @State private var appIcons: [String: UIImage] = [:]
    @Environment(\.dismiss) private var dismiss
    @AppStorage("recentApps") var recentApps: [String] = []
    @AppStorage("connectionMode") private var connectionMode: Int = 0
    var onSelectApp: (String) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        
                        Text("Loading installed apps...")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: connectionMode == 0 ? "cable.connector.slash" : "wifi.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                            .padding()
                        
                        Text("Connection Issue")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            viewModel.loadApps()
                        }) {
                            Text("Try Again")
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 10)
                        
                        // Toggle connection mode option
                        Button(action: {
                            // Toggle connection mode
                            connectionMode = connectionMode == 0 ? 1 : 0
                            // Update the context
                            let swiftMode: ConnectionModeSwift = connectionMode == 0 ? .USB : .TCP
                            JITEnableContext.shared().setConnectionModeSwift(swiftMode)
                            // Reload apps
                            LogManager.shared.addInfoLog("🔄 Switching to \(connectionMode == 0 ? "USB" : "WiFi/WireGuard") mode")
                            viewModel.loadApps()
                        }) {
                            Text("Switch to \(connectionMode == 0 ? "WiFi/WireGuard" : "USB") Mode")
                                .foregroundColor(.blue)
                                .padding(.top, 20)
                        }
                    }
                    .padding()
                } else if viewModel.apps.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "app.badge.checkmark")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text("No Compatible Apps Found")
                            .font(.headline)
                        
                        Text("Could not find any apps with the required 'get-task-allow' entitlement. Make sure you have development apps installed.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            viewModel.loadApps()
                        }) {
                            Text("Refresh")
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                } else {
                    List {
                        if !recentApps.isEmpty {
                            Section {
                                ForEach(recentApps, id: \.self) { bundleID in
                                    if let appName = viewModel.apps[bundleID] {
                                        AppButton(bundleID: bundleID, appName: appName, recentApps: $recentApps, appIcons: $appIcons, onSelectApp: onSelectApp)
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive) {
                                                    withAnimation {
                                                        recentApps.removeAll(where: { $0 == bundleID })
                                                    }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            } header: {
                                Text("Recents")
                            }
                        }
                        
                        Section {
                            ForEach(viewModel.apps.sorted(by: { $0.key < $1.key }), id: \.key) { bundleID, appName in
                                AppButton(bundleID: bundleID, appName: appName, recentApps: $recentApps, appIcons: $appIcons, onSelectApp: onSelectApp)
                            }
                        } header: {
                            if !recentApps.isEmpty {
                                Text("All Applications")
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Installed Apps")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !viewModel.isLoading && !viewModel.apps.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            viewModel.loadApps()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadApps()
        }
    }
}
