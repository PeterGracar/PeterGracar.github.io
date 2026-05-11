import SwiftUI
import UIKit

/// A SwiftUI wrapper around a `UIView` that draws via a closure receiving a
/// raw `CGContext`. SwiftUI's own `Canvas` adds enough per-frame overhead on
/// top of CoreGraphics that high-N particle scenes drop to single-digit
/// framerates; going through `UIView.draw(_:)` directly closes the gap.
///
/// Two key knobs:
///   * `layer.drawsAsynchronously = true` — CG commands captured in
///     `draw(_:)` are dispatched to a background queue for tessellation and
///     rasterisation, freeing the main thread.
///   * `CADisplayLink` — drives `setNeedsDisplay` at the display refresh
///     rate, so we redraw without depending on SwiftUI's body re-eval cycle.
struct CGCanvas: UIViewRepresentable {
    let render: (CGContext, CGSize) -> Void

    func makeUIView(context: Context) -> CGCanvasView {
        let view = CGCanvasView()
        view.render = render
        return view
    }

    func updateUIView(_ uiView: CGCanvasView, context: Context) {
        uiView.render = render
    }

    @MainActor
    static func dismantleUIView(_ uiView: CGCanvasView, coordinator: ()) {
        uiView.tearDown()
    }
}

final class CGCanvasView: UIView {
    var render: ((CGContext, CGSize) -> Void)?

    // `CADisplayLink` is not Sendable, but `invalidate()` is documented as
    // safe to call from any thread, and we only ever read this property
    // from `init` (main) and `deinit` (whichever thread releases the last
    // reference). `nonisolated(unsafe)` promises the compiler we own that
    // contract so it lets `deinit` touch the property.
    nonisolated(unsafe) private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        layer.drawsAsynchronously = true

        let dl = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        dl.add(to: .main, forMode: .common)
        displayLink = dl
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    @objc private func displayLinkFired() {
        setNeedsDisplay()
    }

    func tearDown() {
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit {
        // Inline the cleanup rather than calling the @MainActor-isolated
        // tearDown(): deinit isn't actor-isolated, and CADisplayLink's
        // invalidate() is documented as safe to call from any thread.
        displayLink?.invalidate()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        render?(ctx, bounds.size)
    }
}
