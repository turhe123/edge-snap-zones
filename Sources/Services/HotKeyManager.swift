import AppKit
import Carbon

/// Registers Control+Option global shortcuts with Carbon `RegisterEventHotKey` (no Input Monitoring needed).
final class HotKeyManager {
    static let shared = HotKeyManager()

    /// A shortcut action: either a layout or restoring the original size.
    enum Action: Equatable {
        case layout(SnapLayout)
        case restore
    }

    /// Key code, display label and action for every shortcut.
    static let bindings: [(key: Int, label: String, action: Action)] = [
        (kVK_LeftArrow, "←", .layout(.leftHalf)),
        (kVK_RightArrow, "→", .layout(.rightHalf)),
        (kVK_UpArrow, "↑", .layout(.topHalf)),
        (kVK_DownArrow, "↓", .layout(.bottomHalf)),
        (kVK_Return, "↩", .layout(.maximize)),
        (kVK_ANSI_U, "U", .layout(.topLeft)),
        (kVK_ANSI_I, "I", .layout(.topRight)),
        (kVK_ANSI_J, "J", .layout(.bottomLeft)),
        (kVK_ANSI_K, "K", .layout(.bottomRight)),
        (kVK_ANSI_D, "D", .layout(.leftThird)),
        (kVK_ANSI_F, "F", .layout(.centerThird)),
        (kVK_ANSI_G, "G", .layout(.rightThird)),
        (kVK_ANSI_C, "C", .layout(.center)),
        (kVK_Delete, "⌫", .restore),
    ]

    static func label(for action: Action) -> String {
        bindings.first { $0.action == action }.map { "⌃⌥" + $0.label } ?? ""
    }

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    var isRunning: Bool { !refs.isEmpty }

    func start() {
        guard !isRunning else { return }
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var id = EventHotKeyID()
                let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                               nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                if status == noErr { DispatchQueue.main.async { HotKeyManager.shared.fire(Int(id.id)) } }
                return noErr
            }, 1, &spec, nil, &handler)
        }
        let signature = OSType(0x4553_5A4E) // 'ESZN'
        for (index, binding) in Self.bindings.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: signature, id: UInt32(index))
            let status = RegisterEventHotKey(UInt32(binding.key), UInt32(controlKey | optionKey), id,
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) }
        }
    }

    func stop() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
    }

    private func fire(_ index: Int) {
        guard Self.bindings.indices.contains(index) else { return }
        Self.perform(Self.bindings[index].action)
    }

    /// Runs an action against the frontmost app's focused window.
    static func perform(_ action: Action) {
        guard let window = WindowMover.shared.focusedWindow() else { NSSound.beep(); return }
        switch action {
        case .layout(let layout): WindowMover.shared.snap(window, to: layout)
        case .restore: WindowMover.shared.restore(window)
        }
    }
}
