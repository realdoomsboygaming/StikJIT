import Foundation

// Create a Swift-friendly enum that mirrors the Objective-C ConnectionMode
// We're using a different name to avoid conflicts
@objc public enum ConnectionModeSwift: Int {
    case USB = 0
    case TCP = 1
}

// Extend JITEnableContext to add a Swift-friendly method
extension JITEnableContext {
    @objc public func setConnectionModeSwift(_ mode: ConnectionModeSwift) {
        // The Objective-C ConnectionMode enum has the same raw values
        // Just pass the raw value to the Objective-C method
        self.setConnectionMode(Int32(mode.rawValue))
    }
}
