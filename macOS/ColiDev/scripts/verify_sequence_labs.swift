import Foundation

@main
enum SequenceLabsVerification {
    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    static func main() {
        typealias Fidelity = GenomeFidelityModel
        // "What life is": a 1% error with σ = 10 allows only 229 letters.
        precondition(Fidelity.exactLimit(exponent: 2, advantage: 10) == 229)
        // Lesson quiz: e = 10⁻⁹ and σ = 10 give about 2.3 billion letters.
        let quiz = Fidelity.approximateLimit(exponent: 9, advantage: 10)
        precondition(close(quiz / 1e9, 2.302585, 1e-6))
        precondition(abs(Fidelity.exactLimit(exponent: 9, advantage: 10) - quiz) < 2)
        // Practice task: 10⁻⁴ and 10⁻⁶ give about 23 026 and 2 302 585 letters; 100 times less error, 100 times longer.
        precondition(Int(Fidelity.approximateLimit(exponent: 4, advantage: 10).rounded()) == 23_026)
        precondition(Int(Fidelity.approximateLimit(exponent: 6, advantage: 10).rounded()) == 2_302_585)
        for exponent in Fidelity.exponentRange.dropLast(2) {
            let ratio = Fidelity.approximateLimit(exponent: exponent + 2, advantage: 10) / Fidelity.approximateLimit(exponent: exponent, advantage: 10)
            precondition(close(ratio, 100, 1e-6))
        }
        // The exact limit is the largest length that still satisfies σ · (1 − e)ᴸ > 1.
        for exponent in 2...6 {
            let limit = Fidelity.exactLimit(exponent: exponent, advantage: 10)
            let e = Fidelity.errorRate(exponent: exponent)
            precondition(10 * pow(1 - e, limit) > 1 && 10 * pow(1 - e, limit + 1) <= 1)
        }

        typealias Hamming = HammingModel
        // Lesson program: "ATGCCGTA" and "ATGACGTT" differ at positions 4 and 8, distance 2, identity 75%.
        precondition(Hamming.mismatchPositions("ATGCCGTA", "ATGACGTT") == [4, 8])
        precondition(Hamming.distance("ATGCCGTA", "ATGACGTT") == 2 && Hamming.identity("ATGCCGTA", "ATGACGTT") == 75)
        // Practice task: the third sequence "ATGACGTA" is one substitution from each of the other two.
        precondition(Hamming.distance("ATGCCGTA", "ATGACGTA") == 1 && Hamming.distance("ATGACGTT", "ATGACGTA") == 1)
        // Unequal lengths and letters outside A, T, G, C have no Hamming distance.
        precondition(Hamming.distance("ATGC", "ATG") == nil && Hamming.distance("ATGX", "ATGC") == nil)
        precondition(Hamming.distance("", "") == nil && Hamming.distance("ACGT", "ACGT") == 0)
        print("Genome fidelity and Hamming distance lab models verified")
    }
}
