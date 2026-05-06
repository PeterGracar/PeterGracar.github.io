import Foundation
import Observation

struct LBMPoint: Sendable {
    var x: Double
    var y: Double
    var time: Int
}

@Observable
final class LBMSimulation {

    // MARK: - Parameters

    var alpha: Double = 1.0 {
        didSet {
            if alpha != oldValue {
                sausageRadius = radiusForQuantile(percent: sausageQuantilePercent)
            }
        }
    }
    var speed: Int = 5
    /// Sausage radius. Backed by a `quantile` slider in the UI: the radius is
    /// the q-th quantile of the Lévy jump distribution at the current α.
    var sausageQuantilePercent: Double = 50 {
        didSet { sausageRadius = radiusForQuantile(percent: sausageQuantilePercent) }
    }
    var sausageRadius: Double = 5.0
    var showBrownian: Bool = true
    var showLevy: Bool = false
    var showSausage: Bool = false

    var seed: String = "lbm"
    var hasStarted: Bool = false
    var isPaused: Bool = false

    // MARK: - State

    private(set) var levy: [LBMPoint] = []
    private(set) var brownian: [LBMPoint] = []
    private(set) var time: Int = 0

    private var levyPos: SIMD2<Double> = .zero
    private var brownianPos: SIMD2<Double> = .zero
    private var rng = SeededRandom(seed: "lbm")

    // MARK: - Constants

    let baseScale: Double = 5.0
    let colorSpeedFactor: Double = 0.05
    var cyclePeriod: Double { (360 / colorSpeedFactor) * 4 }   // 28800
    let maxLevyPoints = 30_000
    let maxBrownianPoints = 30_000

    init() {
        seed = randomSeed()
        sausageRadius = radiusForQuantile(percent: sausageQuantilePercent)
        reset(seed: seed)
    }

    // MARK: - Lifecycle

    func reset(seed newSeed: String? = nil) {
        if let s = newSeed { seed = s }
        rng = SeededRandom(seed: seed)
        time = 0
        levyPos = .zero
        brownianPos = .zero
        levy = [LBMPoint(x: 0, y: 0, time: 0)]
        brownian = [LBMPoint(x: 0, y: 0, time: 0)]
        hasStarted = false
        isPaused = false
        sausageRadius = radiusForQuantile(percent: sausageQuantilePercent)
    }

    func newSeed() {
        reset(seed: randomSeed())
    }

    private func randomSeed() -> String {
        "lbm-" + String(UInt32.random(in: 0..<UInt32.max), radix: 36)
    }

    // MARK: - Step

    func tickIfRunning() {
        guard hasStarted, !isPaused else { return }
        for _ in 0..<speed {
            time += 1
            let theta = rng.uniform() * 2 * .pi
            let dirX = cos(theta)
            let dirY = sin(theta)

            // Lévy jump
            let stepLevy = min(baseScale * pow(rng.uniformOpen(), -1 / alpha), 1e6)
            levyPos.x += dirX * stepLevy
            levyPos.y += dirY * stepLevy
            levy.append(LBMPoint(x: levyPos.x, y: levyPos.y, time: time))

            // Brownian step in the *same* direction so the two walks share
            // their angular sequence and only differ by jump magnitude.
            let stepBM = abs(rng.gaussian()) * baseScale
            brownianPos.x += dirX * stepBM
            brownianPos.y += dirY * stepBM
            brownian.append(LBMPoint(x: brownianPos.x, y: brownianPos.y, time: time))
        }
        if levy.count > maxLevyPoints {
            levy.removeFirst(levy.count - maxLevyPoints)
        }
        if brownian.count > maxBrownianPoints {
            brownian.removeFirst(brownian.count - maxBrownianPoints)
        }
    }

    // MARK: - Derived statistics

    /// Median Lévy jump under the inverse-power tail at the current α.
    var medianJumpSize: Double {
        baseScale * pow(2, 1 / alpha)
    }

    /// q-th quantile of |J|: P(|J| ≤ R(q)) = q.
    func radiusForQuantile(percent: Double) -> Double {
        let q = max(0, min(99.99, percent)) / 100.0
        return baseScale * pow(1 - q, -1 / alpha)
    }
}
