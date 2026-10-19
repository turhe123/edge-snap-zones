import Foundation

/// UserDefaults keys and typed accessors shared by `@AppStorage` views and non-UI services.
enum Prefs {
    static let enabledKey = "enabled"
    static let sensitivityKey = "edgeSensitivity"
    static let gapKey = "gapSize"
    static let dragKey = "dragToSnap"
    static let hotkeysKey = "keyboardShortcuts"
    static let ignoredKey = "ignoredApps"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            enabledKey: true, sensitivityKey: 8.0, gapKey: 0, dragKey: true, hotkeysKey: true, ignoredKey: "",
        ])
    }

    private static var d: UserDefaults { .standard }
    static var enabled: Bool { d.bool(forKey: enabledKey) }
    static var sensitivity: Double { min(max(d.double(forKey: sensitivityKey), 2), 30) }
    static var gap: Int { max(d.integer(forKey: gapKey), 0) }
    static var dragEnabled: Bool { d.bool(forKey: dragKey) }
    static var hotkeysEnabled: Bool { d.bool(forKey: hotkeysKey) }

    /// Bundle identifiers whose windows are never snapped (stored newline-separated).
    static var ignoredApps: [String] {
        get { (d.string(forKey: ignoredKey) ?? "").split(separator: "\n").map(String.init) }
        set { d.set(newValue.joined(separator: "\n"), forKey: ignoredKey) }
    }
}
