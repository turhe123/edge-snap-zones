import AppKit
import ApplicationServices
import ServiceManagement

/// Central coordinator: tracks Accessibility trust and starts/stops drag monitoring and hotkeys to match settings.
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var loginError: String?

    private let drag = DragSnapController()
    private var pollTimer: Timer?
    private var defaultsObserver: NSObjectProtocol?

    private init() {
        Prefs.registerDefaults()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.apply() }
        if !trusted { requestAccess() }
        // Poll continuously: picks up a fresh grant and detects revocation while running.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.refreshTrust() }
        apply()
    }

    /// Shows the system Accessibility prompt.
    func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        trusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func openAccessibilityPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshTrust() {
        let now = AXIsProcessTrusted()
        guard now != trusted else { return }
        trusted = now
        apply()
    }

    /// Starts or stops each service according to trust and the user's toggles.
    private func apply() {
        let active = trusted && Prefs.enabled
        if active && Prefs.dragEnabled { drag.start() } else { drag.stop() }
        if active && Prefs.hotkeysEnabled { HotKeyManager.shared.start() } else { HotKeyManager.shared.stop() }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
