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
}
