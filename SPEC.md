# EdgeSnapZones — specification

**Tagline:** Drag a window to a screen edge or corner and watch a preview before it snaps into halves, thirds or quarters.

**Category:** Window Management

**Inspired by (paid):** Magnet ($4.99 one-time)

**Frameworks:** SwiftUI, AppKit, ApplicationServices, CoreGraphics, Carbon, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

(1) What the paid app does. Magnet is a long-running Mac App Store window snapper sold for 4.99 dollars one time. Dragging a window to the left or right edge makes it fill that half, dragging to a corner makes it a quarter, and keyboard shortcuts do the same without a mouse. Evidence of demand: it is repeatedly named in comparisons against the free Rectangle app, has several hundred near five star ratings on the store and shows up in nearly every best window manager roundup. Our clean-room version is called EdgeSnapZones and focuses on the drag-to-edge behaviour plus a small set of hotkeys.

(2) Feature set. Drag any window by its title bar to a screen edge or corner. When the pointer enters a snap zone a translucent rounded preview rectangle appears showing the target frame. Releasing the mouse moves and resizes the window to that frame. Zones: left half, right half, top (maximize), four corners as quarters, and left, center and right thirds when the pointer is held on the lower edge zones. Keyboard shortcuts for the same layouts using Control plus Option plus arrow keys, plus Return to maximize and Control plus Option plus C to center. A restore action returns the window to its size from before the first snap. Respect the visible frame so the menu bar and Dock are never covered, and support multiple displays by snapping on whichever screen holds the pointer. Optional gap setting in points between snapped windows and screen edges.

(3) UI spec. A MenuBarExtra with a window-style or menu-style list showing each layout with its shortcut, an Enabled toggle, a Restore Original Size item, Settings and Quit. The Settings window is a SwiftUI form with: edge sensitivity slider from 2 to 30 points, gap size stepper, toggle for drag-to-snap, toggle for keyboard shortcuts, toggle for Launch at login, a list of apps to ignore, and an Accessibility status row with a button to open the privacy pane. The preview is a borderless NSPanel at floating level that ignores mouse events, uses a blurred material and a thin accent border, and fades in and out. Empty or disabled state: the menu bar icon is dimmed and the first menu row explains that Accessibility access is needed.

(4) Technical approach. Request Accessibility trust with AXIsProcessTrustedWithOptions and the prompt option, then poll until granted. Detect drags with a global NSEvent monitor for left mouse dragged and left mouse up events, which needs no extra permission beyond Accessibility. On the first drag event, read the window under the cursor using AXUIElementCopyElementAtPosition, walk up to the window element and confirm the subrole is standard window. Move and resize through the position and size attributes of the AX element, converting from AppKit bottom-left coordinates to the top-left Quartz coordinates used by Accessibility. Use NSScreen visibleFrame for each screen. Register global hotkeys with Carbon RegisterEventHotKey so no Input Monitoring is needed. Store settings with AppStorage and register launch at login with SMAppService main app. Target roughly 450 lines.

(5) Edge cases. Ignore drags that begin on non-title-bar areas by requiring the window frame top strip of 40 points to contain the mouse-down point. Windows that refuse resizing, such as fixed-size panels, should only be moved and centered in the zone. Full screen windows and sheets are skipped. If the pointer is released outside any zone, do nothing. Handle display changes by recomputing zones on the screen parameters notification. If Accessibility is revoked while running, stop monitors and show the warning row. Debounce the preview so it does not flicker when the pointer jitters at an edge.
