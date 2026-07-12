import SwiftUI

enum TrackMode: String, CaseIterable, Identifiable, Hashable {
    case bm, levy, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bm: return "BM"
        case .levy: return "Lévy"
        case .both: return "Both"
        }
    }
}

struct SimulationCanvas: View {
    @Environment(LBMSimulation.self) private var sim

    @State private var camX: Double = 0
    @State private var camY: Double = 0
    @State private var camZoom: Double = 1
    @State private var manualCamera: Bool = false
    @State private var trackMode: TrackMode = .both
    @State private var canvasSize: CGSize = .zero
    @State private var dragStartCam: SIMD2<Double>? = nil
    @State private var pinchStartZoom: Double? = nil
    @State private var pinchStartCam: SIMD2<Double>? = nil
    /// Pinch anchor in viewport-centred coordinates (i.e. screen point minus
    /// canvas centre). Stays fixed for the lifetime of the gesture so that
    /// the same world point sits under the user's fingers throughout.
    @State private var pinchAnchor: SIMD2<Double>? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let _ = timeline.date
                    Canvas { context, size in
                        draw(context: context, size: size)
                    }
                }
                .contentShape(Rectangle())
                .gesture(panGesture)
                .simultaneousGesture(zoomGesture)

                TrackpadPanCatcher(
                    onPan: { delta in
                        manualCamera = true
                        let dx = Double(delta.width) / max(camZoom, 1e-9)
                        let dy = Double(delta.height) / max(camZoom, 1e-9)
                        camX -= dx
                        camY -= dy
                    },
                    onEnd: {}
                )

                VStack {
                    HStack {
                        trackingPill
                        Spacer()
                    }
                    Spacer()
                }
                .padding(12)
                .allowsHitTesting(true)
            }
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
        }
        .background(Color(.tertiarySystemBackground))
        .task {
            await runLoop()
        }
    }

    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            sim.tickIfRunning()
            updateCamera(canvasSize: canvasSize)
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    // MARK: - Camera

    private func updateCamera(canvasSize: CGSize) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        guard !manualCamera else { return }
        let target = computeCameraTarget(canvasSize: canvasSize)
        let lerpRate = 0.06
        camX = lerp(camX, target.x, lerpRate)
        camY = lerp(camY, target.y, lerpRate)
        let logZoom = lerp(log(max(1e-9, camZoom)), log(max(1e-9, target.zoom)), lerpRate)
        camZoom = exp(logZoom)
    }

    private func computeCameraTarget(canvasSize: CGSize) -> (x: Double, y: Double, zoom: Double) {
        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity

        let consider = { (p: LBMPoint) in
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }

        let trackBM = (trackMode == .bm || trackMode == .both) && sim.showBrownian
        let trackLevy = (trackMode == .levy || trackMode == .both) && sim.showLevy
        if trackLevy { sim.levy.forEach(consider) }
        if trackBM { sim.brownian.forEach(consider) }
        // Fall back to whatever is visible if the chosen track target has no
        // points (e.g. user picked "Lévy" but Lévy is hidden).
        if minX == .infinity {
            if sim.showLevy { sim.levy.forEach(consider) }
            if sim.showBrownian { sim.brownian.forEach(consider) }
        }
        if minX == .infinity {
            return (0, 0, 1)
        }
        let pad = sim.showSausage ? sim.sausageRadius : 0
        minX -= pad; maxX += pad; minY -= pad; maxY += pad

        let cW = max(maxX - minX, 100)
        let cH = max(maxY - minY, 100)
        let margin: Double = 50
        let availW = max(Double(canvasSize.width) - margin * 2, 1)
        let availH = max(Double(canvasSize.height) - margin * 2, 1)
        let zoom = min(availW / cW, availH / cH)
        return (
            x: (minX + maxX) / 2,
            y: (minY + maxY) / 2,
            zoom: zoom
        )
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStartCam == nil {
                    dragStartCam = SIMD2<Double>(camX, camY)
                    manualCamera = true
                }
                let start = dragStartCam!
                let dx = Double(value.translation.width) / max(camZoom, 1e-9)
                let dy = Double(value.translation.height) / max(camZoom, 1e-9)
                camX = start.x - dx
                camY = start.y - dy
            }
            .onEnded { _ in
                dragStartCam = nil
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                if pinchStartZoom == nil {
                    pinchStartZoom = camZoom
                    pinchStartCam = SIMD2<Double>(camX, camY)
                    let centerX = Double(canvasSize.width) / 2
                    let centerY = Double(canvasSize.height) / 2
                    let loc = value.startLocation
                    pinchAnchor = SIMD2<Double>(
                        Double(loc.x) - centerX,
                        Double(loc.y) - centerY
                    )
                    manualCamera = true
                }
                let startZoom = pinchStartZoom!
                let startCam = pinchStartCam!
                let anchor = pinchAnchor!
                let newZoom = max(1e-4, min(100, startZoom * Double(value.magnification)))
                // World point under the anchor at the start of the gesture.
                // Keep it nailed there as we change zoom: solve
                //   anchor / newZoom + camNew = anchor / startZoom + startCam
                // for camNew.
                let worldX = anchor.x / startZoom + startCam.x
                let worldY = anchor.y / startZoom + startCam.y
                camX = worldX - anchor.x / newZoom
                camY = worldY - anchor.y / newZoom
                camZoom = newZoom
            }
            .onEnded { _ in
                pinchStartZoom = nil
                pinchStartCam = nil
                pinchAnchor = nil
            }
    }

    // MARK: - Tracking pill

    private var trackingPill: some View {
        HStack(spacing: 6) {
            ForEach(TrackMode.allCases) { mode in
                trackButton(mode)
            }
        }
    }

    @ViewBuilder
    private func trackButton(_ mode: TrackMode) -> some View {
        let active = !manualCamera && trackMode == mode
        let label = Text(mode.label)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 4)
        if active {
            Button {
                trackMode = mode
                manualCamera = false
            } label: { label }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .accessibilityLabel("Track \(mode.label)")
        } else {
            Button {
                trackMode = mode
                manualCamera = false
            } label: { label }
                .buttonStyle(.glass)
                .controlSize(.small)
                .accessibilityLabel("Track \(mode.label)")
        }
    }

    // MARK: - Draw

    private func draw(context: GraphicsContext, size: CGSize) {
        // Background
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(.systemBackground))
        )

        var ctx = context
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.scaleBy(x: camZoom, y: camZoom)
        ctx.translateBy(x: -camX, y: -camY)

        if sim.showBrownian {
            drawBrownian(ctx: ctx)
        }
        if sim.showLevy {
            drawLevy(ctx: ctx, viewSize: size)
        }

        // Legend (in screen-space, drawn via the original context).
        if sim.showLevy {
            drawLegend(in: context, size: size)
        }
    }

    private func drawBrownian(ctx: GraphicsContext) {
        let points = sim.brownian
        guard points.count >= 2 else { return }

        var path = Path()
        path.move(to: CGPoint(x: points[0].x, y: points[0].y))
        for i in 1..<points.count {
            path.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
        }

        if sim.showSausage {
            let sausageColor = Color(.systemGray).opacity(0.18)
            ctx.stroke(
                path,
                with: .color(sausageColor),
                style: StrokeStyle(
                    lineWidth: 2 * sim.sausageRadius,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }

        let strokeWidth = max(1.5, 2.5 / camZoom)
        ctx.stroke(
            path,
            with: .color(.primary),
            style: StrokeStyle(
                lineWidth: strokeWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private func drawLevy(ctx: GraphicsContext, viewSize: CGSize) {
        let points = sim.levy
        guard !points.isEmpty else { return }

        let cyclePeriod = sim.cyclePeriod
        let now = sim.time
        let pointSize = max(1.5, 3 / camZoom)
        let half = pointSize / 2

        // Pass 1: gray "trace" underlay for archived points (older than the
        // cycle period). Single Path, single fill, so overlapping squares
        // compose into a uniform shade rather than alpha-stacking.
        var tracePath = Path()
        for p in points {
            let age = Double(now - p.time) / cyclePeriod
            if age < 1 { continue }
            if sim.showSausage {
                tracePath.addEllipse(in: CGRect(
                    x: p.x - sim.sausageRadius,
                    y: p.y - sim.sausageRadius,
                    width: 2 * sim.sausageRadius,
                    height: 2 * sim.sausageRadius
                ))
            } else {
                tracePath.addRect(CGRect(
                    x: p.x - half,
                    y: p.y - half,
                    width: pointSize,
                    height: pointSize
                ))
            }
        }
        ctx.fill(tracePath, with: .color(Color.secondary.opacity(0.18)))

        // Pass 2: connector polyline between successive Lévy points.
        if points.count >= 2 {
            var line = Path()
            line.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for i in 1..<points.count {
                line.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
            }
            ctx.stroke(
                line,
                with: .color(Color.secondary.opacity(0.55)),
                style: StrokeStyle(
                    lineWidth: max(0.75, 1 / camZoom),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }

        // Pass 3: hue-cycled overlay for active points (within cycle period).
        for p in points {
            let age = Double(now - p.time) / cyclePeriod
            if age >= 1 { continue }
            let alpha = max(0, 1 - age)
            let hue = ((Double(p.time) * sim.colorSpeedFactor)
                .truncatingRemainder(dividingBy: 360)) / 360.0
            let saturation = max(0, 0.85 - 0.4 * age)
            let brightness = max(0, min(1, 0.55 + 0.25 * age))
            let color = Color(
                hue: hue >= 0 ? hue : hue + 1,
                saturation: saturation,
                brightness: brightness,
                opacity: alpha
            )
            if sim.showSausage {
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: p.x - sim.sausageRadius,
                        y: p.y - sim.sausageRadius,
                        width: 2 * sim.sausageRadius,
                        height: 2 * sim.sausageRadius
                    )),
                    with: .color(color)
                )
            } else {
                ctx.fill(
                    Path(CGRect(
                        x: p.x - half,
                        y: p.y - half,
                        width: pointSize,
                        height: pointSize
                    )),
                    with: .color(color)
                )
            }
        }
    }

    private func drawLegend(in context: GraphicsContext, size: CGSize) {
        let minDim = min(Double(size.width), Double(size.height))
        let barW = max(180.0, minDim * 0.35)
        let barH = max(12.0, minDim * 0.022)
        let startX = Double(size.width) - barW - 24
        let startY = Double(size.height) - barH - 24

        // Pill background
        let bgRect = CGRect(
            x: startX - 10,
            y: startY - barH * 1.5 - 4,
            width: barW + 20,
            height: barH * 2.5 + 12
        )
        context.fill(
            Path(roundedRect: bgRect, cornerRadius: 8),
            with: .color(Color(.systemBackground).opacity(0.9))
        )

        // Hue gradient
        let steps = 60
        let sliceW = barW / Double(steps)
        let now = sim.time
        let cyclePeriod = sim.cyclePeriod
        for i in 0..<steps {
            let ageRatio = 1.0 - Double(i) / Double(max(1, steps - 1))
            let pseudoTime = Double(now) - ageRatio * cyclePeriod
            let hue = (pseudoTime * sim.colorSpeedFactor)
                .truncatingRemainder(dividingBy: 360) / 360.0
            let saturation = max(0, 0.85 - 0.4 * ageRatio)
            let brightness = max(0, min(1, 0.55 + 0.25 * ageRatio))
            let alpha = max(0, 1 - ageRatio)
            context.fill(
                Path(CGRect(
                    x: startX + Double(i) * sliceW,
                    y: startY,
                    width: sliceW + 1,
                    height: barH
                )),
                with: .color(Color(
                    hue: hue >= 0 ? hue : hue + 1,
                    saturation: saturation,
                    brightness: brightness,
                    opacity: alpha
                ))
            )
        }

        let labelText = Text("Past · Present")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        context.draw(
            labelText,
            at: CGPoint(x: startX + barW / 2, y: startY - 8),
            anchor: .bottom
        )
    }
}
