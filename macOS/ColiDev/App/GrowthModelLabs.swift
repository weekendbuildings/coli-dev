import Foundation

/// Euler's method for the mathematics lesson (OpenStax Calculus Volume 2, 4.2) on dN/dt = r · N:
/// yₙ = yₙ₋₁ + h · f(tₙ₋₁, yₙ₋₁), compared with the exact solution N₀ · e^(r·t).
enum EulerMethodModel {
    static let initialPopulation = 100.0
    static let growthRate = 0.1
    static let stepSizes: [Double] = [1, 0.5, 0.25, 0.1]
    static let endTimeRange = 2...20

    static func stepCount(stepSize: Double, endTime: Int) -> Int { Int((Double(endTime) / stepSize).rounded()) }

    /// The broken line of Euler's method: (t, N) after each step, starting at t = 0.
    static func eulerPoints(stepSize: Double, endTime: Int) -> [(t: Double, value: Double)] {
        var value = initialPopulation
        var points = [(t: 0.0, value: value)]
        for step in 1...stepCount(stepSize: stepSize, endTime: endTime) {
            value += stepSize * growthRate * value
            points.append((t: Double(step) * stepSize, value: value))
        }
        return points
    }

    static func eulerValue(stepSize: Double, endTime: Int) -> Double {
        eulerPoints(stepSize: stepSize, endTime: endTime).last?.value ?? initialPopulation
    }

    static func exactValue(at time: Double) -> Double { initialPopulation * exp(growthRate * time) }
}

/// Autocatalysis for the chemistry lesson on prebiotic chemistry: an ordinary catalyst adds one molecule per hour,
/// while autocatalytic molecules each make a copy of themselves every hour, so their number doubles.
enum AutocatalysisModel {
    static let hourRange = 0...20

    static func catalysed(hours: Int) -> Int { 1 + hours }

    static func autocatalytic(hours: Int) -> Int { 1 << hours }

    /// The first hour at which doubling gives strictly more molecules than adding one per hour.
    static var overtakingHour: Int {
        hourRange.first { autocatalytic(hours: $0) > catalysed(hours: $0) } ?? hourRange.upperBound
    }
}
