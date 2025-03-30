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
}
