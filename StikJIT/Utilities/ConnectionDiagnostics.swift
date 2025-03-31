// ConnectionDiagnostics.swift
// Add this to your project to help diagnose connection issues

import SwiftUI
import Network

class ConnectionDiagnostics: ObservableObject {
    static let shared = ConnectionDiagnostics()
    
    @Published var isRunningDiagnostics = false
    @Published var usbConnected = false
    @Published var wireguardConnected = false
    @Published var recommendedMode: Int? = nil
    
    private init() {}
    
    /// Run diagnostics on both connection types
    func runDiagnostics(completion: @escaping () -> Void) {
        guard !isRunningDiagnostics else { return }
        
        isRunningDiagnostics = true
        LogManager.shared.addInfoLog("🔍 Starting connection diagnostics")
        
        // Reset previous results
        usbConnected = false
        wireguardConnected = false
        recommendedMode = nil
        
        let group = DispatchGroup()
        
        // Check USB connection
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.usbConnected = USBConnectivityChecker.shared.checkUSBConnectivity()
            LogManager.shared.addInfoLog("🔍 Diagnostics: USB connection \(self?.usbConnected == true ? "succeeded" : "failed")")
            group.leave()
        }
        
        // Check WireGuard/TCP connection
        group.enter()
        checkWireguardConnection { [weak self] success in
            self?.wireguardConnected = success
            LogManager.shared.addInfoLog("🔍 Diagnostics: WireGuard connection \(success ? "succeeded" : "failed")")
            group.leave()
        }
        
        // Wait for both checks to complete
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Determine recommended mode
            if self.usbConnected && !self.wireguardConnected {
                self.recommendedMode = 0 // USB mode
                LogManager.shared.addInfoLog("🔍 Diagnostics: Recommending USB mode")
            } else if !self.usbConnected && self.wireguardConnected {
                self.recommendedMode = 1 // TCP/WireGuard mode
                LogManager.shared.addInfoLog("🔍 Diagnostics: Recommending WireGuard mode")
            } else if self.usbConnected && self.wireguardConnected {
                // Both work, prioritize USB for speed
                self.recommendedMode = 0
                LogManager.shared.addInfoLog("🔍 Diagnostics: Both connections work, recommending USB for speed")
            } else {
                // Neither works
                self.recommendedMode = nil
                LogManager.shared.addErrorLog("❌ Diagnostics: Neither connection method works")
            }
            
            self.isRunningDiagnostics = false
            completion()
        }
    }
    
    /// Check if WireGuard VPN is connected
    private func checkWireguardConnection(completion: @escaping (Bool) -> Void) {
        let host = NWEndpoint.Host("10.7.0.1")
        let port = NWEndpoint.Port(rawValue: 62078)!
        
        let connection = NWConnection(host: host, port: port, using: .tcp)
        
        // Create a timeout
        var timeoutWorkItem: DispatchWorkItem?
        
        timeoutWorkItem = DispatchWorkItem { [weak connection] in
            if connection?.state != .ready {
                connection?.cancel()
                completion(false)
            }
        }
        
        connection.stateUpdateHandler = { [weak connection] state in
            switch state {
            case .ready:
                // Connection succeeded - cancel the timeout
                timeoutWorkItem?.cancel()
                connection?.cancel()
                completion(true)
            case .failed(let error):
                // Connection failed - cancel the timeout
                timeoutWorkItem?.cancel()
                connection?.cancel()
                LogManager.shared.addDebugLog("🔍 WireGuard test error: \(error.localizedDescription)")
                completion(false)
            case .cancelled:
                timeoutWorkItem?.cancel()
                completion(false)
            default:
                break
            }
        }
        
        // Start the connection
        connection.start(queue: .global())
        
        // Schedule the timeout - 3 seconds is usually enough
        if let workItem = timeoutWorkItem {
            DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: workItem)
        }
    }
}

struct ConnectionDiagnosticsView: View {
    @StateObject private var diagnostics = ConnectionDiagnostics.shared
    @AppStorage("connectionMode") private var connectionMode: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title and explanation
                VStack(spacing: 8) {
                    Text("Connection Diagnostics")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Let's figure out which connection method works best for your setup")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Connection status cards
                Group {
                    ConnectionStatusCard(
                        title: "USB Connection",
                        iconName: "cable.connector",
                        isConnected: diagnostics.usbConnected,
                        isRecommended: diagnostics.recommendedMode == 0,
                        isCurrentMode: connectionMode == 0,
                        isRunningTest: diagnostics.isRunningDiagnostics
                    )
                    
                    ConnectionStatusCard(
                        title: "WireGuard Connection",
                        iconName: "wifi",
                        isConnected: diagnostics.wireguardConnected,
                        isRecommended: diagnostics.recommendedMode == 1,
                        isCurrentMode: connectionMode == 1,
                        isRunningTest: diagnostics.isRunningDiagnostics
                    )
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 16) {
                    if diagnostics.isRunningDiagnostics {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Testing connections...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        // Recommendation
                        if let recommended = diagnostics.recommendedMode {
                            VStack(spacing: 8) {
                                Text("Recommended Connection")
                                    .font(.headline)
                                
                                Text(recommended == 0 ? "USB Mode" : "WireGuard Mode")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(recommended == 0 ? .blue : .green)
                                
                                if recommended != connectionMode {
                                    Button(action: {
                                        // Switch to recommended mode
                                        connectionMode = recommended
                                        // Update in JITEnableContext
                                        let swiftMode: ConnectionModeSwift = connectionMode == 0 ? .USB : .TCP
                                        JITEnableContext.shared().setConnectionModeSwift(swiftMode)
                                        // Log the change
                                        LogManager.shared.addInfoLog("🔄 Switched to \(connectionMode == 0 ? "USB" : "WiFi/WireGuard") mode")
                                    }) {
                                        Text("Switch to Recommended Mode")
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .padding(.horizontal)
                                } else {
                                    Text("You're already using the recommended mode")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        } else if !diagnostics.usbConnected && !diagnostics.wireguardConnected {
                            VStack(spacing: 8) {
                                Text("No Working Connection")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                Text("Neither USB nor WireGuard connections are working. Please check your setup.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Run diagnostics button
                        Button(action: {
                            diagnostics.runDiagnostics {
                                // Completion handler
                            }
                        }) {
                            Text("Run Diagnostics Again")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Run diagnostics when the view appears
                diagnostics.runDiagnostics {
                    // Completion handler
                }
            }
        }
    }
}

struct ConnectionStatusCard: View {
    let title: String
    let iconName: String
    let isConnected: Bool
    let isRecommended: Bool
    let isCurrentMode: Bool
    let isRunningTest: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 56, height: 56)
                
                if isRunningTest {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: isConnected ? iconName : "\(iconName).slash")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                HStack {
                    // Status text
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(statusColor)
                    
                    if isCurrentMode {
                        Text("(Current)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    if isRecommended {
                        Text("Recommended")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var backgroundColor: Color {
        if isRunningTest {
            return .gray
        } else if isConnected {
            return isRecommended ? .green : .blue
        } else {
            return .red
        }
    }
    
    private var statusText: String {
        if isRunningTest {
            return "Testing..."
        } else if isConnected {
            return "Connected"
        } else {
            return "Not Connected"
        }
    }
    
    private var statusColor: Color {
        if isRunningTest {
            return .gray
        } else if isConnected {
            return .green
        } else {
            return .red
        }
    }
}
