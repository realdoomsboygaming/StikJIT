import UIKit

// Renamed to avoid conflict with the class version in StikJITApp.swift
struct HapticFeedbackUtil {
    static func trigger() {
        // Keep the implementation from your original HapticFeedbackHelper struct
        let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactFeedbackGenerator.prepare()
        impactFeedbackGenerator.impactOccurred()
    }
}
