import Foundation
import Observation

enum InfectionState: Sendable {
    case susceptible
    case infected
}

struct Node {
    var x: Double
    var y: Double
    var radiusSeed: Double
    var radius: Double = 0
    var state: InfectionState = .susceptible

    // Stored randomness driving the current Lévy step. Storing the uniform
    // and Gaussian draws lets the step length re-scale instantly when the
    // user drags the alpha slider mid-flight.
    var stepUniform: Double = 0
    var stepGaussian: Double = 0
    var stepAngle: Double = 0
    var stepDistance: Double = 0
}

struct Edge {
    var u: Int
    var v: Int
    var vRelX: Double
    var vRelY: Double
}

@Observable
final class Simulation {

    // MARK: - Parameters

    var L: Double = 1000 {
        didSet { if L != oldValue { wrapPositions() } }
    }
    var N: Int = 200 {
        didSet { if N != oldValue { resampleN() } }
    }
    var deterministicRadii: Bool = false {
        didSet { if deterministicRadii != oldValue { recomputeRadii() } }
    }
    var r0: Double = 25 {
        didSet { if r0 != oldValue, deterministicRadii { recomputeRadii() } }
    }
    var xm: Double = 15 {
        didSet { if xm != oldValue, !deterministicRadii { recomputeRadii() } }
    }
    var gamma: Double = 2.5 {
        didSet { if gamma != oldValue, !deterministicRadii { recomputeRadii() } }
    }

    var alpha: Double = 2.0
    var speed: Double = 2.0
    var beta: Double = 0.10
    var delta: Double = 0.02

    var motionFrozen: Bool = true
    var isPaused: Bool = false

    // MARK: - State

    private(set) var nodes: [Node] = []
    private(set) var edges: [Edge] = []
    private(set) var history: [Double] = []
    private(set) var prevalence: Double = 0
    private(set) var avgDegree: Double = 0

    let maxHistory = 600

    init() { reset() }

    // MARK: - Lifecycle

    func reset() {
        nodes = (0..<N).map { _ in makeNode() }
        edges.removeAll(keepingCapacity: true)
        history.removeAll(keepingCapacity: true)
        prevalence = 0
        avgDegree = 0
    }

    private func makeNode() -> Node {
        var node = Node(
            x: Double.random(in: 0..<L),
            y: Double.random(in: 0..<L),
            radiusSeed: Double.random(in: 1e-6..<1)
        )
        node.radius = computeRadius(u: node.radiusSeed)
        sampleStep(for: &node)
        return node
    }

    private func resampleN() {
        if nodes.count < N {
            nodes.append(contentsOf: (nodes.count..<N).map { _ in makeNode() })
        } else if nodes.count > N {
            nodes.removeLast(nodes.count - N)
        }
        // Edges are cleared so that stale indices (from the previous tick)
        // can never reference nodes that have just been removed.
        edges.removeAll(keepingCapacity: true)
    }

    private func wrapPositions() {
        for i in nodes.indices {
            nodes[i].x = nodes[i].x.truncatingRemainder(dividingBy: L)
            nodes[i].y = nodes[i].y.truncatingRemainder(dividingBy: L)
            if nodes[i].x < 0 { nodes[i].x += L }
            if nodes[i].y < 0 { nodes[i].y += L }
        }
    }

    // MARK: - Radius distribution

    func computeRadius(u: Double) -> Double {
        deterministicRadii ? r0 : xm * pow(u, -1.0 / gamma)
    }

    private func recomputeRadii() {
        for i in nodes.indices {
            nodes[i].radius = computeRadius(u: nodes[i].radiusSeed)
        }
    }

    /// First and second moment of the radius distribution. Returns nil for
    /// the heavy-tailed regime where the second moment diverges.
    func radiusMoments() -> (mean: Double, meanSq: Double)? {
        if deterministicRadii { return (r0, r0 * r0) }
        guard gamma > 2.0 else { return nil }
        return (
            mean: gamma * xm / (gamma - 1),
            meanSq: gamma * xm * xm / (gamma - 2)
        )
    }

    // MARK: - Lévy step

    private func sampleStep(for node: inout Node) {
        node.stepUniform = Double.random(in: 1e-9..<1)
        let u1 = Double.random(in: 1e-9..<1)
        let u2 = Double.random(in: 0..<1)
        node.stepGaussian = abs(sqrt(-2 * log(u1)) * cos(2 * .pi * u2))
        node.stepAngle = Double.random(in: 0..<(2 * .pi))
        node.stepDistance = 0
    }

    private func currentStepLength(for node: Node) -> Double {
        let baseScale = 20.0
        if alpha >= 1.99 {
            return node.stepGaussian * baseScale
        }
        return min(pow(node.stepUniform, -1.0 / alpha) * baseScale, L * 3)
    }

