import AppKit

struct AlignmentGuide: Equatable {
    enum Orientation {
        case vertical
        case horizontal
    }

    let orientation: Orientation
    let position: CGFloat
}

struct WidgetDragFeedback {
    let origin: CGPoint
    let guides: [AlignmentGuide]
}

final class WidgetPositionManager {
    func gridOrigins(
        for sizes: [CGSize],
        in frame: CGRect,
        spacing: CGFloat = 20,
        margin: CGFloat = 40
    ) -> [CGPoint] {
        var origins: [CGPoint] = []
        var cursor = CGPoint(x: frame.minX + margin, y: frame.maxY - margin)
        var rowHeight: CGFloat = 0

        for size in sizes {
            if cursor.x + size.width > frame.maxX - margin {
                cursor.x = frame.minX + margin
                cursor.y -= rowHeight + spacing
                rowHeight = 0
            }

            let origin = CGPoint(x: cursor.x, y: cursor.y - size.height)
            origins.append(origin)

            rowHeight = max(rowHeight, size.height)
            cursor.x += size.width + spacing
        }

        return origins
    }

    func dragFeedback(
        for proposedFrame: CGRect,
        against otherFrames: [CGRect],
        snapThreshold: CGFloat = 8
    ) -> WidgetDragFeedback {
        guard !otherFrames.isEmpty else {
            return WidgetDragFeedback(origin: proposedFrame.origin, guides: [])
        }

        var adjustedOrigin = proposedFrame.origin
        var guides: [AlignmentGuide] = []

        let xCandidates = [
            proposedFrame.minX,
            proposedFrame.midX,
            proposedFrame.maxX
        ]

        var bestXDelta: CGFloat?
        var bestXGuide: AlignmentGuide?

        for frame in otherFrames {
            let anchors = [frame.minX, frame.midX, frame.maxX]

            for candidate in xCandidates {
                for anchor in anchors {
                    let delta = anchor - candidate
                    guard abs(delta) <= snapThreshold else { continue }

                    if let current = bestXDelta, abs(delta) >= abs(current) {
                        continue
                    }

                    bestXDelta = delta
                    bestXGuide = AlignmentGuide(orientation: .vertical, position: anchor)
                }
            }
        }

        if let bestXDelta {
            adjustedOrigin.x += bestXDelta
        }

        let adjustedFrame = CGRect(origin: adjustedOrigin, size: proposedFrame.size)
        let adjustedYCandidates = [
            adjustedFrame.minY,
            adjustedFrame.midY,
            adjustedFrame.maxY
        ]

        var bestYDelta: CGFloat?
        var bestYGuide: AlignmentGuide?

        for frame in otherFrames {
            let anchors = [frame.minY, frame.midY, frame.maxY]

            for candidate in adjustedYCandidates {
                for anchor in anchors {
                    let delta = anchor - candidate
                    guard abs(delta) <= snapThreshold else { continue }

                    if let current = bestYDelta, abs(delta) >= abs(current) {
                        continue
                    }

                    bestYDelta = delta
                    bestYGuide = AlignmentGuide(orientation: .horizontal, position: anchor)
                }
            }
        }

        if let bestYDelta {
            adjustedOrigin.y += bestYDelta
        }

        if let bestXGuide {
            guides.append(bestXGuide)
        }

        if let bestYGuide {
            guides.append(bestYGuide)
        }

        return WidgetDragFeedback(origin: adjustedOrigin, guides: guides)
    }
}
