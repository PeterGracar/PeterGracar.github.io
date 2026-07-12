import SwiftUI

struct SimulationCanvas: View {
    @Environment(Simulation.self) private var sim

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let _ = timeline.date  // re-evaluate the renderer each frame
                Canvas { context, size in
                    draw(in: context, size: size)
                }
                .accessibilityLabel("Simulation viewport. Tap a node to mark it infected.")
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                let xform = transform(for: geo.size)
                let wx = (Double(location.x) - xform.offsetX) / xform.scale
                let wy = (Double(location.y) - xform.offsetY) / xform.scale
                sim.infect(at: SIMD2<Double>(wx, wy), withinRadius: 50.0 / xform.scale)
            }
            .overlay(alignment: .bottomLeading) {
                Text("Tap to infect · Periodic boundaries · Amber tick = critical value (R₀ ≈ 1)")
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
            await runSimulationLoop()
        }
    }

    @MainActor
    private func runSimulationLoop() async {
        while !Task.isCancelled, !sim.isPaused {
            sim.tick()
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    // MARK: - View transform

    private struct Transform {
        var scale: Double
        var offsetX: Double
        var offsetY: Double
    }

    private func transform(for size: CGSize) -> Transform {
        let padding: Double = 16
        let avW = max(Double(size.width) - 2 * padding, 1)
        let avH = max(Double(size.height) - 2 * padding, 1)
        let scale = min(avW, avH) / max(sim.L, 1)
        let drawn = sim.L * scale
        return Transform(
            scale: scale,
            offsetX: (Double(size.width) - drawn) / 2,
            offsetY: (Double(size.height) - drawn) / 2
        )
    }

    // MARK: - Drawing

    private func draw(in context: GraphicsContext, size: CGSize) {
        let xform = transform(for: size)
        let scale = xform.scale
        let originX = xform.offsetX
        let originY = xform.offsetY
        let L = sim.L
        let drawn = L * scale

        let tile = CGRect(x: originX, y: originY, width: drawn, height: drawn)

        // Background fill of the entire canvas (the surrounding band).
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(.tertiarySystemBackground))
        )

        // Tile background and clip to the visible torus tile.
        var tileContext = context
        tileContext.clip(to: Path(tile))
        tileContext.fill(Path(tile), with: .color(Color(.systemBackground)))

        // System red/blue adapt to dark mode so the halos stay visibly
        // tinted on a dark background. The stroke outline ensures every
        // disc has a clear boundary even when several halos overlap.
        let infectedHue = Color(.systemRed)
        let susceptibleHue = Color(.systemBlue)
        let edgeColor = Color.secondary.opacity(0.55)
        let infectedFill = infectedHue.opacity(0.22)
        let infectedStroke = infectedHue.opacity(0.55)
        let infectedCore = infectedHue
        let susceptibleFill = susceptibleHue.opacity(0.16)
        let susceptibleStroke = susceptibleHue.opacity(0.45)
        let susceptibleCore = susceptibleHue

        let shifts: [(dx: Double, dy: Double)] = [
            (0, 0), (L, 0), (-L, 0),
            (0, L), (0, -L),
            (L, L), (-L, -L),
            (L, -L), (-L, L)
        ]

        let nodes = sim.nodes
        let edges = sim.edges

        for shift in shifts {
            let tx = originX + shift.dx * scale
            let ty = originY + shift.dy * scale

            // Edges
            var edgePath = Path()
            for edge in edges {
                let u = nodes[edge.u]
                let midX = (u.x + edge.vRelX) / 2 + shift.dx
                let midY = (u.y + edge.vRelY) / 2 + shift.dy
                if midX <= -L || midX >= L * 2 { continue }
                if midY <= -L || midY >= L * 2 { continue }
                edgePath.move(to: CGPoint(x: tx + u.x * scale, y: ty + u.y * scale))
                edgePath.addLine(to: CGPoint(x: tx + edge.vRelX * scale, y: ty + edge.vRelY * scale))
            }
            tileContext.stroke(edgePath, with: .color(edgeColor), lineWidth: 1)

            // Halos are filled one disc at a time so that overlapping
            // translucent fills accumulate alpha — otherwise a small disc
            // inside a larger one would be invisible. Cores are drawn in a
            // second pass so they all sit above every halo.
            let coreRadius = max(2.0, scale * 2.0)
            var visibleNodes: [(rect: CGRect, coreRect: CGRect, infected: Bool)] = []
            visibleNodes.reserveCapacity(nodes.count)

            for node in nodes {
                let nx = node.x + shift.dx
                let ny = node.y + shift.dy
                if nx + node.radius < 0 || nx - node.radius > L { continue }
                if ny + node.radius < 0 || ny - node.radius > L { continue }
                let cx = tx + node.x * scale
                let cy = ty + node.y * scale
                let r = max(node.radius * scale, 1)
                let halo = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
                let core = CGRect(
                    x: cx - coreRadius,
                    y: cy - coreRadius,
                    width: 2 * coreRadius,
                    height: 2 * coreRadius
                )
                visibleNodes.append((halo, core, node.state == .infected))
            }

            for entry in visibleNodes {
                let path = Path(ellipseIn: entry.rect)
                tileContext.fill(
                    path,
                    with: .color(entry.infected ? infectedFill : susceptibleFill)
                )
                tileContext.stroke(
                    path,
                    with: .color(entry.infected ? infectedStroke : susceptibleStroke),
                    lineWidth: 0.75
                )
            }
            for entry in visibleNodes {
                tileContext.fill(
                    Path(ellipseIn: entry.coreRect),
                    with: .color(entry.infected ? infectedCore : susceptibleCore)
                )
            }
        }

        // Tile border, drawn unclipped so it sits cleanly above content.
        context.stroke(
            Path(tile),
            with: .color(Color.secondary.opacity(0.6)),
            lineWidth: 1.5
        )
    }
}
