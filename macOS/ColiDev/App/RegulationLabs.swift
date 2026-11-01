import Foundation

/// Radioactive dating for the physics lesson (OpenStax College Physics 2e, 31.5): N/N₀ = (1/2)^(t / t½),
/// so the remaining share of an isotope gives the age t = t½ · log₂(N₀ / N).
enum RadioactiveDatingModel {
    struct Isotope: Equatable {
        var halfLifeYears: Double
    }

    static let carbon14 = Isotope(halfLifeYears: 5730)
    static let uranium238 = Isotope(halfLifeYears: 4.5e9)
    static let isotopes = [carbon14, uranium238]
    static let remainingPercentRange = 1.0...100.0

    static func remainingShare(after years: Double, isotope: Isotope) -> Double { pow(0.5, years / isotope.halfLifeYears) }

    static func halfLives(remainingPercent: Double) -> Double { log2(100 / remainingPercent) }

    static func age(remainingPercent: Double, isotope: Isotope) -> Double {
        isotope.halfLifeYears * halfLives(remainingPercent: remainingPercent)
    }

    static func halfLivesElapsed(years: Double, isotope: Isotope) -> Double { years / isotope.halfLifeYears }
}

/// Feedback loops for the biology lesson on homeostasis, in illustrative units: after a disturbance, negative
/// feedback shrinks the deviation from the set point by a share k each step, positive feedback grows it by k.
enum FeedbackLoopModel {
    static let setPoint = 37.0
    static let gainRange = 0.1...0.5
    static let disturbanceRange = -3.0...3.0
    static let steps = 15

    static func deviation(after step: Int, initial: Double, gain: Double, negative: Bool) -> Double {
        initial * pow(negative ? 1 - gain : 1 + gain, Double(step))
    }

    static func temperatures(initial: Double, gain: Double, negative: Bool) -> [Double] {
        (0...steps).map { setPoint + deviation(after: $0, initial: initial, gain: gain, negative: negative) }
    }
}
