// ConnectionModeExtensions.swift
// StikJIT
//
// Created on 3/30/25.
//

import Foundation

// This enum mirrors the Objective-C ConnectionMode enum defined in heartbeat.h
// to provide type-safe handling in Swift
enum ConnectionMode: Int {
    case USB = 0
    case TCP = 1
}

// Extension to provide conversion to Objective-C ConnectionMode
extension ConnectionMode {
    // Convert Swift ConnectionMode to Objective-C ConnectionMode
    var toObjC: __ObjC.ConnectionMode {
        switch self {
        case .USB:
            return .USB
        case .TCP:
            return .TCP
        }
    }
    
    // Create Swift ConnectionMode from Int (useful for @AppStorage)
    static func fromInt(_ value: Int) -> ConnectionMode {
        return value == 0 ? .USB : .TCP
    }
}

// Extension to modify the places that use this conversion
extension JITEnableContext {
    // Helper method to simplify conversion
    func setConnectionModeSwift(_ mode: ConnectionMode) {
        self.setConnectionMode(mode.toObjC)
    }
}
