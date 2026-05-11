import Foundation

// Krumhansl-Schmuckler key-finding algorithm.
// Builds a pitch-class histogram from detected frequencies, then finds the
// major/minor key whose profile best correlates (Pearson r) with the histogram.
enum KeyFinder {

    // Krumhansl-Kessler tonal hierarchy profiles (C = index 0)
    private static let majorProfile: [Double] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    private static let minorProfile: [Double] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    private static let noteNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

    // Returns a key string like "Dm", "A", "F#m", or nil if there's not enough data.
    static func detect(from frequencies: [Float]) -> String? {
        guard frequencies.count >= 10 else { return nil }

        // Build normalized pitch-class histogram
        var histogram = [Double](repeating: 0, count: 12)
        for freq in frequencies {
            guard freq > 60, freq < 2000 else { continue }
            let midi = 69.0 + 12.0 * log2(Double(freq) / 440.0)
            let raw = Int(midi.rounded()) % 12
            histogram[(raw + 12) % 12] += 1
        }
        let total = histogram.reduce(0, +)
        guard total > 0 else { return nil }
        let norm = histogram.map { $0 / total }

        var bestKey = ""
        var bestScore = -Double.infinity

        for tonic in 0..<12 {
            let majorScore = pearson(norm, profile: majorProfile, tonic: tonic)
            if majorScore > bestScore { bestScore = majorScore; bestKey = noteNames[tonic] }

            let minorScore = pearson(norm, profile: minorProfile, tonic: tonic)
            if minorScore > bestScore { bestScore = minorScore; bestKey = "\(noteNames[tonic])m" }
        }

        return bestKey.isEmpty ? nil : bestKey
    }

    private static func pearson(_ histogram: [Double], profile: [Double], tonic: Int) -> Double {
        let n = 12
        let rotated = (0..<n).map { profile[($0 - tonic + n) % n] }
        let mH = histogram.reduce(0, +) / Double(n)
        let mP = rotated.reduce(0, +) / Double(n)
        var num = 0.0, dH = 0.0, dP = 0.0
        for i in 0..<n {
            let h = histogram[i] - mH
            let p = rotated[i] - mP
            num += h * p; dH += h * h; dP += p * p
        }
        let denom = sqrt(dH * dP)
        return denom > 0 ? num / denom : 0
    }
}
