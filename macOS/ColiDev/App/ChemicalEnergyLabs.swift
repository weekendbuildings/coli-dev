import Foundation

/// Energy coupling for the chemistry lesson on the thermodynamics of living systems (OpenStax Biology 2e, 6.4):
/// ΔG values of coupled reactions add up, and ATP hydrolysis gives −30.5 kJ/mol under standard conditions.
enum EnergyCouplingModel {
    static let atpFreeEnergy = -30.5               // kJ/mol
    static let reactionRange = 1.0...100.0         // kJ/mol
    static let atpRange = 0...5

    static func total(reaction: Double, atpCount: Int) -> Double { reaction + Double(atpCount) * atpFreeEnergy }

    static func runs(reaction: Double, atpCount: Int) -> Bool { total(reaction: reaction, atpCount: atpCount) < 0 }

    /// The fewest ATP whose hydrolysis makes the total ΔG negative.
    static func minimumATP(reaction: Double) -> Int { Int((reaction / -atpFreeEnergy).rounded(.down)) + 1 }
}

/// The reaction quotient for CO + H₂O ⇌ CO₂ + H₂ from the chemistry lesson (OpenStax Chemistry 2e, 13.2–13.3):
/// Q = [CO₂][H₂] / ([CO][H₂O]); Q < K runs forward, Q > K runs in reverse, until Q = K.
enum ReactionQuotientModel {
    struct Mixture: Equatable {
        var carbonMonoxide: Double
        var water: Double
        var carbonDioxide: Double
        var hydrogen: Double
    }

    static let equilibriumConstant = 0.64
    static let concentrationRange = 0.001...0.05   // mol/L
    static let lessonMixture = Mixture(carbonMonoxide: 0.020, water: 0.020, carbonDioxide: 0.0040, hydrogen: 0.0040)

    enum Direction: Equatable { case forward, reverse, equilibrium }

    static func quotient(_ mixture: Mixture) -> Double {
        mixture.carbonDioxide * mixture.hydrogen / (mixture.carbonMonoxide * mixture.water)
    }

    static func direction(_ mixture: Mixture, tolerance: Double = 1e-6) -> Direction {
        let q = quotient(mixture)
        if abs(q - equilibriumConstant) <= tolerance * equilibriumConstant { return .equilibrium }
        return q < equilibriumConstant ? .forward : .reverse
    }

    /// The mixture after the reaction shifts by x mol/L (positive forward) until Q = K. The difference
    /// (CO₂ + x)(H₂ + x) − K(CO − x)(H₂O − x) grows with x on the allowed interval, so bisection finds x.
    static func equilibrate(_ mixture: Mixture) -> Mixture {
        func excess(_ x: Double) -> Double {
            (mixture.carbonDioxide + x) * (mixture.hydrogen + x)
                - equilibriumConstant * (mixture.carbonMonoxide - x) * (mixture.water - x)
        }
        var low = -min(mixture.carbonDioxide, mixture.hydrogen)
        var high = min(mixture.carbonMonoxide, mixture.water)
        for _ in 0..<200 {
            let middle = (low + high) / 2
            if excess(middle) < 0 { low = middle } else { high = middle }
        }
        let x = (low + high) / 2
        return Mixture(carbonMonoxide: mixture.carbonMonoxide - x, water: mixture.water - x,
                       carbonDioxide: mixture.carbonDioxide + x, hydrogen: mixture.hydrogen + x)
    }
}
