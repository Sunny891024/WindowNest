import ApplicationServices
import Foundation

enum AccessibilityService {
    private static let promptKey = "AXTrustedCheckOptionPrompt"

    static func isTrusted(prompt: Bool) -> Bool {
        let options = [promptKey: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
