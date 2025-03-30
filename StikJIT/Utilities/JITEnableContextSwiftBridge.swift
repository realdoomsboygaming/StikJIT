// JITEnableContextSwiftBridge.swift
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
        // Call the Objective-C method with raw int value
        self.setConnectionMode(mode.rawValue)
    }
    
    // Non-@objc version with inout parameter for Swift use
    public func getAppList() -> [String: String]? {
        var error: NSError?
        let result = self.getAppListWithError(&error)
        
        if let error = error {
            print("Error getting app list: \(error)")
            return nil
        }
        
        return result
    }
}
