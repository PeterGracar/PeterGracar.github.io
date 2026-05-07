import Foundation
import Observation

enum MotionKind: String, CaseIterable, Identifiable, Sendable {
    case brownian, levy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .brownian: return "Brownian"
        case .levy: return "Lévy"
        }
    }
}

enum RadiusMode: String, CaseIterable, Identifiable, Sendable {
    case deterministic, pareto
    var id: String { rawValue }
    var label: String {
        switch self {
        case .deterministic: return "Fixed r"
        case .pareto: return "Pareto"
        }
    }
}

enum TargetMode: String, CaseIterable, Identifiable, Sendable {
    case fixed, moving
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fixed: return "Fixed"
        case .moving: return "Moving"
        }
    }
}

enum Scenario: Int, CaseIterable, Identifiable, Sendable {
    case anyParticle = 1
    case largestComponent = 2
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .anyParticle: return "Any particle"
        case .largestComponent: return "Largest component"
        }
    }
    var explanation: String {
        switch self {
        case .anyParticle:
            return "Stop as soon as the target lies in some disc B(x_i, r_i)."
        case .largestComponent:
            return "Stop when the target is covered by a component of the current maximum vertex count k_max(t)."
        }
    }
}

struct Particle {
    var x: Double
    var y: Double
    var radius: Double
    var vx: Double = 0
    var vy: Double = 0
    var ticksToChange: Int = 0
    var root: Int = 0
    var compSize: Int = 1
}

struct DPEdge {
    var i: Int
    var j: Int
    var vRelX: Double
    var vRelY: Double
}

struct DPTarget {
    var x: Double = 0
    var y: Double = 0
    var fixed: Bool
    var vx: Double = 0
    var vy: Double = 0
    var ticksToChange: Int = 0
}

struct HitInfo: Sendable {
    var t: Double
    var causeIndex: Int
    var causeX: Double
    var causeY: Double
    var causeR: Double
}

@Observable
final class DPSimulation {

    // MARK: - Parameters that need a full reset on change

    var L: Double = 300 {
        didSet { if L != oldValue { reset() } }
    }
    var logLambda: Double = -2.70 {
        didSet { if logLambda != oldValue { reset() } }
    }
    var radiusMode: RadiusMode = .deterministic {
        didSet { if radiusMode != oldValue { reset() } }
    }
    var xm: Double = 1.0 {
        didSet { if xm != oldValue, radiusMode == .pareto { reset() } }
    }
    var paretoDelta: Double = 2.50 {
        didSet { if paretoDelta != oldValue, radiusMode == .pareto { reset() } }
    }
    var target: TargetMode = .fixed {
        didSet { if target != oldValue { reset() } }
    }
    var seed: String = "detection" {
        didSet { if seed != oldValue { reset() } }
    }

    // MARK: - Parameters that take effect on the next tick

    var motion: MotionKind = .brownian
    var sigma: Double = 1.0
    var alpha: Double = 1.50
    var scenario: Scenario = .anyParticle {
        didSet { if scenario != oldValue { rebuildScenarioState() } }
    }
    var speed: Int = 3

    /// Slider for fixed radius. Updates existing particle radii in place
    /// without triggering a reset, so dragging the slider doesn't disturb
    /// positions or the seeded sequence.
    var fixedRadius: Double = 3.0 {
        didSet {
            if fixedRadius != oldValue, radiusMode == .deterministic {
                for i in particles.indices { particles[i].radius = fixedRadius }
            }
        }
    }

    let dtPerTick: Double = 0.1

    // MARK: - Derived

    var lambda: Double { pow(10, logLambda) }
    var meanN: Double { lambda * L * L }
    var t: Double { Double(tick) * dtPerTick }

    // MARK: - State

    private(set) var particles: [Particle] = []
    private(set) var edges: [DPEdge] = []
    private(set) var distinguished: DPTarget? = nil
    private(set) var trail: [SIMD2<Double>] = []
    private(set) var tick: Int = 0
    private(set) var kmax: Int = 0
    private(set) var hit: HitInfo? = nil

    var isPaused: Bool = true

    let trailLength = 240
    let levyBaseScale = 20.0
    let maxParticles = 100_000

    private var rng = SeededRandom(seed: "detection")

    /// Particle indices sorted by radius descending. Cached because radii
    /// only change at reset (Pareto resamples on init; deterministic-r slider
    /// changes leave the order untouched since every radius shifts equally).
    /// The two-tier component pass uses this to pick the K largest discs to
    /// brute-force against everyone, while the rest go through the fast grid.
    private var radiusOrder: [Int] = []

