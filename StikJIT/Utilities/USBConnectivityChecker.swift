// USBConnectivityChecker.swift
// Add this to your project to diagnose USB connection issues

import Foundation
import UIKit

class USBConnectivityChecker {
    
    static let shared = USBConnectivityChecker()
    
    private init() {}
    
    /// Checks if a USB device is connected and logs diagnostic information
    func checkUSBConnectivity() -> Bool {
        // Check if pairing file exists
        let fileManager = FileManager.default
        let pairingFilePath = URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path
        let pairingExists = fileManager.fileExists(atPath: pairingFilePath)
        
        LogManager.shared.addInfoLog("🔌 USB Diagnostics: Pairing file exists: \(pairingExists)")
        
        if !pairingExists {
            LogManager.shared.addWarningLog("🔌 USB Diagnostics: No pairing file found")
            return false
        }
        
        // Create a UsbmuxdAddrHandle just to test connectivity
        do {
            // This code doesn't actually establish a full connection, just tests if the usbmuxd socket is available
            // Use a separate thread to avoid blocking the main thread
            var isConnected = false
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global(qos: .utility).async {
                var usb_addr: UnsafeMutablePointer<UnsafeMutableRawPointer>? = nil
                let err = idevice_usbmuxd_unix_addr_new("/var/run/usbmuxd", &usb_addr)
                
                if err == IdeviceSuccess && usb_addr != nil {
                    LogManager.shared.addInfoLog("🔌 USB Diagnostics: Successfully created usbmuxd address")
                    idevice_usbmuxd_addr_free(usb_addr)
                    isConnected = true
                } else {
                    LogManager.shared.addErrorLog("🔌 USB Diagnostics: Failed to create usbmuxd address, error: \(err)")
                }
                
                group.leave()
            }
            
            // Wait with timeout to avoid hanging
            if group.wait(timeout: .now() + 5.0) == .timedOut {
                LogManager.shared.addErrorLog("🔌 USB Diagnostics: Connection check timed out")
                return false
            }
            
            return isConnected
            
        } catch {
            LogManager.shared.addErrorLog("🔌 USB Diagnostics: Error checking USB connection: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Provides recommendations on how to fix USB connectivity issues
    func getUSBTroubleshootingSteps() -> String {
        return """
        1. Ensure your device is connected with a USB cable
        2. Try unplugging and reconnecting the cable
        3. Try a different USB port or cable
        4. Ensure you've trusted this computer on your device
        5. Restart your device and try again
        6. Switch to WiFi/WireGuard mode in Settings if USB isn't working
        """
    }
    
    /// Shows an alert with USB troubleshooting steps
    func showUSBTroubleshootingAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "USB Connection Issue",
                message: "There seems to be an issue with the USB connection.\n\n\(self.getUSBTroubleshootingSteps())",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
}
