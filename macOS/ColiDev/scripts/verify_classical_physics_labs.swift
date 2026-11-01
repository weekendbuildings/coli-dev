import Foundation

@main
enum ClassicalPhysicsLabsVerification {
    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    static func main() {
        typealias Circuit = CircuitModel
        // Lesson quiz: 2 Ω and 6 Ω in parallel on 12 V give 1.5 Ω and 8 A.
        precondition(close(Circuit.totalResistance(2, 6, parallel: true), 1.5) && close(Circuit.totalCurrent(voltage: 12, 2, 6, parallel: true), 8))
        // The wrong answer: in series they give 1.5 A.
        precondition(close(Circuit.totalCurrent(voltage: 12, 2, 6, parallel: false), 1.5))
        // Practice task: 4 Ω and 12 Ω on 6 V give 0.375 A in series and 2 A in parallel; the parallel R is below 4 Ω.
        precondition(close(Circuit.totalCurrent(voltage: 6, 4, 12, parallel: false), 0.375) && close(Circuit.totalCurrent(voltage: 6, 4, 12, parallel: true), 2))
        precondition(Circuit.totalResistance(4, 12, parallel: true) < 4)
        // Branch currents add up in parallel; branch voltages add up in series.
        precondition(close(Circuit.branchCurrent(voltage: 12, resistor: 2, other: 6, parallel: true)
                           + Circuit.branchCurrent(voltage: 12, resistor: 6, other: 2, parallel: true), 8))
        precondition(close(Circuit.branchVoltage(voltage: 6, resistor: 4, other: 12, parallel: false)
                           + Circuit.branchVoltage(voltage: 6, resistor: 12, other: 4, parallel: false), 6))

        typealias Light = RefractionModel
        // Lesson quiz: in water (n = 1.333) light travels at about 2.25 · 10⁸ m/s; in diamond about 1.24 · 10⁸ m/s.
        precondition(close(Light.speed(in: Light.water) / 1e8, 2.25, 5e-3) && close(Light.speed(in: Light.diamond) / 1e8, 1.24, 5e-3))
        // Practice task: air → glass at 30° gives sin θ₂ ≈ 0.329 and θ₂ ≈ 19.2°, toward the perpendicular.
        let angle = Light.refractionAngle(incidence: 30, from: Light.air, to: Light.glass)!
        precondition(close(sin(angle * .pi / 180), 0.5 / 1.52) && close(angle, 19.2, 0.05) && angle < 30)
        // Glass → air beyond about 41.1° is totally internally reflected.
        precondition(close(Light.criticalAngle(from: Light.glass, to: Light.air)!, 41.1, 0.05))
        precondition(Light.refractionAngle(incidence: 50, from: Light.glass, to: Light.air) == nil)
        precondition(Light.criticalAngle(from: Light.air, to: Light.glass) == nil)
        precondition(close(Light.refractionAngle(incidence: 0, from: Light.air, to: Light.diamond)!, 0))

        typealias Seesaw = SeesawModel
        // Lesson quiz: a 30 kg child at 2 m balances a 40 kg child at 1.5 m.
        precondition(close(Seesaw.balancingDistance(mass: 30, distance: 2, otherMass: 40), 1.5))
        precondition(close(Seesaw.netTorque(leftMass: 30, leftDistance: 2, rightMass: 40, rightDistance: 1.5), 0))
        precondition(Seesaw.netTorque(leftMass: 30, leftDistance: 2, rightMass: 40, rightDistance: 2) > 0)
        // Practice task: 20 N at 0.8 m is 16 N·m; the same torque at 0.2 m needs 80 N.
        precondition(close(20 * 0.8, 16) && close(16 / 0.2, 80))
        print("Circuit, refraction, and seesaw lab models verified")
    }
}
