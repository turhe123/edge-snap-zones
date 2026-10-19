import SwiftUI
import AppKit

/// App entry point: a menu-bar-only app with a MenuBarExtra and a Settings window.
@main
struct EdgeSnapZonesApp: App {
    @StateObject private var state = AppState.shared
    @AppStorage(Prefs.enabledKey) private var enabled = true

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(state)
        } label: {
            Image(nsImage: MenuBarIcon.image(dimmed: !(state.trusted && enabled)))
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(state)
        }
    }
}

/// Builds the template menu bar icon; the dimmed variant is drawn at reduced alpha.
enum MenuBarIcon {
    static func image(dimmed: Bool) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "EdgeSnapZones")?
            .withSymbolConfiguration(config) else { return NSImage() }
        let image = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: dimmed ? 0.35 : 1)
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Opens the donation page.
enum Support {
    static func openDonate() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }
}
