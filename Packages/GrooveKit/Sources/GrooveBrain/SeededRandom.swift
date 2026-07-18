/// SplitMix64 — tiny, fast, deterministic PRNG so a groove is reproducible from a seed.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    public mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    /// Approximately normal, mean 0, stdDev 1 (sum of uniforms).
    public mutating func gaussian() -> Double {
        var sum = 0.0
        for _ in 0..<6 { sum += unit() }
        return (sum - 3.0)
    }
}
