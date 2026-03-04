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

    func firstAvailableOrigin(
        for size: CGSize,
        in frame: CGRect,
        occupied: [CGRect],
        margin: CGFloat = 28,
        scanStep: CGFloat = 24
    ) -> CGPoint? {
        let minX = frame.minX + margin
        let maxX = frame.maxX - margin - size.width
        let minY = frame.minY + margin
        let maxY = frame.maxY - margin - size.height

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        // Scan all candidates sorted by distance from screen center so new widgets
        // appear in a visible, easy-to-find location instead of a corner.
        let targetX = (frame.midX - size.width / 2).clamped(minX, maxX)
        let targetY = (frame.midY - size.height / 2).clamped(minY, maxY)

        struct Candidate {
            let point: CGPoint
            let distSq: CGFloat
        }

        var candidates: [Candidate] = []
        var y = minY
        while y <= maxY {
            var x = minX
            while x <= maxX {
                let dx = x - targetX
                let dy = y - targetY
                candidates.append(Candidate(point: CGPoint(x: x, y: y), distSq: dx * dx + dy * dy))
                x += scanStep
            }
            y += scanStep
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
        let clampedDefault = clampedOrigin(
            CGPoint(x: frame.minX + margin, y: frame.maxY - margin - size.height),
            size: size,
            in: frame,
            margin: margin
        )
        let minX = frame.minX + margin
        let maxX = frame.maxX - margin - size.width
        let minY = frame.minY + margin
        let startY = frame.maxY - margin - size.height
        guard maxX >= minX, startY >= minY else {
            return clampedDefault
        }

        var bestOrigin = clampedDefault
        var bestScore = CGFloat.greatestFiniteMagnitude

        var y = startY
        while y >= minY {
            var x = minX
            while x <= maxX {
                let candidate = CGRect(origin: CGPoint(x: x, y: y), size: size)
                let overlapArea = occupied.reduce(CGFloat(0)) { partial, obstacle in
                    partial + candidate.intersection(obstacle).area
                }
                // Prefer center-screen over corners for new widget discoverability.
                let centerXBias = abs(candidate.midX - frame.midX) * 0.15
                let centerYBias = abs(candidate.midY - frame.midY) * 0.10
                let score = overlapArea + centerXBias + centerYBias
                if score < bestScore {
                    bestScore = score
                    bestOrigin = candidate.origin
                }
                x += scanStep
            }
            y -= scanStep
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
