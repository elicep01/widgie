import AppKit
import QuartzCore

@MainActor
enum WidgetAnimator {
    static func animateAppearance(of window: NSWindow) {
        let originalFrame = window.frame
        let startFrame = NSRect(
            x: originalFrame.origin.x,
            y: originalFrame.origin.y,
            width: originalFrame.width * 0.95,
            height: originalFrame.height * 0.95
        )

        window.setFrame(startFrame, display: false)
        window.alphaValue = 0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.30
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
            window.animator().setFrame(originalFrame, display: true)
        }
    }

    static func animateRemoval(of window: NSWindow, completion: @escaping () -> Void) {
        let frame = window.frame
        let target = NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.width * 0.95,
            height: frame.height * 0.95
        )

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 0
                window.animator().setFrame(target, display: true)
            },
            completionHandler: completion
        )
    }

    static func animateDragStart(of window: NSWindow) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0.60
        }
    }

    static func animateDragEnd(of window: NSWindow, to targetOrigin: NSPoint) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
            window.animator().setFrameOrigin(targetOrigin)
        }
    }

    static func animateResizeRelease(of window: NSWindow) {
        guard let layer = window.contentView?.layer else {
            return
        }

        let fromTransform = CATransform3DMakeScale(1.012, 1.012, 1)
        let toTransform = CATransform3DIdentity

        let animation = CASpringAnimation(keyPath: "transform")
        animation.fromValue = fromTransform
        animation.toValue = toTransform
        animation.initialVelocity = 1.5
        animation.mass = 0.85
        animation.stiffness = 210
        animation.damping = 20
        animation.duration = animation.settlingDuration

        layer.add(animation, forKey: "widgetResizeRelease")
        layer.transform = toTransform
    }
}
