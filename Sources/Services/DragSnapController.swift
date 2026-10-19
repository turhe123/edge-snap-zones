import AppKit

/// Watches global mouse drags, shows a debounced preview when the pointer enters a snap zone,
/// and snaps the dragged window on release.
final class DragSnapController {
    private var monitors: [Any] = []
    private let preview = PreviewPanel()
    private let mover = WindowMover.shared
    private var downPoint: CGPoint = .zero
    private var resolved = false
    private var window: AXUIElement?
    private var startFrame: CGRect?
    private var shownLayout: SnapLayout?
    private var pending: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?

    /// Height of the title-bar strip (points) that must contain the mouse-down point.
    private let titleBarStrip: CGFloat = 40

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard !isRunning else { return }
        let masks: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = [
            (.leftMouseDown, { [weak self] _ in self?.mouseDown() }),
            (.leftMouseDragged, { [weak self] _ in self?.mouseDragged() }),
            (.leftMouseUp, { [weak self] _ in self?.mouseUp() }),
        ]
        monitors = masks.compactMap { NSEvent.addGlobalMonitorForEvents(matching: $0.0, handler: $0.1) }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.screensChanged() }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        reset()
    }

    // MARK: Events

    private func mouseDown() {
        reset()
        downPoint = NSEvent.mouseLocation
    }

    private func mouseDragged() {
        if !resolved {
            resolved = true
            resolveWindow()
        }
        guard window != nil else { return }
        let point = NSEvent.mouseLocation
        guard let screen = Coordinates.screen(containing: point) else { return }
        let layout = SnapLayout.zone(at: point, on: screen, sensitivity: CGFloat(Prefs.sensitivity))
        schedulePreview(layout, on: screen)
    }

    private func mouseUp() {
        defer { reset() }
        guard let window, let startFrame else { return }
        let point = NSEvent.mouseLocation
        guard let screen = Coordinates.screen(containing: point),
              let layout = SnapLayout.zone(at: point, on: screen, sensitivity: CGFloat(Prefs.sensitivity)),
              let now = mover.frame(of: window), now.origin != startFrame.origin else { return }
        // Let the owning app finish its own drag before we reposition the window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [mover] in
            mover.snap(window, to: layout, on: screen, originalFrame: startFrame)
        }
    }

    /// Accepts the window under the mouse-down point only if the press was in its title-bar strip.
    private func resolveWindow() {
        guard let candidate = mover.window(at: downPoint), let frame = mover.frame(of: candidate) else { return }
        let ax = Coordinates.toAX(downPoint)
        guard ax.x >= frame.minX, ax.x <= frame.maxX, ax.y >= frame.minY, ax.y <= frame.minY + titleBarStrip else { return }
        window = candidate
        startFrame = frame
    }

    // MARK: Preview

    /// Debounces preview changes so pointer jitter at an edge does not flicker the panel.
    private func schedulePreview(_ layout: SnapLayout?, on screen: NSScreen) {
        pending?.cancel()
        pending = nil
        guard layout != shownLayout else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.window != nil else { return }
            self.shownLayout = layout
            guard let layout, let window = self.window, let current = self.mover.frame(of: window) else {
                self.preview.hide()
                return
            }
            var target = layout.frame(in: screen.visibleFrame, gap: CGFloat(Prefs.gap), currentSize: current.size)
            if !self.mover.isResizable(window) { target = SnapLayout.centered(current.size, in: target) }
            self.preview.show(target)
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + (layout == nil ? 0.12 : 0.08), execute: item)
    }

    private func screensChanged() {
        // Zones are derived from NSScreen on every event; just drop any stale preview.
        shownLayout = nil
        preview.hide()
    }

    private func reset() {
        pending?.cancel()
        pending = nil
        resolved = false
        window = nil
        startFrame = nil
        shownLayout = nil
        preview.hide()
    }
}
