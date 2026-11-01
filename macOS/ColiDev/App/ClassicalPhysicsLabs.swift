import Foundation

/// Two resistors in series or parallel for the physics lesson on circuits (OpenStax College Physics 2e, 20.2, 21.1):
/// series R = R₁ + R₂, parallel 1/R = 1/R₁ + 1/R₂, and Ohm's law I = V / R.
enum CircuitModel {
    static let resistanceRange = 1.0...20.0   // Ω
    static let voltageRange = 1.0...24.0      // V

    static func totalResistance(_ first: Double, _ second: Double, parallel: Bool) -> Double {
        parallel ? 1 / (1 / first + 1 / second) : first + second
    }

    static func totalCurrent(voltage: Double, _ first: Double, _ second: Double, parallel: Bool) -> Double {
        voltage / totalResistance(first, second, parallel: parallel)
    }

    /// Current through one resistor: the full current in series, V / R in parallel.
    static func branchCurrent(voltage: Double, resistor: Double, other: Double, parallel: Bool) -> Double {
        parallel ? voltage / resistor : totalCurrent(voltage: voltage, resistor, other, parallel: false)
    }

    static func branchVoltage(voltage: Double, resistor: Double, other: Double, parallel: Bool) -> Double {
        parallel ? voltage : voltage * resistor / (resistor + other)
    }
}

/// Snell's law for the physics lesson on refraction (OpenStax College Physics 2e, 25.3–25.4):
/// n₁ sin θ₁ = n₂ sin θ₂, v = c / n, and total internal reflection when sin θ₂ would exceed 1.
enum RefractionModel {
    struct Medium: Equatable {
        var index: Double
    }

    static let speedOfLight = 3.00e8
    static let air = Medium(index: 1.00)
    static let water = Medium(index: 1.333)
    static let glass = Medium(index: 1.52)
    static let diamond = Medium(index: 2.419)
    static let media = [air, water, glass, diamond]
    static let angleRange = 0.0...89.0

    static func speed(in medium: Medium) -> Double { speedOfLight / medium.index }

    /// The refraction angle in degrees, or nil when the ray is totally internally reflected.
    static func refractionAngle(incidence: Double, from first: Medium, to second: Medium) -> Double? {
        let sine = first.index * sin(incidence * .pi / 180) / second.index
        guard sine <= 1 else { return nil }
        return asin(sine) * 180 / .pi
    }

    static func criticalAngle(from first: Medium, to second: Medium) -> Double? {
        guard first.index > second.index else { return nil }
        return asin(second.index / first.index) * 180 / .pi
    }
}

/// A seesaw for the physics lesson on torque (OpenStax College Physics 2e, 9.2): τ = r F with F = m g,
/// and balance when the torques on both sides are equal, m₁ r₁ = m₂ r₂.
enum SeesawModel {
    static let gravity = 9.80
    static let massRange = 10.0...60.0     // kg
    static let distanceRange = 0.5...3.0   // m

    static func torque(mass: Double, distance: Double) -> Double { mass * gravity * distance }

    static func balancingDistance(mass: Double, distance: Double, otherMass: Double) -> Double { mass * distance / otherMass }

    static func netTorque(leftMass: Double, leftDistance: Double, rightMass: Double, rightDistance: Double) -> Double {
        torque(mass: rightMass, distance: rightDistance) - torque(mass: leftMass, distance: leftDistance)
    }
}