    init() { reset() }

    // MARK: - Reset

    func reset() {
        rng = SeededRandom(seed: seed)
        let mean = meanN
        let n = min(maxParticles, samplePoisson(mean: mean))
        var newParticles: [Particle] = []
        newParticles.reserveCapacity(n)
        for i in 0..<n {
            var p = Particle(
                x: (rng.uniform() - 0.5) * L,
                y: (rng.uniform() - 0.5) * L,
                radius: sampleRadius()
            )
            p.root = i
            newParticles.append(p)
        }
        particles = newParticles
        distinguished = DPTarget(fixed: target == .fixed)
        trail.removeAll(keepingCapacity: true)
        edges.removeAll(keepingCapacity: true)
        tick = 0
        kmax = 0
        hit = nil
        rebuildRadiusOrder()
        rebuildScenarioState()
    }

    private func rebuildRadiusOrder() {
        let n = particles.count
        radiusOrder = Array(0..<n)
        if radiusMode != .deterministic {
            radiusOrder.sort { particles[$0].radius > particles[$1].radius }
        }
    }

    private func rebuildScenarioState() {
        if scenario == .largestComponent {
            computeComponents()
        } else {
            kmax = 0
            edges.removeAll(keepingCapacity: true)
            for i in particles.indices {
                particles[i].root = i
                particles[i].compSize = 1
            }
        }
    }

    // MARK: - Sampling

    private func sampleRadius() -> Double {
        if radiusMode == .deterministic { return fixedRadius }
        return xm / pow(rng.uniformOpen(), 1.0 / paretoDelta)
    }

    private func samplePoisson(mean: Double) -> Int {
        guard mean > 0 else { return 0 }
        if mean < 30 {
            let threshold = exp(-mean)
            var k = 0
            var p = 1.0
            repeat {
                k += 1
                p *= rng.uniform()
            } while p > threshold
            return k - 1
        }
        return max(0, Int((mean + sqrt(mean) * rng.gaussian()).rounded()))
    }

    // MARK: - Tick

    func tickIfNotPausedOrHit() {
        guard !isPaused, hit == nil else { return }
        for _ in 0..<speed {
            stepOnce()
            if hit != nil { break }
        }
    }

    private func stepOnce() {
        tick += 1

        for i in particles.indices {
            move(&particles[i])
        }

        if var d = distinguished, !d.fixed {
            move(&d)
            distinguished = d
            trail.append(SIMD2<Double>(d.x, d.y))
            if trail.count > trailLength {
                trail.removeFirst(trail.count - trailLength)
            }
        }

        if scenario == .largestComponent {
            computeComponents()
        }

        if let result = checkHit() {
            hit = result
            isPaused = true
        }
    }

    private func checkHit() -> HitInfo? {
        guard let d = distinguished else { return nil }
        switch scenario {
        case .anyParticle:
            for i in particles.indices {
                let p = particles[i]
                if torusDistanceSquared(d.x, d.y, p.x, p.y) <= p.radius * p.radius {
                    return HitInfo(t: t, causeIndex: i, causeX: p.x, causeY: p.y, causeR: p.radius)
                }
            }
        case .largestComponent:
            guard kmax > 0 else { return nil }
            for i in particles.indices {
                let p = particles[i]
                guard p.compSize == kmax else { continue }
                if torusDistanceSquared(d.x, d.y, p.x, p.y) <= p.radius * p.radius {
                    return HitInfo(t: t, causeIndex: i, causeX: p.x, causeY: p.y, causeR: p.radius)
                }
            }
        }
        return nil
    }

    // MARK: - Movement

    private func move<M: Mover>(_ p: inout M) {
        switch motion {
        case .brownian:
            let s = sigma * sqrt(dtPerTick)
            p.x += s * rng.gaussian()
            p.y += s * rng.gaussian()
        case .levy:
            if p.ticksToChange <= 0 {
                let theta = rng.uniform() * 2 * .pi
                let mag: Double
                if alpha >= 1.99 {
                    mag = abs(rng.gaussian()) * levyBaseScale
                } else {
                    mag = min(pow(rng.uniformOpen(), -1.0 / alpha) * levyBaseScale, L * 3)
                }
                let duration = max(1, Int((mag / Double(max(1, speed))).rounded(.up)))
                p.vx = mag * cos(theta) / Double(duration)
                p.vy = mag * sin(theta) / Double(duration)
                p.ticksToChange = duration
            }
            p.x += p.vx
            p.y += p.vy
            p.ticksToChange -= 1
        }
        wrap(&p)
    }

