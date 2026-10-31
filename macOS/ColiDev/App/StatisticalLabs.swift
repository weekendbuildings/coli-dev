import Foundation

/// Coin microstates for the physics entropy lesson (OpenStax College Physics 2e, 15.7): N coins have 2^N
/// equally likely sequences, and the macrostate "k heads" has C(N, k) of them.
enum CoinMicrostateModel {
    static let coinRange = 1...20

    static func microstates(coins: Int, heads: Int) -> Int {
        guard heads >= 0, heads <= coins else { return 0 }
        var result = 1
        for index in 0..<min(heads, coins - heads) {
            result = result * (coins - index) / (index + 1)
        }
        return result
    }

    static func total(coins: Int) -> Int { 1 << coins }

    static func probability(coins: Int, heads: Int) -> Double {
        Double(microstates(coins: coins, heads: heads)) / Double(total(coins: coins))
    }

    /// The most likely number of heads; for an odd N the two middle outcomes tie and the smaller is returned.
    static func mostLikelyHeads(coins: Int) -> Int { coins / 2 }
}

/// Genotype frequencies for the biology Hardy–Weinberg lesson (OpenStax Biology 2e, 19.1).
enum HardyWeinbergModel {
    static let recessiveRange = 0.01...0.99

    struct Genotypes: Equatable {
        let dominantHomozygous: Double
        let heterozygous: Double
        let recessiveHomozygous: Double
    }

    static func genotypes(recessiveAllele q: Double) -> Genotypes {
        let p = 1 - q
        return Genotypes(dominantHomozygous: p * p, heterozygous: 2 * p * q, recessiveHomozygous: q * q)
    }

    /// The recessive allele frequency from the share of individuals showing the recessive trait: q = √q².
    static func recessiveAllele(fromAffectedShare share: Double) -> Double {
        share.squareRoot()
    }

    /// How many hidden carriers there are per individual showing the trait: 2pq / q² = 2p / q.
    static func carriersPerAffected(recessiveAllele q: Double) -> Double {
        2 * (1 - q) / q
    }
}
