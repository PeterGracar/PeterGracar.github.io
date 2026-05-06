import SwiftUI

struct SimulationCanvas: View {
    @Environment(DPSimulation.self) private var sim

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let _ = timeline.date
                Canvas { context, size in
                    draw(in: context, size: size)
                }
                .accessibilityLabel("Detection percolation viewport.")
            }
            .overlay(alignment: .bottomLeading) {
                Text("Periodic boundaries · Box side = L · Origin at centre")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: .rect(cornerRadius: 8))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(.tertiarySystemBackground))
        .task(id: sim.isPaused) {
            await runLoop()
        }
    }

    @MainActor
    private func runLoop() async {
        while !Task.isCancelled, !sim.isPaused, sim.hit == nil {
            sim.tickIfNotPausedOrHit()
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    // MARK: - Transform

    private struct Transform {
        var scale: Double
        var centerX: Double  // screen position of world origin
        var centerY: Double
    }

    private func transform(for size: CGSize) -> Transform {
        let padding: Double = 16
        let avW = max(Double(size.width) - 2 * padding, 1)
        let avH = max(Double(size.height) - 2 * padding, 1)
        let scale = min(avW, avH) / max(sim.L, 1)
        return Transform(
            scale: scale,
            centerX: Double(size.width) / 2,
            centerY: Double(size.height) / 2
        )
    }

    // MARK: - Draw

    private func draw(in context: GraphicsContext, size: CGSize) {
        let xform = transform(for: size)
        let scale = xform.scale
        let L = sim.L
        let drawn = L * scale
        let bx0 = xform.centerX - drawn / 2
        let by0 = xform.centerY - drawn / 2
        let tile = CGRect(x: bx0, y: by0, width: drawn, height: drawn)

        // Outside band
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(.tertiarySystemBackground))
        )

        var clipped = context
        clipped.clip(to: Path(tile))
        clipped.fill(Path(tile), with: .color(Color(.systemBackground)))

        let particleHue = Color(.systemTeal)
        let bigCompHue = Color(.systemOrange)
        let edgeColor = Color.secondary.opacity(0.45)
        let particleFill = particleHue.opacity(0.20)
        let particleStroke = particleHue.opacity(0.55)
        let bigCompFill = bigCompHue.opacity(0.30)
        let bigCompStroke = bigCompHue.opacity(0.7)

        let shifts: [(dx: Double, dy: Double)] = [
            (0, 0), (L, 0), (-L, 0),
            (0, L), (0, -L),
            (L, L), (-L, -L),
            (L, -L), (-L, L)
        ]

        let particles = sim.particles
        let edges = sim.edges
        let kmax = sim.kmax
        let scenarioIsTwo = sim.scenario == .largestComponent
        let coreRadius = max(1.5, min(3.0, scale * 0.6))

        for shift in shifts {
            let tx = xform.centerX + shift.dx * scale
            let ty = xform.centerY + shift.dy * scale

            // Edges (scenario 2 only)
            if scenarioIsTwo, !edges.isEmpty {
                var edgePath = Path()
                for e in edges {
                    let u = particles[e.i]
                    let mx = (u.x + e.vRelX) / 2 + shift.dx
                    let my = (u.y + e.vRelY) / 2 + shift.dy
                    if mx <= -L || mx >= L * 2 { continue }
                    if my <= -L || my >= L * 2 { continue }
                    edgePath.move(to: CGPoint(x: tx + u.x * scale, y: ty + u.y * scale))
                    edgePath.addLine(to: CGPoint(x: tx + e.vRelX * scale, y: ty + e.vRelY * scale))
                }
                clipped.stroke(edgePath, with: .color(edgeColor), lineWidth: 1)
            }

            // Particles: halo fills (alpha-accumulating, with stroked outline),
            // then opaque cores so every centre stays visible.
            var visibleEntries: [(rect: CGRect, core: CGRect, big: Bool)] = []
            visibleEntries.reserveCapacity(particles.count)

            for p in particles {
                let nx = p.x + shift.dx
                let ny = p.y + shift.dy
                let halfL = L / 2
                if nx + p.radius < -halfL || nx - p.radius > halfL { continue }
                if ny + p.radius < -halfL || ny - p.radius > halfL { continue }
                let cx = tx + p.x * scale
                let cy = ty + p.y * scale
                let r = max(p.radius * scale, 1)
                let halo = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
                let core = CGRect(
                    x: cx - coreRadius,
                    y: cy - coreRadius,
                    width: 2 * coreRadius,
                    height: 2 * coreRadius
                )
                let big = scenarioIsTwo && kmax > 0 && p.compSize == kmax
                visibleEntries.append((halo, core, big))
            }

            for entry in visibleEntries {
                let path = Path(ellipseIn: entry.rect)
                clipped.fill(
                    path,
                    with: .color(entry.big ? bigCompFill : particleFill)
                )
                clipped.stroke(
                    path,
                    with: .color(entry.big ? bigCompStroke : particleStroke),
                    lineWidth: 0.75
                )
            }
            for entry in visibleEntries {
                clipped.fill(
                    Path(ellipseIn: entry.core),
                    with: .color(entry.big ? bigCompHue : particleHue)
                )
            }
        }

        // Trail of moving target
        if let d = sim.distinguished, !d.fixed, sim.trail.count > 1 {
            var trailPath = Path()
            var lastWorld: SIMD2<Double>? = nil
            for pt in sim.trail {
                let sx = xform.centerX + pt.x * scale
                let sy = xform.centerY + pt.y * scale
                if let last = lastWorld,
                   abs(pt.x - last.x) > L / 2 || abs(pt.y - last.y) > L / 2 {
                    trailPath.move(to: CGPoint(x: sx, y: sy))
                } else if lastWorld == nil {
                    trailPath.move(to: CGPoint(x: sx, y: sy))
                } else {
                    trailPath.addLine(to: CGPoint(x: sx, y: sy))
                }
                lastWorld = pt
            }
            clipped.stroke(
                trailPath,
                with: .color(Color.red.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }

        // Distinguished target
        if let d = sim.distinguished {
            let dx = xform.centerX + d.x * scale
            let dy = xform.centerY + d.y * scale
            clipped.fill(
                Path(ellipseIn: CGRect(x: dx - 10, y: dy - 10, width: 20, height: 20)),
                with: .color(Color.red.opacity(0.25))
            )
            clipped.fill(
                Path(ellipseIn: CGRect(x: dx - 4, y: dy - 4, width: 8, height: 8)),
                with: .color(Color.red)
            )
            clipped.stroke(
                Path(ellipseIn: CGRect(x: dx - 4, y: dy - 4, width: 8, height: 8)),
                with: .color(Color.white),
                lineWidth: 1.5
            )
        }

        // Tile border, drawn unclipped
        context.stroke(
            Path(tile),
            with: .color(Color.secondary.opacity(0.6)),
            lineWidth: 1.5
        )

        // Hit highlight
        if let h = sim.hit {
            let cx = xform.centerX + h.causeX * scale
            let cy = xform.centerY + h.causeY * scale
            let r = max(8.0, h.causeR * scale + 4)
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)),
                with: .color(Color.red),
                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
            )
        }
    }
}