    private func wrap<M: Mover>(_ p: inout M) {
        let H = L / 2
        var nx = (p.x + H).truncatingRemainder(dividingBy: L)
        if nx < 0 { nx += L }
        p.x = nx - H
        var ny = (p.y + H).truncatingRemainder(dividingBy: L)
        if ny < 0 { ny += L }
        p.y = ny - H
    }

    // MARK: - Geometry

    private func torusDistanceSquared(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) -> Double {
        var dx = abs(ax - bx)
        var dy = abs(ay - by)
        if dx > L / 2 { dx = L - dx }
        if dy > L / 2 { dy = L - dy }
        return dx * dx + dy * dy
    }

    private func relativePosition(of b: Particle, relativeTo a: Particle) -> (x: Double, y: Double) {
        var x = b.x, y = b.y
        if x - a.x > L / 2 { x -= L } else if a.x - x > L / 2 { x += L }
        if y - a.y > L / 2 { y -= L } else if a.y - y > L / 2 { y += L }
        return (x, y)
    }

    // MARK: - Components

    /// Two-tier connected-components pass.
    ///
    /// A single Pareto outlier with a giant radius would otherwise force the
    /// uniform-grid cell side up to `2·r_max`, which collapses the grid into
    /// a handful of cells and makes the check no faster than O(N²). Instead
    /// we split the particles into:
    ///
    ///   * **small** (the bottom N − K by radius) — placed in a tight grid
    ///     with cell side `s = max(L/50, 2·r_(K+1))`. Every small-small pair
    ///     that *could* overlap lies in the 3×3 Chebyshev neighbourhood of
    ///     one another, so we only check those.
    ///   * **large** (the top K by radius) — brute-forced against everyone
    ///     in an O(K·N) pass. K is chosen so that this single pass costs
    ///     less than what the grid would cost if the large discs forced its
    ///     cell side up.
    ///
    /// K is picked by sweeping candidates {0, 1, 2, 4, 8, …, n} and choosing
    /// the one that minimises a simple cost model:
    ///
    ///   cost(K) ≈ (cols² · 9 · ρ²)  +  K · N
    ///
    /// where ρ = (n − K) / cols² is the expected occupancy of a small-cell.
    /// For deterministic radii every K has the same `r_(K+1)`, so K = 0
    /// always wins and we fall through to the pure grid case.
    private func computeComponents() {
        let n = particles.count
        edges.removeAll(keepingCapacity: true)
        guard n > 0 else { kmax = 0; return }

        let storeEdges = scenario == .largestComponent

        var parent = Array(0..<n)
        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }

        // ── Pick the optimal "large" cut-off K ────────────────────────────
        var ks: [Int] = [0]
        var k = 1
        while k < n {
            ks.append(k)
            if k >= n { break }
            k *= 2
        }
        if ks.last != n { ks.append(n) }

        var bestK = 0
        var bestCost = Double.infinity
        var bestCols = max(1, Int(L / max(L / 50, 1e-6)))

        for K in ks {
            let maxSmallR = (K >= n) ? 0 : particles[radiusOrder[K]].radius
            let cellSize = max(L / 50, 2 * maxSmallR, 1e-6)
            let cols = max(1, Int(L / cellSize))
            let nSmall = n - K
            let gridCost: Double
            if cols < 3 {
                gridCost = Double(nSmall) * Double(max(0, nSmall - 1)) * 0.5
            } else {
                let occ = Double(nSmall) / Double(cols * cols)
                gridCost = Double(cols * cols) * 9 * occ * occ
            }
            let linearCost = Double(K) * Double(n)
            let cost = gridCost + linearCost
            if cost < bestCost {
                bestCost = cost
                bestK = K
                bestCols = cols
            }
        }

        let nLarge = bestK
        let cols = bestCols
        let useGrid = cols >= 3 && nLarge * 3 <= n

