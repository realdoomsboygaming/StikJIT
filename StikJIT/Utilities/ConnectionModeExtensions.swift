import Foundation

// Define the Swift-side enum to match the Objective-C side
enum ConnectionMode: Int {
    case USB = 0
    case TCP = 1
}

// Extension to JITEnableContext for type-safe calls from Swift
extension JITEnableContext {
    // Type-safe wrapper method for setting connection mode
    func setConnectionModeSwift(_ mode: ConnectionMode) {
        // Convert Swift enum to the raw Int value, which matches the Objective-C enum values
        self.setConnectionMode(ConnectionMode_objc(rawValue: mode.rawValue)!)
    }
}
