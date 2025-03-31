import SwiftUI
import Network
import Foundation

// Connectivity Diagnostics Utility Class
class ConnectionDiagnostics: ObservableObject {
    // Singleton instance
    static let shared = ConnectionDiagnostics()
    
    // Published properties for UI state
    @Published var isRunningDiagnostics = false
    @Published var usbConnected = false
    @Published var wireguardConnected = false
    @Published var recommendedMode: Int? = nil
    
    // Private dispatch queues and groups for thread safety
    private let diagnosticsQueue = DispatchQueue(
        label: "com.stikjit.connectiondiagnostics", 
        attributes: .concurrent
    )
    private let connectionGroup = DispatchGroup()
    
    // Private initializer for singleton
    private init() {}
    
    /// Comprehensive connection diagnostics method
    func runDiagnostics(completion: @escaping () -> Void) {
        // Prevent multiple simultaneous diagnostic runs
        guard !isRunningDiagnostics else { return }
        
        // Reset diagnostics state on main queue to prevent UI glitches
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isRunningDiagnostics = true
            self.usbConnected = false
            self.wireguardConnected = false
            self.recommendedMode = nil
        }
        
        // Log diagnostic start
        LogManager.shared.addInfoLog("🔍 Starting comprehensive connection diagnostics")
        
        // Run diagnostics on background queue
        diagnosticsQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Perform concurrent connection checks
            self.checkUSBConnection()
            self.checkWireguardConnection()
            
            // Wait for all checks to complete
            self.connectionGroup.notify(queue: .main) {
                self.determineRecommendedMode()
                self.isRunningDiagnostics = false
                completion()
            }
        }
    }
    
    /// Check USB connectivity
    private func checkUSBConnection() {
        connectionGroup.enter()
        diagnosticsQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Use USBConnectivityChecker to verify USB connection
            let isConnected = USBConnectivityChecker.shared.checkUSBConnectivity()
            
            DispatchQueue.main.async {
                self.usbConnected = isConnected
                LogManager.shared.addInfoLog("🔌 USB Connectivity: \(isConnected ? "Connected" : "Disconnected")")
                self.connectionGroup.leave()
            }
        }
    }
    
    /// Check WireGuard/Network connectivity
    private func checkWireguardConnection() {
        connectionGroup.enter()
        diagnosticsQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Use semaphore for synchronous-like network check
            let semaphore = DispatchSemaphore(value: 0)
            var connectionResult = false
            
            // Create network connection
            let connection = self.createWireguardConnection()
            
            // Handle connection state updates
            connection.stateUpdateHandler = { [weak connection] state in
                switch state {
                case .ready:
                    connectionResult = true
                    connection?.cancel()
                    semaphore.signal()
                case .failed, .cancelled:
                    connectionResult = false
                    connection?.cancel()
                    semaphore.signal()
                default:
                    break
                }
            }
            
            // Start connection on global queue
            connection.start(queue: .global())
            
            // Wait with timeout
            _ = semaphore.wait(timeout: .now() + 5.0)
            
            // Update UI on main queue
            DispatchQueue.main.async {
                self.wireguardConnected = connectionResult
                LogManager.shared.addInfoLog("🌐 WireGuard Connectivity: \(connectionResult ? "Connected" : "Disconnected")")
                self.connectionGroup.leave()
            }
        }
    }
    
    /// Create network connection for WireGuard check
    private func createWireguardConnection() -> NWConnection {
        let host = NWEndpoint.Host("10.7.0.1")
        let port = NWEndpoint.Port(rawValue: 62078)!
        return NWConnection(host: host, port: port, using: .tcp)
    }
    
    /// Determine the recommended connection mode
    private func determineRecommendedMode() {
        if usbConnected && !wireguardConnected {
            recommendedMode = 0 // USB
            LogManager.shared.addInfoLog("🔍 Diagnostics recommend USB mode")
        } else if !usbConnected && wireguardConnected {
            recommendedMode = 1 // WireGuard
            LogManager.shared.addInfoLog("🔍 Diagnostics recommend WireGuard mode")
        } else if usbConnected && wireguardConnected {
            recommendedMode = 0 // Prioritize USB
            LogManager.shared.addInfoLog("🔍 Both connections work, prioritizing USB")
        } else {
            recommendedMode = nil
            LogManager.shared.addErrorLog("❌ No working connection found")
        }
    }
}

// Connection Status Card for Diagnostics View
struct ConnectionStatusCard: View {
    let title: String
    let iconName: String
    let isConnected: Bool
    let isRecommended: Bool
    let isCurrentMode: Bool
    let isRunningTest: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Connection Status Icon
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
                    // Status Text
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(statusColor)
                    
                    // Current Mode Indicator
                    if isCurrentMode {
                        Text("(Current)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    // Recommended Mode Indicator
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
    
    // Computed properties for dynamic styling
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

// Connection Diagnostics View
struct ConnectionDiagnosticsView: View {
    @StateObject private var diagnostics = ConnectionDiagnostics.shared
    @AppStorage("connectionMode") private var connectionMode: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title and Explanation
                VStack(spacing: 8) {
                    Text("Connection Diagnostics")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Identify the best connection method for your device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Connection Status Cards
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
                
                Spacer()
                
                // Diagnostics Actions
                VStack(spacing: 16) {
                    if diagnostics.isRunningDiagnostics {
                        // Loading State
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Testing connections...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        // Recommendation Section
                        if let recommended = diagnostics.recommendedMode {
                            VStack(spacing: 8) {
                                Text("Recommended Connection")
                                    .font(.headline)
                                
                                Text(recommended == 0 ? "USB Mode" : "WireGuard Mode")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(recommended == 0 ? .blue : .green)
                                
                                // Mode Switch Button
                                if recommended != connectionMode {
                                    Button(action: {
                                        // Switch to recommended mode
                                        connectionMode = recommended
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
                                    Text("You're using the recommended mode")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        } else {
                            // No Working Connection
                            VStack(spacing: 8) {
                                Text("Connection Failed")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                Text("Neither USB nor WireGuard connections are working. Check your setup and try again.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Re-run Diagnostics Button
                        Button(action: {
                            diagnostics.runDiagnostics {}
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
                // Automatically run diagnostics on view appearance
                diagnostics.runDiagnostics {}
            }
        }
    }
}
