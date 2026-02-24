import Foundation

enum WidgetSizePreset: String, CaseIterable, Identifiable {
    case tiny
    case small
    case medium
    case wide
    case large
    case dashboard

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var size: WidgetSize {
        switch self {
        case .tiny:
            return .tiny
        case .small:
            return .small
        case .medium:
            return .medium
        case .wide:
            return .wide
        case .large:
            return .large
        case .dashboard:
            return .dashboard
        }
    }

    /// Discrete resize order used by desktop handle drag. This mimics native widget
    /// class switching instead of freeform pixel resizing.
    static let nativeResizeOrder: [WidgetSizePreset] = [
        .small, .medium, .wide, .large, .dashboard
    ]

    static func nearest(to size: WidgetSize) -> WidgetSizePreset {
        nativeResizeOrder.min { lhs, rhs in
            distanceSquared(size, lhs.size) < distanceSquared(size, rhs.size)
        } ?? .medium
    }

    static func stepped(from preset: WidgetSizePreset, deltaSteps: Int) -> WidgetSizePreset {
        let order = nativeResizeOrder
        guard let index = order.firstIndex(of: preset) else {
            return .medium
        }
        let nextIndex = max(0, min(order.count - 1, index + deltaSteps))
        return order[nextIndex]
    }

    private static func distanceSquared(_ lhs: WidgetSize, _ rhs: WidgetSize) -> Double {
        let dw = lhs.width - rhs.width
        let dh = lhs.height - rhs.height
        return (dw * dw) + (dh * dh)
    }
}
