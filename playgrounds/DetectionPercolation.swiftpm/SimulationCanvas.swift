import SwiftUI
import UIKit

struct SimulationCanvas: View {
    @Environment(DPSimulation.self) private var sim

    var body: some View {
        let liveSim = sim

        return GeometryReader { geo in
            let xform = transform(for: geo.size, L: sim.L)

            ZStack {
                // Outside band
                Color(.tertiarySystemBackground)
                    .ignoresSafeArea()

                // Tile interior (white in light, dark grey in dark)
                Rectangle()
                    .fill(Color(.systemBackground))
                    .frame(width: xform.drawn, height: xform.drawn)
                    .position(x: xform.centerX, y: xform.centerY)

                // Particles + edges via Metal
                MetalParticleView(sim: sim)
                    .allowsHitTesting(false)

                // Tile border, trail, target marker, hit highlight via CG
                CGCanvas { ctx, size in
                    drawOverlay(ctx: ctx, size: size, sim: liveSim)
                }
                .allowsHitTesting(false)
            }
            .accessibilityLabel("Detection percolation viewport.")
        }
    }
}

// MARK: - Transform

private struct Transform {
    var scale: Double
    var centerX: Double
    var centerY: Double
    var drawn: Double
}

private func transform(for size: CGSize, L: Double) -> Transform {
    let padding: Double = 16
    let avW = max(Double(size.width) - 2 * padding, 1)
    let avH = max(Double(size.height) - 2 * padding, 1)
    let scale = min(avW, avH) / max(L, 1)
    return Transform(
        scale: scale,
        centerX: Double(size.width) / 2,
        centerY: Double(size.height) / 2,
        drawn: L * scale
    )
}

// MARK: - Overlay drawing
//
// Tile border, trail, distinguished target, hit highlight. Few enough
// elements that CG is plenty fast — the heavy work (tens of thousands of
// particles) is in Metal.

private func drawOverlay(ctx: CGContext, size: CGSize, sim: DPSimulation) {
    let L = sim.L
    guard L > 0 else { return }
    let xf = transform(for: size, L: L)
    let scale = xf.scale
    let bx0 = xf.centerX - xf.drawn / 2
    let by0 = xf.centerY - xf.drawn / 2
    let tile = CGRect(x: bx0, y: by0, width: xf.drawn, height: xf.drawn)

    // Tile border
    ctx.setStrokeColor(UIColor.secondaryLabel.withAlphaComponent(0.6).cgColor)
    ctx.setLineWidth(1.5)
    ctx.stroke(tile)

    // Clip to the tile for the trail / target visuals
    ctx.saveGState()
    ctx.addRect(tile)
    ctx.clip()

    // Trail of moving target
    if let d = sim.distinguished, !d.fixed, sim.trail.count > 1 {
        let trailPath = CGMutablePath()
        var lastPoint: SIMD2<Double>? = nil
        var first = true
        for pt in sim.trail {
            let sx = xf.centerX + pt.x * scale
            let sy = xf.centerY + pt.y * scale
            let p = CGPoint(x: sx, y: sy)
            if first {
                trailPath.move(to: p)
                first = false
            } else if let last = lastPoint,
                      abs(pt.x - last.x) > L / 2 || abs(pt.y - last.y) > L / 2 {
                trailPath.move(to: p)
            } else {
                trailPath.addLine(to: p)
            }
            lastPoint = pt
        }
        ctx.addPath(trailPath)
        ctx.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.55).cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
    }

    // Distinguished target
    if let d = sim.distinguished {
        let dx = xf.centerX + d.x * scale
        let dy = xf.centerY + d.y * scale
        ctx.setFillColor(UIColor.systemRed.withAlphaComponent(0.25).cgColor)
        ctx.fillEllipse(in: CGRect(x: dx - 10, y: dy - 10, width: 20, height: 20))
        ctx.setFillColor(UIColor.systemRed.cgColor)
        ctx.fillEllipse(in: CGRect(x: dx - 4, y: dy - 4, width: 8, height: 8))
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: dx - 4, y: dy - 4, width: 8, height: 8))
    }

    ctx.restoreGState()  // exit tile clip

    // Hit highlight (drawn unclipped so an off-tile triggering particle
    // marker would still be visible).
    if let h = sim.hit {
        let cx = xf.centerX + h.causeX * scale
        let cy = xf.centerY + h.causeY * scale
        let r = max(8.0, h.causeR * scale + 4)
        ctx.setStrokeColor(UIColor.systemRed.cgColor)
        ctx.setLineWidth(2)
        ctx.setLineDash(phase: 0, lengths: [6, 4])
        ctx.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        ctx.setLineDash(phase: 0, lengths: [])
    }
}
