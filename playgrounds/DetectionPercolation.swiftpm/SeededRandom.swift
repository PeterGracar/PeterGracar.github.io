import Foundation

/// Deterministic 32-bit PRNG (mulberry32 seeded by xmur3 over the seed
/// string) — the same recipe used by the standalone HTML simulations, so
/// runs with the same seed string match across platforms.
struct SeededRandom {
    private var state: UInt32

    init(seed: String) {
        var h: UInt32 = 1779033703 ^ UInt32(truncatingIfNeeded: seed.utf8.count)
        for byte in seed.utf8 {
            h = (h ^ UInt32(byte)) &* 3432918353
            h = (h << 13) | (h >> 19)
        }
        // Run xmur3's output function once to derive the mulberry32 seed.
        h = (h ^ (h >> 16)) &* 2246822507
        h = (h ^ (h >> 13)) &* 3266489909
        h = h ^ (h >> 16)
        self.state = h
    }

    mutating func nextUInt32() -> UInt32 {
        state = state &+ 0x6D2B79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return t ^ (t >> 14)
    }

    mutating func uniform() -> Double {
        Double(nextUInt32()) / 4294967296.0
    }

    mutating func uniformOpen() -> Double {
        // Excludes 0 so log() / power transforms are safe.
        var u = uniform()
        if u == 0 { u = 1e-12 }
        return u
    }

    mutating func gaussian() -> Double {
        // Box–Muller. Both draws must be > 0 to avoid log(0).
        let u = uniformOpen()
        let v = uniformOpen()
        return sqrt(-2 * log(u)) * cos(2 * .pi * v)
    }
}
