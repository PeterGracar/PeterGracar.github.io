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

// MARK: - Free geometry helpers (no self access → no @Observable overhead)

@inline(__always)
private func torusDist2(
    _ ax: Double, _ ay: Double,
    _ bx: Double, _ by: Double,
    _ L: Double, _ halfL: Double
) -> Double {
    var dx = abs(ax - bx)
    var dy = abs(ay - by)
    if dx > halfL { dx = L - dx }
    if dy > halfL { dy = L - dy }
    return dx * dx + dy * dy
}

@inline(__always)
private func relPos(
    _ bx: Double, _ by: Double,
    _ ax: Double, _ ay: Double,
    _ L: Double, _ halfL: Double
) -> (Double, Double) {
    var x = bx, y = by
    if x - ax > halfL { x -= L } else if ax - x > halfL { x += L }
    if y - ay > halfL { y -= L } else if ay - y > halfL { y += L }
    return (x, y)
}

@inline(__always)
private func wrapCoord(_ v: Double, _ L: Double, _ halfL: Double) -> Double {
    var n = (v + halfL).truncatingRemainder(dividingBy: L)
    if n < 0 { n += L }
    return n - halfL
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

    var fixedRadius: Double = 3.0 {
        didSet {
            if fixedRadius != oldValue, radiusMode == .deterministic {
                for i in hotParticles.indices {
                    hotParticles[i].radius = fixedRadius
                }
                publishSnapshot()
            }
        }
    }

    let dtPerTick: Double = 0.1

    // MARK: - Derived

    var lambda: Double { pow(10, logLambda) }
    var meanN: Double { lambda * L * L }
    var t: Double { Double(tick) * dtPerTick }

    // MARK: - Public state (observable snapshot, updated once per frame)

    private(set) var particleCount: Int = 0
    private(set) var distinguished: DPTarget? = nil
    private(set) var trail: [SIMD2<Double>] = []
    private(set) var tick: Int = 0
    private(set) var kmax: Int = 0
    private(set) var hit: HitInfo? = nil

    var isPaused: Bool = true

    // MARK: - Hot-path storage (excluded from Observation tracking)

    @ObservationIgnored
    private var hotParticles: [Particle] = []

    @ObservationIgnored
    private var hotEdges: [DPEdge] = []

    @ObservationIgnored
    private var hotTrail: [SIMD2<Double>] = []

    @ObservationIgnored
    private var hotTick: Int = 0

    @ObservationIgnored
    private var hotKmax: Int = 0

    @ObservationIgnored
    private var hotDistinguished: DPTarget? = nil

    @ObservationIgnored
    private var hotHit: HitInfo? = nil

    @ObservationIgnored
    private var radiusOrder: [Int] = []

    @ObservationIgnored
    private var rng = SeededRandom(seed: "detection")

    @ObservationIgnored
    private var gridCellCounts: [Int] = []

    @ObservationIgnored
    private var gridOffsets: [Int] = []

    @ObservationIgnored
    private var gridParticleIndices: [Int] = []

    @ObservationIgnored
    private var ufParent: [Int] = []

    @ObservationIgnored
    private var ufSize: [Int] = []

    let trailLength = 240
    let levyBaseScale = 20.0
    let maxParticles = 100_000

    init() { reset() }

    // MARK: - Direct access for the Metal renderer (bypasses observation)

    func withHotParticles<T>(_ body: (UnsafeBufferPointer<Particle>) -> T) -> T {
        hotParticles.withUnsafeBufferPointer(body)
    }

    func withHotEdges<T>(_ body: (UnsafeBufferPointer<DPEdge>) -> T) -> T {
        hotEdges.withUnsafeBufferPointer(body)
    }

    var hotEdgeCount: Int { hotEdges.count }
    var hotParticleCountDirect: Int { hotParticles.count }
    var hotKmaxDirect: Int { hotKmax }

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
        hotParticles = newParticles
        hotEdges.removeAll(keepingCapacity: true)
        hotTrail.removeAll(keepingCapacity: true)
        hotDistinguished = DPTarget(fixed: target == .fixed)
        hotTick = 0
        hotKmax = 0
        hotHit = nil
        rebuildRadiusOrder()
        rebuildScenarioState()
    }

    private func rebuildRadiusOrder() {
        let n = hotParticles.count
        radiusOrder = Array(0..<n)
        if radiusMode != .deterministic {
            radiusOrder.sort { hotParticles[$0].radius > hotParticles[$1].radius }
        }
    }

    private func rebuildScenarioState() {
        if scenario == .largestComponent {
            computeComponents()
        } else {
            hotKmax = 0
            hotEdges.removeAll(keepingCapacity: true)
            for i in hotParticles.indices {
                hotParticles[i].root = i
                hotParticles[i].compSize = 1
            }
        }
        publishSnapshot()
    }

    private func publishSnapshot() {
        if tick != hotTick { tick = hotTick }
        if kmax != hotKmax { kmax = hotKmax }
        if hit?.t != hotHit?.t { hit = hotHit }
        distinguished = hotDistinguished
        trail = hotTrail
        let n = hotParticles.count
        if particleCount != n { particleCount = n }
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
        guard !isPaused, hotHit == nil else { return }

        // Cache all observed properties once per frame so the inner loops
        // never hit the @Observable getter/tracking machinery.
        let curMotion = motion
        let curL = L
        let curHalfL = curL / 2
        let curAlpha = alpha
        let curSpeed = speed
        let curScenario = scenario
        let baseScale = levyBaseScale
        let brownianStep = sigma * sqrt(dtPerTick)
        let maxLevyMag = curL * 3

        for _ in 0..<curSpeed {
            hotTick += 1

            // ── Move particles ────────────────────────────────────────────
            hotParticles.withUnsafeMutableBufferPointer { buf in
                let count = buf.count
                switch curMotion {
                case .brownian:
                    for i in 0..<count {
                        buf[i].x += brownianStep * rng.gaussian()
                        buf[i].y += brownianStep * rng.gaussian()
                        buf[i].x = wrapCoord(buf[i].x, curL, curHalfL)
                        buf[i].y = wrapCoord(buf[i].y, curL, curHalfL)
                    }
                case .levy:
                    for i in 0..<count {
                        if buf[i].ticksToChange <= 0 {
                            let theta = rng.uniform() * 2 * .pi
                            let mag: Double
                            if curAlpha >= 1.99 {
                                mag = abs(rng.gaussian()) * baseScale
                            } else {
                                mag = min(pow(rng.uniformOpen(), -1.0 / curAlpha) * baseScale, maxLevyMag)
                            }
                            let duration = max(1, Int((mag / Double(max(1, curSpeed))).rounded(.up)))
                            buf[i].vx = mag * cos(theta) / Double(duration)
                            buf[i].vy = mag * sin(theta) / Double(duration)
                            buf[i].ticksToChange = duration
                        }
                        buf[i].x += buf[i].vx
                        buf[i].y += buf[i].vy
                        buf[i].ticksToChange -= 1
                        buf[i].x = wrapCoord(buf[i].x, curL, curHalfL)
                        buf[i].y = wrapCoord(buf[i].y, curL, curHalfL)
                    }
                }
            }

            // ── Move distinguished target ─────────────────────────────────
            if var d = hotDistinguished, !d.fixed {
                switch curMotion {
                case .brownian:
                    d.x += brownianStep * rng.gaussian()
                    d.y += brownianStep * rng.gaussian()
                case .levy:
                    if d.ticksToChange <= 0 {
                        let theta = rng.uniform() * 2 * .pi
                        let mag: Double
                        if curAlpha >= 1.99 {
                            mag = abs(rng.gaussian()) * baseScale
                        } else {
                            mag = min(pow(rng.uniformOpen(), -1.0 / curAlpha) * baseScale, maxLevyMag)
                        }
                        let duration = max(1, Int((mag / Double(max(1, curSpeed))).rounded(.up)))
                        d.vx = mag * cos(theta) / Double(duration)
                        d.vy = mag * sin(theta) / Double(duration)
                        d.ticksToChange = duration
                    }
                    d.x += d.vx
                    d.y += d.vy
                    d.ticksToChange -= 1
                }
                d.x = wrapCoord(d.x, curL, curHalfL)
                d.y = wrapCoord(d.y, curL, curHalfL)
                hotDistinguished = d
                hotTrail.append(SIMD2<Double>(d.x, d.y))
                if hotTrail.count > trailLength {
                    hotTrail.removeFirst(hotTrail.count - trailLength)
                }
            }

            // ── Components & hit test ─────────────────────────────────────
            if curScenario == .largestComponent {
                computeComponents()
            }

            if let result = checkHit(curL, curHalfL, curScenario) {
                hotHit = result
                isPaused = true
                break
            }
        }

        publishSnapshot()
    }

    private func checkHit(_ curL: Double, _ curHalfL: Double, _ curScenario: Scenario) -> HitInfo? {
        guard let d = hotDistinguished else { return nil }
        let dx = d.x, dy = d.y
        let curT = Double(hotTick) * dtPerTick
        switch curScenario {
        case .anyParticle:
            return hotParticles.withUnsafeBufferPointer { buf in
                for i in 0..<buf.count {
                    let p = buf[i]
                    if torusDist2(dx, dy, p.x, p.y, curL, curHalfL) <= p.radius * p.radius {
                        return HitInfo(t: curT, causeIndex: i, causeX: p.x, causeY: p.y, causeR: p.radius)
                    }
                }
                return nil
            }
        case .largestComponent:
            let curKmax = hotKmax
            guard curKmax > 0 else { return nil }
            return hotParticles.withUnsafeBufferPointer { buf in
                for i in 0..<buf.count {
                    let p = buf[i]
                    if p.compSize != curKmax { continue }
                    if torusDist2(dx, dy, p.x, p.y, curL, curHalfL) <= p.radius * p.radius {
                        return HitInfo(t: curT, causeIndex: i, causeX: p.x, causeY: p.y, causeR: p.radius)
                    }
                }
                return nil
            }
        }
    }

    // MARK: - Components

    private func computeComponents() {
        let n = hotParticles.count
        hotEdges.removeAll(keepingCapacity: true)
        guard n > 0 else { hotKmax = 0; return }

        let curL = L
        let curHalfL = curL / 2
        let storeEdges = scenario == .largestComponent

        // ── Pick the optimal "large" cut-off K ────────────────────────────
        var ks: [Int] = [0]
        var k = 1
        while k < n {
            ks.append(k)
            k *= 2
        }
        if ks.last != n { ks.append(n) }

        var bestK = 0
        var bestCost = Double.infinity
        var bestCols = max(1, Int(curL / max(curL / 50, 1e-6)))

        for K in ks {
            let maxSmallR = (K >= n) ? 0 : hotParticles[radiusOrder[K]].radius
            let cellSize = max(curL / 50, 2 * maxSmallR, 1e-6)
            let cols = max(1, Int(curL / cellSize))
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

        if ufParent.count < n { ufParent = [Int](repeating: 0, count: n) }
        if ufSize.count < n { ufSize = [Int](repeating: 0, count: n) }
        for i in 0..<n { ufParent[i] = i }

        hotParticles.withUnsafeBufferPointer { partsBuf in
            ufParent.withUnsafeMutableBufferPointer { parentBuf in

                @inline(__always)
                func find(_ x: Int) -> Int {
                    var x = x
                    while parentBuf[x] != x {
                        parentBuf[x] = parentBuf[parentBuf[x]]
                        x = parentBuf[x]
                    }
                    return x
                }

                @inline(__always)
                func unionRoots(_ ra: Int, _ rb: Int) {
                    if ra != rb { parentBuf[ra] = rb }
                }

                if !useGrid {
                    // ── Pure O(N²) fallback ───────────────────────────────
                    for i in 0..<(n - 1) {
                        let u = partsBuf[i]
                        for j in (i + 1)..<n {
                            let v = partsBuf[j]
                            let thr = u.radius + v.radius
                            if torusDist2(u.x, u.y, v.x, v.y, curL, curHalfL) < thr * thr {
                                unionRoots(find(i), find(j))
                                if storeEdges {
                                    let rel = relPos(v.x, v.y, u.x, u.y, curL, curHalfL)
                                    hotEdges.append(DPEdge(i: i, j: j, vRelX: rel.0, vRelY: rel.1))
                                }
                            }
                        }
                    }
                } else {
                    let s = curL / Double(cols)
                    let totalCells = cols * cols
                    let nSmall = n - nLarge

                    var isLarge = [UInt8](repeating: 0, count: n)
                    var largePos = [Int](repeating: 0, count: n)
                    for kk in 0..<nLarge {
                        let li = radiusOrder[kk]
                        isLarge[li] = 1
                        largePos[li] = kk
                    }

                    // ── Flat grid (reusable storage, no per-tick heap allocs)
                    if gridCellCounts.count < totalCells {
                        gridCellCounts = [Int](repeating: 0, count: totalCells)
                        gridOffsets = [Int](repeating: 0, count: totalCells + 1)
                    } else {
                        for c in 0..<totalCells { gridCellCounts[c] = 0 }
                    }
                    if gridParticleIndices.count < nSmall {
                        gridParticleIndices = [Int](repeating: 0, count: max(nSmall, 256))
                    }

                    // Count pass
                    for i in 0..<n {
                        if isLarge[i] != 0 { continue }
                        let p = partsBuf[i]
                        var cx = Int((p.x + curHalfL) / s) % cols
                        if cx < 0 { cx += cols }
                        var cy = Int((p.y + curHalfL) / s) % cols
                        if cy < 0 { cy += cols }
                        gridCellCounts[cx + cy * cols] += 1
                    }

                    // Prefix sum → offsets
                    gridOffsets[0] = 0
                    for c in 0..<totalCells {
                        gridOffsets[c + 1] = gridOffsets[c] + gridCellCounts[c]
                    }

                    // Fill pass (reuse gridCellCounts as write cursors)
                    for c in 0..<totalCells { gridCellCounts[c] = gridOffsets[c] }
                    for i in 0..<n {
                        if isLarge[i] != 0 { continue }
                        let p = partsBuf[i]
                        var cx = Int((p.x + curHalfL) / s) % cols
                        if cx < 0 { cx += cols }
                        var cy = Int((p.y + curHalfL) / s) % cols
                        if cy < 0 { cy += cols }
                        let cell = cx + cy * cols
                        gridParticleIndices[gridCellCounts[cell]] = i
                        gridCellCounts[cell] += 1
                    }

                    // ── Small-small via flat grid ──────────────────────────
                    for cy in 0..<cols {
                        for cx in 0..<cols {
                            let cell = cx + cy * cols
                            let aStart = gridOffsets[cell]
                            let aEnd = gridOffsets[cell + 1]
                            if aStart == aEnd { continue }
                            for dy in -1...1 {
                                let ny = (cy + dy + cols) % cols
                                for dx in -1...1 {
                                    let nx = (cx + dx + cols) % cols
                                    let nbrCell = nx + ny * cols
                                    let bStart = gridOffsets[nbrCell]
                                    let bEnd = gridOffsets[nbrCell + 1]
                                    if bStart == bEnd { continue }
                                    let sameCell = (dx == 0 && dy == 0)
                                    for a in aStart..<aEnd {
                                        let i = gridParticleIndices[a]
                                        let u = partsBuf[i]
                                        let b0 = sameCell ? a + 1 : bStart
                                        for b in b0..<bEnd {
                                            let j = gridParticleIndices[b]
                                            if !sameCell && j <= i { continue }
                                            let v = partsBuf[j]
                                            let thr = u.radius + v.radius
                                            if torusDist2(u.x, u.y, v.x, v.y, curL, curHalfL) < thr * thr {
                                                unionRoots(find(i), find(j))
                                                if storeEdges {
                                                    let rel = relPos(v.x, v.y, u.x, u.y, curL, curHalfL)
                                                    hotEdges.append(DPEdge(i: i, j: j, vRelX: rel.0, vRelY: rel.1))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Large-vs-everyone ─────────────────────────────────
                    for kIdx in 0..<nLarge {
                        let li = radiusOrder[kIdx]
                        let u = partsBuf[li]
                        for j in 0..<n {
                            if j == li { continue }
                            if isLarge[j] != 0 && largePos[j] < kIdx { continue }
                            let v = partsBuf[j]
                            let thr = u.radius + v.radius
                            if torusDist2(u.x, u.y, v.x, v.y, curL, curHalfL) < thr * thr {
                                let aIdx = li < j ? li : j
                                let bIdx = li < j ? j : li
                                unionRoots(find(aIdx), find(bIdx))
                                if storeEdges {
                                    let pa = partsBuf[aIdx]
                                    let pb = partsBuf[bIdx]
                                    let rel = relPos(pb.x, pb.y, pa.x, pa.y, curL, curHalfL)
                                    hotEdges.append(DPEdge(i: aIdx, j: bIdx, vRelX: rel.0, vRelY: rel.1))
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Component sizes ───────────────────────────────────────────────
        for i in 0..<n { ufSize[i] = 0 }
        ufParent.withUnsafeMutableBufferPointer { parentBuf in
            for i in 0..<n {
                var x = i
                while parentBuf[x] != x {
                    parentBuf[x] = parentBuf[parentBuf[x]]
                    x = parentBuf[x]
                }
                ufSize[x] += 1
            }
        }

        var maxSize = 0
        hotParticles.withUnsafeMutableBufferPointer { buf in
            ufParent.withUnsafeBufferPointer { parentBuf in
                for i in 0..<n {
                    var x = i
                    while parentBuf[x] != x { x = parentBuf[x] }
                    let root = x
                    buf[i].root = root
                    buf[i].compSize = ufSize[root]
                    if ufSize[root] > maxSize { maxSize = ufSize[root] }
                }
            }
        }
        hotKmax = maxSize
    }
}
