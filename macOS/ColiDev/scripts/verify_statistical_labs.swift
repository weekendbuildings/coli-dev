import Foundation

@main
enum StatisticalLabsVerification {
    static func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    static func main() {
        typealias Coins = CoinMicrostateModel
        // Entropy lesson: four coins give 1, 4, 6, 4, 1; five coins put 20 of 32 in the mixed outcomes.
        precondition((0...4).map { Coins.microstates(coins: 4, heads: $0) } == [1, 4, 6, 4, 1])
        precondition(Coins.total(coins: 4) == 16 && close(Coins.probability(coins: 4, heads: 2), 0.375))
        precondition(Coins.microstates(coins: 5, heads: 2) + Coins.microstates(coins: 5, heads: 3) == 20)
        precondition(Coins.total(coins: 5) == 32)
        precondition(Coins.microstates(coins: 20, heads: 10) == 184_756 && Coins.total(coins: 20) == 1_048_576)
        precondition(Coins.mostLikelyHeads(coins: 4) == 2 && Coins.mostLikelyHeads(coins: 5) == 2)
        precondition(Coins.microstates(coins: 4, heads: 5) == 0 && Coins.microstates(coins: 4, heads: -1) == 0)
        for coins in Coins.coinRange {
            let sum = (0...coins).map { Coins.probability(coins: coins, heads: $0) }.reduce(0, +)
            precondition(close(sum, 1), "probabilities for \(coins) coins add up to 1")
        }

        typealias HW = HardyWeinbergModel
        // Hardy–Weinberg lesson: q² = 0.16 gives q = 0.4, carriers 48%, YY 36%, three carriers per affected.
        let q = HW.recessiveAllele(fromAffectedShare: 0.16)
        precondition(close(q, 0.4))
        let genotypes = HW.genotypes(recessiveAllele: q)
        precondition(close(genotypes.heterozygous, 0.48) && close(genotypes.dominantHomozygous, 0.36))
        precondition(close(genotypes.recessiveHomozygous, 0.16))
        precondition(close(HW.carriersPerAffected(recessiveAllele: q), 3))
        // Practice population 49 / 42 / 9 is exactly p = 0.7.
        let practice = HW.genotypes(recessiveAllele: 0.3)
        precondition(close(practice.dominantHomozygous, 0.49) && close(practice.heterozygous, 0.42) && close(practice.recessiveHomozygous, 0.09))
        for step in 1...99 {
            let g = HW.genotypes(recessiveAllele: Double(step) / 100)
            precondition(close(g.dominantHomozygous + g.heterozygous + g.recessiveHomozygous, 1))
        }
        print("Statistical lab model checks passed.")
    }
}
