import AppKit
import ApplicationServices

/// Thin wrapper over the Accessibility API: finds windows, reads/writes frames and remembers pre-snap sizes.
final class WindowMover {
    static let shared = WindowMover()
    private let systemWide = AXUIElementCreateSystemWide()
    /// Original frames (AX coordinates) recorded before a window's first snap.
    private var originals: [(window: AXUIElement, frame: CGRect)] = []

    // MARK: Lookup

    /// The standard window under an AppKit screen point, or nil for sheets, full-screen or ignored windows.
    func window(at point: CGPoint) -> AXUIElement? {
        let ax = Coordinates.toAX(point)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(ax.x), Float(ax.y), &hit) == .success,
              var element = hit else { return nil }
        for _ in 0..<40 {
            let role = string(element, kAXRoleAttribute)
            if role == kAXSheetRole as String { return nil }
            if role == kAXWindowRole as String { break }
            guard let next = copy(element, kAXParentAttribute), CFGetTypeID(next) == AXUIElementGetTypeID() else { return nil }
            element = next as! AXUIElement // type checked above
        }
        guard string(element, kAXRoleAttribute) == kAXWindowRole as String else { return nil }
        return isSnappable(element) ? element : nil
    }

    /// The focused window of the frontmost application.
    func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let value = copy(axApp, kAXFocusedWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let window = value as! AXUIElement // type checked above
        return isSnappable(window) ? window : nil
    }

    private func isSnappable(_ window: AXUIElement) -> Bool {
        guard string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole as String else { return false }
        if let full = copy(window, "AXFullScreen") as? Bool, full { return false }
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success, pid != ProcessInfo.processInfo.processIdentifier else { return false }
        if let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
           Prefs.ignoredApps.contains(bundle) { return false }
        return true
    }

    // MARK: Geometry

    /// Window frame in AX (top-left origin) coordinates.
    func frame(of window: AXUIElement) -> CGRect? {
        guard let pos = copy(window, kAXPositionAttribute), let size = copy(window, kAXSizeAttribute),
              CFGetTypeID(pos) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        guard AXValueGetValue(pos as! AXValue, .cgPoint, &p), AXValueGetValue(size as! AXValue, .cgSize, &s) else { return nil }
        return CGRect(origin: p, size: s)
    }

    func isResizable(_ window: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &settable) == .success && settable.boolValue
    }

    /// Applies an AX-coordinate frame. Size is set twice so cross-display moves aren't clamped by the old screen.
    func setFrame(_ rect: CGRect, of window: AXUIElement, resize: Bool) {
        var origin = rect.origin, size = rect.size
        guard let pos = AXValueCreate(.cgPoint, &origin), let sz = AXValueCreate(.cgSize, &size) else { return }
        if resize { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz) }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        if resize { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz) }
    }

    // MARK: Snapping

    /// Snaps `window` into `layout` on `screen` (defaults to the screen holding the window's center).
    func snap(_ window: AXUIElement, to layout: SnapLayout, on screen: NSScreen? = nil, originalFrame: CGRect? = nil) {
        guard let current = frame(of: window) else { return }
        let appKitFrame = Coordinates.fromAX(current)
        let center = CGPoint(x: appKitFrame.midX, y: appKitFrame.midY)
        guard let target = screen ?? Coordinates.screen(containing: center) else { return }
        rememberOriginal(window, frame: originalFrame ?? current)
        let gap = CGFloat(Prefs.gap)
        var dest = layout.frame(in: target.visibleFrame, gap: gap, currentSize: current.size)
        let resizable = isResizable(window)
        if !resizable { dest = SnapLayout.centered(current.size, in: dest) }
        setFrame(Coordinates.toAX(dest), of: window, resize: resizable && layout != .center)
    }

    /// Restores the window to the frame it had before its first snap.
    func restore(_ window: AXUIElement) {
        guard let index = originals.firstIndex(where: { CFEqual($0.window, window) }) else { return }
        let saved = originals.remove(at: index).frame
        setFrame(saved, of: window, resize: isResizable(window))
    }

    private func rememberOriginal(_ window: AXUIElement, frame: CGRect) {
        guard !originals.contains(where: { CFEqual($0.window, window) }) else { return }
        originals.append((window, frame))
        if originals.count > 100 { originals.removeFirst() }
    }

    // MARK: Attribute helpers

    private func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }
}
