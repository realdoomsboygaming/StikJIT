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
        
        // Create a dispatch group to synchronize the connection check
        let group = DispatchGroup()
        var isConnected = false
        
        group.enter()
        
        // Use DispatchWorkItem for the USB connection check
        let workItem = DispatchWorkItem {
            // Use OpaquePointer since UsbmuxdAddrHandle is defined as an opaque type in the C header
            var usb_addr: OpaquePointer? = nil
            
            // Convert the string to C string for the function call
            let cString = "/var/run/usbmuxd".cString(using: .utf8)
            let err = idevice_usbmuxd_unix_addr_new(cString, &usb_addr)
            
            if err == IdeviceSuccess && usb_addr != nil {
                LogManager.shared.addInfoLog("🔌 USB Diagnostics: Successfully created usbmuxd address")
                idevice_usbmuxd_addr_free(usb_addr)
                isConnected = true
            } else {
                LogManager.shared.addErrorLog("🔌 USB Diagnostics: Failed to create usbmuxd address, error: \(err)")
            }
            
            group.leave()
        }
        
        // Execute the work item on a global queue
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        
        // Wait with timeout to avoid hanging
        _ = group.wait(timeout: .now() + 5.0)
        
        return isConnected
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
