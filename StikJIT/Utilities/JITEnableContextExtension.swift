// JITEnableContextExtension.swift
// StikJIT
//
// Created on 3/30/2025.
//

import Foundation

// Swift enum that mirrors the Objective-C ConnectionMode_objc enum
@objc public enum ConnectionModeSwift: Int {
    case USB = 0
    case TCP = 1
}

// Extension to provide Swift-friendly methods
extension JITEnableContext {
    // Method to set connection mode using Swift enum
    @objc public func setConnectionModeSwift(_ mode: ConnectionModeSwift) {
        self.setConnectionMode(Int32(mode.rawValue))
    }
    
    // Helper method to check if DevDiskImage is mounted
    @objc public func checkIfMounted() -> Bool {
        return isMounted()
    }
    
    // Method to get app list with Swift error handling
    @objc public func getAppList(withError error: inout NSError?) -> [String: String]? {
        return self.getAppListWithError(&error)
    }
}