        if !useGrid {
            // ── Pure O(N²) fallback ────────────────────────────────────────
            // Triggers only when every reasonable grid configuration costs
            // about as much as the all-pairs scan.
            for i in 0..<(n - 1) {
                let u = particles[i]
                for j in (i + 1)..<n {
                    let v = particles[j]
                    let thr = u.radius + v.radius
                    if torusDistanceSquared(u.x, u.y, v.x, v.y) < thr * thr {
                        let ru = find(i), rv = find(j)
                        if ru != rv { parent[ru] = rv }
                        if storeEdges {
                            let rel = relativePosition(of: v, relativeTo: u)
                            edges.append(DPEdge(i: i, j: j, vRelX: rel.x, vRelY: rel.y))
                        }
                    }
                }
            }
        } else {
            let H = L / 2
            // Pick the actual cell side so the grid divides L exactly —
            // makes modular neighbour indexing line up with the torus wrap.
            let s = L / Double(cols)

            var isLarge = [Bool](repeating: false, count: n)
            var largePos = [Int](repeating: 0, count: n)
            for k in 0..<nLarge {
                let li = radiusOrder[k]
                isLarge[li] = true
                largePos[li] = k
            }

            // ── Small-small via uniform grid ──────────────────────────────
            var buckets: [[Int]] = Array(repeating: [], count: cols * cols)
            for i in 0..<n {
                if isLarge[i] { continue }
                let p = particles[i]
                var cx = Int((p.x + H) / s) % cols
                if cx < 0 { cx += cols }
                var cy = Int((p.y + H) / s) % cols
                if cy < 0 { cy += cols }
                buckets[cx + cy * cols].append(i)
            }

            for cy in 0..<cols {
                for cx in 0..<cols {
                    let bucket = buckets[cx + cy * cols]
                    if bucket.isEmpty { continue }
                    for dy in -1...1 {
                        let ny = (cy + dy + cols) % cols
                        for dx in -1...1 {
                            let nx = (cx + dx + cols) % cols
                            let nbr = buckets[nx + ny * cols]
                            if nbr.isEmpty { continue }
                            let sameCell = (dx == 0 && dy == 0)
                            for a in 0..<bucket.count {
                                let i = bucket[a]
                                let u = particles[i]
                                let b0 = sameCell ? a + 1 : 0
                                for b in b0..<nbr.count {
                                    let j = nbr[b]
                                    // For cross-cell pairs, emit each pair
                                    // once — keep it on the side where i < j.
                                    if !sameCell && j <= i { continue }
                                    let v = particles[j]
                                    let thr = u.radius + v.radius
                                    if torusDistanceSquared(u.x, u.y, v.x, v.y) < thr * thr {
                                        let ru = find(i), rv = find(j)
                                        if ru != rv { parent[ru] = rv }
                                        if storeEdges {
                                            let rel = relativePosition(of: v, relativeTo: u)
                                            edges.append(DPEdge(i: i, j: j, vRelX: rel.x, vRelY: rel.y))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Large-vs-everyone ─────────────────────────────────────────
            // Each large disc is checked against every other particle. To
            // avoid double-counting large-large pairs, skip the "other" if
            // it's also large and appears earlier in radiusOrder (already
            // handled when we processed it).
            for kIdx in 0..<nLarge {
                let li = radiusOrder[kIdx]
                let u = particles[li]
                for j in 0..<n {
                    if j == li { continue }
                    if isLarge[j] && largePos[j] < kIdx { continue }
                    let v = particles[j]
                    let thr = u.radius + v.radius
                    if torusDistanceSquared(u.x, u.y, v.x, v.y) < thr * thr {
                        let aIdx = li < j ? li : j
                        let bIdx = li < j ? j : li
                        let ra = find(aIdx), rb = find(bIdx)
                        if ra != rb { parent[ra] = rb }
                        if storeEdges {
                            let pa = particles[aIdx]
                            let pb = particles[bIdx]
                            let rel = relativePosition(of: pb, relativeTo: pa)
                            edges.append(DPEdge(i: aIdx, j: bIdx, vRelX: rel.x, vRelY: rel.y))
                        }
                    }
                }
            }
        }

        // ── Component sizes ───────────────────────────────────────────────
        var size = [Int](repeating: 0, count: n)
        for i in 0..<n { size[find(i)] += 1 }

        var maxSize = 0
        for i in 0..<n {
            let root = find(i)
            particles[i].root = root
            particles[i].compSize = size[root]
            if size[root] > maxSize { maxSize = size[root] }
        }
        kmax = maxSize
    }
}

// MARK: - Mover

protocol Mover {
    var x: Double { get set }
    var y: Double { get set }
    var vx: Double { get set }
    var vy: Double { get set }
    var ticksToChange: Int { get set }
}
extension Particle: Mover {}
extension DPTarget: Mover {}
