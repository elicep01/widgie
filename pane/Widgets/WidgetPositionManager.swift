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
        screenFrame: CGRect? = nil,
        snapThreshold: CGFloat = 8
    ) -> WidgetDragFeedback {
        guard !otherFrames.isEmpty || screenFrame != nil else {
            return WidgetDragFeedback(origin: proposedFrame.origin, guides: [])
        }

        var adjustedOrigin = proposedFrame.origin
        var guides: [AlignmentGuide] = []

        // --- Widget-to-widget X snapping ---
        let xCandidates = [proposedFrame.minX, proposedFrame.midX, proposedFrame.maxX]
        var bestXDelta: CGFloat?
        var bestXGuide: AlignmentGuide?

        for frame in otherFrames {
            let anchors = [frame.minX, frame.midX, frame.maxX]
            for candidate in xCandidates {
                for anchor in anchors {
                    let delta = anchor - candidate
                    guard abs(delta) <= snapThreshold else { continue }
                    if let current = bestXDelta, abs(delta) >= abs(current) { continue }
                    bestXDelta = delta
                    bestXGuide = AlignmentGuide(orientation: .vertical, position: anchor)
                }
            }
        }

        // --- Screen edge X snapping (wider threshold, only edge-to-edge) ---
        let edgeThreshold: CGFloat = 16
        if let screenFrame {
            let edgePairs: [(CGFloat, CGFloat)] = [
                (screenFrame.minX - proposedFrame.minX, screenFrame.minX),
                (screenFrame.maxX - proposedFrame.maxX, screenFrame.maxX)
            ]
            for (delta, position) in edgePairs {
                guard abs(delta) <= edgeThreshold else { continue }
                if let current = bestXDelta, abs(delta) >= abs(current) { continue }
                bestXDelta = delta
                bestXGuide = AlignmentGuide(orientation: .vertical, position: position)
            }
        }

        if let bestXDelta { adjustedOrigin.x += bestXDelta }

        // --- Widget-to-widget Y snapping (use x-adjusted frame) ---
        let adjustedFrame = CGRect(origin: adjustedOrigin, size: proposedFrame.size)
        let adjustedYCandidates = [adjustedFrame.minY, adjustedFrame.midY, adjustedFrame.maxY]
        var bestYDelta: CGFloat?
        var bestYGuide: AlignmentGuide?

        for frame in otherFrames {
            let anchors = [frame.minY, frame.midY, frame.maxY]
            for candidate in adjustedYCandidates {
                for anchor in anchors {
                    let delta = anchor - candidate
                    guard abs(delta) <= snapThreshold else { continue }
                    if let current = bestYDelta, abs(delta) >= abs(current) { continue }
                    bestYDelta = delta
                    bestYGuide = AlignmentGuide(orientation: .horizontal, position: anchor)
                }
            }
        }

        // --- Screen edge Y snapping ---
        if let screenFrame {
            let edgePairs: [(CGFloat, CGFloat)] = [
                (screenFrame.minY - adjustedFrame.minY, screenFrame.minY),
                (screenFrame.maxY - adjustedFrame.maxY, screenFrame.maxY)
            ]
            for (delta, position) in edgePairs {
                guard abs(delta) <= edgeThreshold else { continue }
                if let current = bestYDelta, abs(delta) >= abs(current) { continue }
                bestYDelta = delta
                bestYGuide = AlignmentGuide(orientation: .horizontal, position: position)
            }
        }

        if let bestYDelta { adjustedOrigin.y += bestYDelta }

        if let bestXGuide { guides.append(bestXGuide) }
        if let bestYGuide { guides.append(bestYGuide) }

        return WidgetDragFeedback(origin: adjustedOrigin, guides: guides)
    }

    func clampedOrigin(
        _ origin: CGPoint,
        size: CGSize,
        in frame: CGRect,
        margin: CGFloat = 28
    ) -> CGPoint {
        let minX = frame.minX + margin
        let maxX = max(minX, frame.maxX - margin - size.width)
        let minY = frame.minY + margin
        let maxY = max(minY, frame.maxY - margin - size.height)
        return CGPoint(
            x: origin.x.clamped(minX, maxX),
            y: origin.y.clamped(minY, maxY)
        )
    }

    /// Grid step for placement — all auto-placed widgets land on multiples of this
    /// value relative to screen edges, producing clean, uniform positions.
    private static let gridStep: CGFloat = 40

    /// Snap a coordinate to the nearest grid line relative to a screen-edge anchor.
    private func snapToGrid(_ value: CGFloat, anchor: CGFloat) -> CGFloat {
        let offset = value - anchor
        return anchor + (offset / Self.gridStep).rounded() * Self.gridStep
    }

    func firstAvailableOrigin(
        for size: CGSize,
        in frame: CGRect,
        occupied: [CGRect],
        margin: CGFloat = 28,
        scanStep: CGFloat = 24
    ) -> CGPoint? {
        let step = Self.gridStep
        // Snap margins to grid so all placements align cleanly.
        let minX = snapToGrid(frame.minX + margin, anchor: frame.minX)
        let maxX = frame.maxX - margin - size.width
        let minY = snapToGrid(frame.minY + margin, anchor: frame.minY)
        let maxY = frame.maxY - margin - size.height

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        // Scan from top-right corner inward. Widgets placed near the right edge
        // look intentional and leave the desktop center open.
        let targetX = snapToGrid(maxX, anchor: frame.minX)
        let targetY = snapToGrid(maxY, anchor: frame.minY)

        struct Candidate {
            let point: CGPoint
            let distSq: CGFloat
        }

        var candidates: [Candidate] = []
        var y = snapToGrid(minY, anchor: frame.minY)
        while y <= maxY {
            var x = minX
            while x <= maxX {
                let dx = x - targetX
                let dy = y - targetY
                candidates.append(Candidate(point: CGPoint(x: x, y: y), distSq: dx * dx + dy * dy))
                x += step
            }
            y += step
        }

        candidates.sort { $0.distSq < $1.distSq }

        for candidate in candidates {
            let rect = CGRect(origin: candidate.point, size: size)
            if occupied.allSatisfy({ !$0.intersects(rect) }) {
                return candidate.point
            }
        }

        return nil
    }

    func bestEffortOrigin(
        for size: CGSize,
        in frame: CGRect,
        occupied: [CGRect],
        margin: CGFloat = 28,
        scanStep: CGFloat = 28
    ) -> CGPoint {
        let step = Self.gridStep
        let snappedDefault = CGPoint(
            x: snapToGrid(frame.maxX - margin - size.width, anchor: frame.minX),
            y: snapToGrid(frame.maxY - margin - size.height, anchor: frame.minY)
        )
        let clampedDefault = clampedOrigin(snappedDefault, size: size, in: frame, margin: margin)

        let minX = snapToGrid(frame.minX + margin, anchor: frame.minX)
        let maxX = frame.maxX - margin - size.width
        let minY = snapToGrid(frame.minY + margin, anchor: frame.minY)
        let startY = snapToGrid(frame.maxY - margin - size.height, anchor: frame.minY)
        guard maxX >= minX, startY >= minY else {
            return clampedDefault
        }

        var bestOrigin = clampedDefault
        var bestScore = CGFloat.greatestFiniteMagnitude

        var y = startY
        while y >= minY {
            var x = snapToGrid(maxX, anchor: frame.minX)
            while x >= minX {
                let candidate = CGRect(origin: CGPoint(x: x, y: y), size: size)
                let overlapArea = occupied.reduce(CGFloat(0)) { partial, obstacle in
                    partial + candidate.intersection(obstacle).area
                }
                // Prefer top-right region — widgets near screen edges look clean and intentional.
                let edgeXBias = (frame.maxX - candidate.maxX) * 0.05
                let edgeYBias = (frame.maxY - candidate.maxY) * 0.05
                let score = overlapArea + edgeXBias + edgeYBias
                if score < bestScore {
                    bestScore = score
                    bestOrigin = candidate.origin
                }
                x -= step
            }
            y -= step
        }

        return bestOrigin
    }
}

private extension CGFloat {
    func clamped(_ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, minValue), maxValue)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
    }
}
