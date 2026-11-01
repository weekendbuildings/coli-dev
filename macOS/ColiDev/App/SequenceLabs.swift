import Foundation

/// Copying accuracy and the longest genome Eigen's error threshold allows, for the biology lesson on DNA
/// replication fidelity: information survives while σ · (1 − e)ᴸ > 1, so L < ln σ / −ln(1 − e) ≈ ln σ / e.
enum GenomeFidelityModel {
    /// The error per letter is e = 10^(−exponent).
    static let exponentRange = 2...10
    static let advantageRange = 2.0...100.0

    static func errorRate(exponent: Int) -> Double { pow(10, -Double(exponent)) }

    /// The largest whole length with σ · (1 − e)ᴸ > 1.
    static func exactLimit(exponent: Int, advantage: Double) -> Double {
        let bound = log(advantage) / -log1p(-errorRate(exponent: exponent))
        let floorBound = bound.rounded(.down)
        return floorBound == bound ? floorBound - 1 : floorBound
    }

    /// The lesson's approximation L ≈ ln σ / e.
    static func approximateLimit(exponent: Int, advantage: Double) -> Double {
        log(advantage) / errorRate(exponent: exponent)
    }
}

/// Hamming distance between aligned DNA sequences for the biology lesson on sequence comparison:
/// the number of positions at which two strings of equal length differ.
enum HammingModel {
    static let alphabet: Set<Character> = ["A", "T", "G", "C"]

    static func isValid(_ sequence: String) -> Bool { !sequence.isEmpty && sequence.allSatisfy { alphabet.contains($0) } }

    static func mismatchPositions(_ first: String, _ second: String) -> [Int]? {
        guard isValid(first), isValid(second), first.count == second.count else { return nil }
        return zip(first, second).enumerated().compactMap { index, pair in pair.0 == pair.1 ? nil : index + 1 }
    }

    static func distance(_ first: String, _ second: String) -> Int? { mismatchPositions(first, second)?.count }

    static func identity(_ first: String, _ second: String) -> Double? {
        guard let distance = distance(first, second) else { return nil }
        return Double(first.count - distance) / Double(first.count) * 100
    }
}
