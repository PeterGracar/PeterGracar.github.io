import SwiftUI
import UIKit

/// Captures trackpad two-finger pan events and forwards their per-frame
/// screen-space delta. Implemented as a UIKit pan recognizer with
/// `allowedScrollTypesMask = .continuous`, since SwiftUI's `DragGesture`
/// only sees finger / pointer touches, not scroll-wheel events.
struct TrackpadPanCatcher: UIViewRepresentable {
    var onPan: (CGSize) -> Void
    var onEnd: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPan: onPan, onEnd: onEnd)
    }

    func makeUIView(context: Context) -> ScrollOnlyView {
        let view = ScrollOnlyView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let recognizer = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        recognizer.allowedScrollTypesMask = .continuous
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: ScrollOnlyView, context: Context) {
        context.coordinator.onPan = onPan
        context.coordinator.onEnd = onEnd
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPan: (CGSize) -> Void
        var onEnd: () -> Void
        private var lastTranslation: CGPoint = .zero

        init(onPan: @escaping (CGSize) -> Void, onEnd: @escaping () -> Void) {
            self.onPan = onPan
            self.onEnd = onEnd
        }

        @objc func handle(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                lastTranslation = .zero
            case .changed:
                let t = recognizer.translation(in: recognizer.view)
                let dx = t.x - lastTranslation.x
                let dy = t.y - lastTranslation.y
                lastTranslation = t
                if dx != 0 || dy != 0 {
                    onPan(CGSize(width: dx, height: dy))
                }
            case .ended, .cancelled, .failed:
                onEnd()
                lastTranslation = .zero
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            // Don't fight other recognizers — pinch-zoom in particular needs
            // to keep working while the trackpad pan is active.
            true
        }
    }
}

/// Hit-tests positive only for scroll events. Touch events (finger taps,
/// pinch gestures, indirect-pointer drags) fall through to whichever
/// SwiftUI gesture is configured on the canvas underneath.
final class ScrollOnlyView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        event?.type == .scroll
    }
}
