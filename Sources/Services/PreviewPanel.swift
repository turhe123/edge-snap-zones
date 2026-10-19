import AppKit

/// Borderless, click-through floating panel that shows a blurred, accent-bordered preview of the snap target.
final class PreviewPanel {
    private let panel: NSPanel
    private var visible = false

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 12
        blur.layer?.masksToBounds = true
        blur.layer?.borderWidth = 2
        blur.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.85).cgColor
        blur.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        panel.contentView = blur
    }

    /// Shows (fading in) or moves the preview to an AppKit-coordinate frame.
    func show(_ frame: CGRect) {
        if visible {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                panel.animator().setFrame(frame, display: true)
            }
            return
        }
        visible = true
        panel.contentView?.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.85).cgColor
        panel.setFrame(frame, display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    /// Fades the preview out.
    func hide() {
        guard visible else { return }
        visible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.visible else { return }
            self.panel.orderOut(nil)
        })
    }
}
