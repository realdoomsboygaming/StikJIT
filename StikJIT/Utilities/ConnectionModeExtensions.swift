// ConnectionModeExtensions.swift
// StikJIT
//
// Created on 3/30/25.
//

import Foundation

// Instead of redefining ConnectionMode, just extend the existing one
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
}

// Extension to modify the places that use this conversion
extension JITEnableContext {
    // Helper method to simplify conversion
    func setConnectionModeSwift(_ mode: ConnectionMode) {
        self.setConnectionMode(mode.toObjC)
    }
}
