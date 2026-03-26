import AppKit
import Carbon
import Foundation

struct HotKeyDefinition: Identifiable {
    let layout: WindowLayoutPreset
    let keyCode: UInt32
    let modifiers: UInt32

    var id: String { layout.id }

    var displayText: String {
        "\(modifierSymbols)\(keySymbol)"
    }

    private var modifierSymbols: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "^" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        return symbols
    }

    private var keySymbol: String {
        switch Int(keyCode) {
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        default: return "?"
        }
    }

    static let defaults: [HotKeyDefinition] = [
        HotKeyDefinition(layout: .leftHalf, keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        HotKeyDefinition(layout: .rightHalf, keyCode: UInt32(kVK_RightArrow), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        HotKeyDefinition(layout: .maximize, keyCode: UInt32(kVK_UpArrow), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        HotKeyDefinition(layout: .bottomHalf, keyCode: UInt32(kVK_DownArrow), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        HotKeyDefinition(layout: .centerLarge, keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        HotKeyDefinition(layout: .topLeft, keyCode: UInt32(kVK_ANSI_U), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        HotKeyDefinition(layout: .topRight, keyCode: UInt32(kVK_ANSI_I), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        HotKeyDefinition(layout: .bottomLeft, keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        HotKeyDefinition(layout: .bottomRight, keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey | cmdKey))
    ]
}

@MainActor
final class HotKeyService {
    private static var current: HotKeyService?

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var definitionsByID: [UInt32: HotKeyDefinition] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var handler: EventHandlerRef?
    private let onTrigger: (WindowLayoutPreset) -> Void

    init(onTrigger: @escaping (WindowLayoutPreset) -> Void) {
        self.onTrigger = onTrigger
        Self.current = self
        installHandlerIfNeeded()
        registerAll(definitions: HotKeyDefinition.defaults)
    }

    var definitions: [HotKeyDefinition] {
        HotKeyDefinition.defaults
    }

    private func registerAll(definitions: [HotKeyDefinition]) {
        for definition in definitions {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: fourCharCode("WNST"), id: nextHotKeyID)
            let status = RegisterEventHotKey(
                definition.keyCode,
                definition.modifiers,
                hotKeyID,
                GetEventDispatcherTarget(),
                0,
                &hotKeyRef
            )

            guard status == noErr, let hotKeyRef else {
                continue
            }

            hotKeyRefs.append(hotKeyRef)
            definitionsByID[nextHotKeyID] = definition
            nextHotKeyID += 1
        }
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ in
                guard let event else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else { return status }
                HotKeyService.current?.handleHotKey(withID: hotKeyID.id)
                return noErr
            },
            1,
            &eventSpec,
            nil,
            &handler
        )
    }

    private func handleHotKey(withID id: UInt32) {
        guard let definition = definitionsByID[id] else {
            return
        }

        onTrigger(definition.layout)
    }
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
}
