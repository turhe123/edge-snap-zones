import SwiftUI

/// Contents of the menu bar menu: status, layouts with shortcuts, toggles and app commands.
struct MenuView: View {
    @EnvironmentObject private var state: AppState
    @AppStorage(Prefs.enabledKey) private var enabled = true
    @Environment(\.openSettings) private var openSettings

    private let groups: [[SnapLayout]] = [
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf, .maximize, .center],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.leftThird, .centerThird, .rightThird],
    ]

    var body: some View {
        if !state.trusted {
            Button("⚠️ Accessibility access is needed — Grant…") {
                state.requestAccess()
                state.openAccessibilityPane()
            }
            Divider()
        }
        ForEach(groups.indices, id: \.self) { i in
            ForEach(groups[i]) { layout in
                Button {
                    HotKeyManager.perform(.layout(layout))
                } label: {
                    Label("\(layout.title)\t\(HotKeyManager.label(for: .layout(layout)))", systemImage: layout.symbol)
                }
                .disabled(!state.trusted)
            }
            Divider()
        }
        Button("Restore Original Size\t\(HotKeyManager.label(for: .restore))") {
            HotKeyManager.perform(.restore)
        }
        .disabled(!state.trusted)
        Toggle("Enabled", isOn: $enabled)
        Divider()
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Support / Donate ❤️") { Support.openDonate() }
        Divider()
        Button("Quit EdgeSnapZones") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