    private func step(_ node: inout Node) {
        var total = currentStepLength(for: node)
        if node.stepDistance >= total {
            sampleStep(for: &node)
            total = currentStepLength(for: node)
        }
        node.x += speed * cos(node.stepAngle)
        node.y += speed * sin(node.stepAngle)
        node.stepDistance += speed
        if node.x < 0 { node.x += L }
        if node.x >= L { node.x -= L }
        if node.y < 0 { node.y += L }
        if node.y >= L { node.y -= L }
    }

    // MARK: - Geometry on the torus

    private func distSqTorus(_ a: Node, _ b: Node) -> Double {
        var dx = abs(a.x - b.x)
        var dy = abs(a.y - b.y)
        if dx > L / 2 { dx = L - dx }
        if dy > L / 2 { dy = L - dy }
        return dx * dx + dy * dy
    }

    private func relativePosition(of b: Node, relativeTo a: Node) -> (x: Double, y: Double) {
        var x = b.x
        var y = b.y
        if x - a.x > L / 2 { x -= L } else if a.x - x > L / 2 { x += L }
        if y - a.y > L / 2 { y -= L } else if a.y - y > L / 2 { y += L }
        return (x, y)
    }

    // MARK: - Tap-to-infect

    func infect(at point: SIMD2<Double>, withinRadius threshold: Double) {
        let thr2 = threshold * threshold
        var bestIndex: Int? = nil
        var bestDistance = Double.infinity
        for i in nodes.indices {
            let dx = nodes[i].x - point.x
            let dy = nodes[i].y - point.y
            let d = dx * dx + dy * dy
            if d < bestDistance {
                bestDistance = d
                bestIndex = i
            }
        }
        if let idx = bestIndex, bestDistance < thr2 {
            nodes[idx].state = .infected
        }
    }

    // MARK: - Tick

    func tick() {
        if !motionFrozen {
            for i in nodes.indices { step(&nodes[i]) }
        }

        edges.removeAll(keepingCapacity: true)
        var infectedNeighbours = [Int](repeating: 0, count: nodes.count)
        var connectedPairs = 0
        let count = nodes.count
        if count >= 2 {
            for i in 0..<(count - 1) {
                let ni = nodes[i]
                for j in (i + 1)..<count {
                    let nj = nodes[j]
                    let r = ni.radius + nj.radius
                    if distSqTorus(ni, nj) < r * r {
                        let rel = relativePosition(of: nj, relativeTo: ni)
                        edges.append(Edge(u: i, v: j, vRelX: rel.x, vRelY: rel.y))
                        if ni.state == .infected { infectedNeighbours[j] += 1 }
                        if nj.state == .infected { infectedNeighbours[i] += 1 }
                        connectedPairs += 1
                    }
                }
            }
        }

        let oldStates = nodes.map(\.state)
        for i in nodes.indices {
            switch oldStates[i] {
            case .infected:
                if Double.random(in: 0..<1) < delta {
                    nodes[i].state = .susceptible
                }
            case .susceptible:
                let k = infectedNeighbours[i]
                if k > 0 {
                    let p = 1 - exp(-beta * Double(k))
                    if Double.random(in: 0..<1) < p {
                        nodes[i].state = .infected
                    }
                }
            }
        }

        let infectedCount = nodes.lazy.filter { $0.state == .infected }.count
        prevalence = nodes.isEmpty ? 0 : Double(infectedCount) / Double(nodes.count)
        avgDegree = nodes.isEmpty ? 0 : Double(2 * connectedPairs) / Double(nodes.count)

        history.append(prevalence)
        if history.count > maxHistory {
            history.removeFirst(history.count - maxHistory)
        }
    }

    // MARK: - Derived quantities surfaced in the UI

    var density: Double { Double(N) / (L * L) * 10_000 }
    var r0Proxy: Double? { delta > 0 ? beta * avgDegree / delta : nil }

    private var connectivityTerm: Double? {
        guard let m = radiusMoments() else { return nil }
        return 2 * .pi * (m.meanSq + m.mean * m.mean)
    }

    // Slider critical values that mark the percolation/epidemic threshold
    // R_0 ≈ 1. Returns nil when the parameter does not have a finite
    // critical value at the current configuration.
    var criticalBeta: Double? {
        guard let term = connectivityTerm else { return nil }
        let kAvg = Double(N) / (L * L) * term
        guard kAvg > 0 else { return nil }
        return delta / kAvg
    }
    var criticalDelta: Double? {
        guard let term = connectivityTerm else { return nil }
        let kAvg = Double(N) / (L * L) * term
        return beta * kAvg
    }
    var criticalN: Double? {
        guard let term = connectivityTerm, beta > 0, term > 0 else { return nil }
        return delta / beta * (L * L / term)
    }
    var criticalL: Double? {
        guard let term = connectivityTerm, delta > 0 else { return nil }
        return sqrt(Double(N) * beta * term / delta)
    }
    var criticalXm: Double? {
        guard !deterministicRadii, beta > 0, gamma > 2 else { return nil }
        let gt = gamma / (gamma - 2) + pow(gamma / (gamma - 1), 2)
        guard gt > 0 else { return nil }
        return sqrt(delta / beta * (L * L / Double(N)) * (1 / (2 * .pi * gt)))
    }
}
