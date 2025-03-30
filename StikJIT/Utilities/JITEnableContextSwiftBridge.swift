import Foundation

// Single definition of ConnectionModeSwift enum
@objc public enum ConnectionModeSwift: Int {
    case USB = 0
    case TCP = 1
}

// Extension to add Swift-friendly interface to JITEnableContext
extension JITEnableContext {
    // Method to set connection mode using Swift enum
    @objc public func setConnectionModeSwift(_ mode: ConnectionModeSwift) {
        // Cast to Int32 to match the Objective-C method signature
        self.setConnectionMode(Int32(mode.rawValue))
    }
    
    // Create a completely different method that doesn't try to use getAppListWithError
    public func getAppList() -> [String: String]? {
        // Access the variable directly instead of using the method
        let nsError = NSError(domain: "StikJIT", code: -1, userInfo: nil)
        var error: NSError? = nsError
        
        // Call the Objective-C API directly
        if let apps = list_installed_apps_usb(nil, &error) {
            return apps as? [String: String]
        }
        
        return [:]
    }
}
