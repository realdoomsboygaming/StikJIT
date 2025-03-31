import SwiftUI
import Network
import Foundation

// TCP/WiFi Connectivity Diagnostics Utility Class
class TCPConnectionDiagnostics: ObservableObject {
    // Singleton instance
    static let shared = TCPConnectionDiagnostics()
    
    // Published properties for UI state
    @Published var isRunningDiagnostics = false
    @Published var wireguardConnected = false
    
    // Private dispatch queues and groups for thread safety
    private let diagnosticsQueue = DispatchQueue(
        label: "com.stikjit.tcpdiagnostics", 
        attributes: .concurrent
    )
    private let connectionGroup = DispatchGroup()
    
    // Private initializer for singleton
    private init() {}
    
    /// Run diagnostics for TCP/WiFi connectivity
    func runDiagnostics(completion: @escaping () -> Void) {
        // Prevent multiple simultaneous diagnostic runs
        guard !isRunningDiagnostics else { return }
        
        // Reset diagnostics state on main queue to prevent UI glitches
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isRunningDiagnostics = true
            self.wireguardConnected = false
        }
        
        // Log diagnostic start
        LogManager.shared.addInfoLog("🔍 Starting TCP/WiFi connection diagnostics")
        
        // Run diagnostics on background queue
        diagnosticsQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check WireGuard/TCP connection
            self.checkWireguardConnection()
            
            // Wait for check to complete
            self.connectionGroup.notify(queue: .main) {
                self.isRunningDiagnostics = false
                completion()
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
}

// Connection Status Card for Diagnostics View
struct ConnectionStatusCard: View {
    let title: String
    let iconName: String
    let isConnected: Bool
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
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
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
            return .green
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

// TCP Connection Diagnostics View
struct TCPConnectionDiagnosticsView: View {
    @StateObject private var diagnostics = TCPConnectionDiagnostics.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title and Explanation
                VStack(spacing: 8) {
                    Text("TCP Connection Diagnostics")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Check your WiFi/WireGuard connection status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // WireGuard Connection Status Card
                ConnectionStatusCard(
                    title: "WireGuard Connection",
                    iconName: "wifi",
                    isConnected: diagnostics.wireguardConnected,
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
                            Text("Testing TCP connection...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        // Results Section
                        VStack(spacing: 8) {
                            if diagnostics.wireguardConnected {
                                VStack(spacing: 8) {
                                    Text("Connection Status")
                                        .font(.headline)
                                    
                                    Text("WireGuard Connected")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                    
                                    Text("Your TCP/WiFi connection is working correctly")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            } else {
                                // Not Connected
                                VStack(spacing: 8) {
                                    Text("Connection Failed")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    
                                    Text("WireGuard connection not working")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    
                                    Text("Please check your WireGuard configuration and ensure you're connected")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                // Troubleshooting Tips
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Troubleshooting:")
                                        .font(.headline)
                                        .padding(.top, 10)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        TroubleshootingRow(text: "Make sure WireGuard is active and connected")
                                        TroubleshootingRow(text: "Verify your WireGuard configuration is correct")
                                        TroubleshootingRow(text: "Check that your device has internet connectivity")
                                        TroubleshootingRow(text: "Try restarting the WireGuard connection")
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
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

// Helper view for troubleshooting tips
struct TroubleshootingRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(.secondary)
                .padding(.top, 6)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
