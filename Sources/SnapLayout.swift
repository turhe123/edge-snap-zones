import AppKit

/// A target layout a window can be snapped into, plus the geometry that computes its frame.
enum SnapLayout: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf, maximize
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird
    case center

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .maximize: return "Maximize"
        case .topLeft: return "Top Left Quarter"
        case .topRight: return "Top Right Quarter"
        case .bottomLeft: return "Bottom Left Quarter"
        case .bottomRight: return "Bottom Right Quarter"
        case .leftThird: return "Left Third"
        case .centerThird: return "Center Third"
        case .rightThird: return "Right Third"
        case .center: return "Center"
        }
    }

    var symbol: String {
        switch self {
        case .leftHalf: return "rectangle.lefthalf.filled"
        case .rightHalf: return "rectangle.righthalf.filled"
        case .topHalf: return "rectangle.tophalf.filled"
        case .bottomHalf: return "rectangle.bottomhalf.filled"
        case .maximize: return "rectangle.fill"
        case .topLeft: return "rectangle.inset.topleft.filled"
        case .topRight: return "rectangle.inset.topright.filled"
        case .bottomLeft: return "rectangle.inset.bottomleft.filled"
        case .bottomRight: return "rectangle.inset.bottomright.filled"
        case .leftThird: return "rectangle.leadingthird.inset.filled"
        case .centerThird: return "rectangle.center.inset.filled"
        case .rightThird: return "rectangle.trailingthird.inset.filled"
        case .center: return "dot.square"
        }
    }

    /// Target frame in AppKit (bottom-left origin) coordinates inside `visible`, honoring `gap` points.
    func frame(in visible: CGRect, gap: CGFloat, currentSize: CGSize) -> CGRect {
        let r = visible.insetBy(dx: gap, dy: gap)
        let hw = (r.width - gap) / 2, hh = (r.height - gap) / 2
        let tw = (r.width - 2 * gap) / 3
        let rightX = r.minX + hw + gap, topY = r.minY + hh + gap
        switch self {
        case .leftHalf: return CGRect(x: r.minX, y: r.minY, width: hw, height: r.height)
        case .rightHalf: return CGRect(x: rightX, y: r.minY, width: hw, height: r.height)
        case .topHalf: return CGRect(x: r.minX, y: topY, width: r.width, height: hh)
        case .bottomHalf: return CGRect(x: r.minX, y: r.minY, width: r.width, height: hh)
        case .maximize: return r
        case .topLeft: return CGRect(x: r.minX, y: topY, width: hw, height: hh)
        case .topRight: return CGRect(x: rightX, y: topY, width: hw, height: hh)
        case .bottomLeft: return CGRect(x: r.minX, y: r.minY, width: hw, height: hh)
        case .bottomRight: return CGRect(x: rightX, y: r.minY, width: hw, height: hh)
        case .leftThird: return CGRect(x: r.minX, y: r.minY, width: tw, height: r.height)
        case .centerThird: return CGRect(x: r.minX + tw + gap, y: r.minY, width: tw, height: r.height)
        case .rightThird: return CGRect(x: r.minX + 2 * (tw + gap), y: r.minY, width: tw, height: r.height)
        case .center: return SnapLayout.centered(currentSize, in: r)
        }
    }

    /// Centers `size` (clamped to the rect) inside `rect`.
    static func centered(_ size: CGSize, in rect: CGRect) -> CGRect {
        let w = min(size.width, rect.width), h = min(size.height, rect.height)
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }

    /// The drag zone (if any) under `point` on `screen`; `sensitivity` is the edge thickness in points.
    static func zone(at point: CGPoint, on screen: NSScreen, sensitivity: CGFloat) -> SnapLayout? {
        let f = screen.frame
        let corner = max(60, sensitivity * 3)
        let nearLeft = point.x <= f.minX + sensitivity, nearRight = point.x >= f.maxX - sensitivity - 1
        let nearTop = point.y >= f.maxY - sensitivity - 1, nearBottom = point.y <= f.minY + sensitivity
        let inTopBand = point.y >= f.maxY - corner, inBottomBand = point.y <= f.minY + corner
        let inLeftBand = point.x <= f.minX + corner, inRightBand = point.x >= f.maxX - corner
        if nearLeft { return inTopBand ? .topLeft : inBottomBand ? .bottomLeft : .leftHalf }
        if nearRight { return inTopBand ? .topRight : inBottomBand ? .bottomRight : .rightHalf }
        if nearTop { return inLeftBand ? .topLeft : inRightBand ? .topRight : .maximize }
        if nearBottom {
            if inLeftBand { return .bottomLeft }
            if inRightBand { return .bottomRight }
            let third = Int((point.x - f.minX) / (f.width / 3))
            return [.leftThird, .centerThird, .rightThird][min(max(third, 0), 2)]
        }
        return nil
    }
}

/// Converts between AppKit (bottom-left origin) and Quartz/Accessibility (top-left origin) coordinates.
enum Coordinates {
    static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

    static func toAX(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func fromAX(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func toAX(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x, y: primaryHeight - point.y) }

    static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
    }
}
