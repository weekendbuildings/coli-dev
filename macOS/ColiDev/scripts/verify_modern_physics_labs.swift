import Foundation

@main
enum ModernPhysicsLabsVerification {
    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    static func main() {
        typealias Relativity = RelativityModel
        // Lesson quiz: at 0.6c, γ = 1.25 and 10 s of ship time is 12.5 s on Earth.
        precondition(close(Relativity.gamma(speed: 0.6), 1.25) && close(Relativity.dilatedTime(properTime: 10, speed: 0.6), 12.5))
        // Muon: at 0.950c, γ ≈ 3.20 and 1.52 µs stretches to about 4.87 µs.
        precondition(close(Relativity.gamma(speed: 0.95), 3.20, 5e-3))
        precondition(close(Relativity.dilatedTime(properTime: Relativity.muonHalfLife, speed: 0.95), 4.87, 5e-3))
        // At rest nothing changes; γ grows without bound as v approaches c.
        precondition(close(Relativity.gamma(speed: 0), 1) && Relativity.gamma(speed: 0.99) > 7)
        // Practice task: clocks run half as fast (γ = 2) at v = √3/2 · c ≈ 0.866c.
        precondition(close(Relativity.gamma(speed: 3.0.squareRoot() / 2), 2))

        typealias Hydrogen = HydrogenSpectrumModel
        // Lesson quiz: 3 → 2 gives ΔE ≈ 1.89 eV and λ ≈ 656 nm.
        precondition(close(Hydrogen.photonEnergy(from: 3, to: 2), 1.89, 5e-3))
        precondition(Int(Hydrogen.wavelength(from: 3, to: 2).rounded()) == 656)
        // Practice task: 4 → 2 is bluer (shorter) than 3 → 2; levels −13.6, −3.4, −1.51, −0.85 eV.
        precondition(Hydrogen.wavelength(from: 4, to: 2) < Hydrogen.wavelength(from: 3, to: 2))
        precondition(Int(Hydrogen.wavelength(from: 4, to: 2).rounded()) == 486)
        precondition(close(Hydrogen.energy(level: 1), -13.6) && close(Hydrogen.energy(level: 2), -3.4) && close(Hydrogen.energy(level: 4), -0.85))
        // Wrong answers from the quiz: 13.6 / 4 eV gives about 365 nm, 13.6 eV about 91 nm.
        precondition(Int((1240 / 3.4).rounded()) == 365 && Int((1240 / 13.6).rounded()) == 91)
        // Shells hold 2, 8, 18, 32 electrons.
        precondition((1...4).map(Hydrogen.shellCapacity) == [2, 8, 18, 32])
        // Transitions to n = 1 are ultraviolet, to n = 3 infrared; 3 → 2 is visible.
        precondition(Hydrogen.wavelength(from: 2, to: 1) < Hydrogen.visibleRange.lowerBound)
        precondition(Hydrogen.wavelength(from: 4, to: 3) > Hydrogen.visibleRange.upperBound)
        precondition(Hydrogen.visibleRange.contains(Hydrogen.wavelength(from: 3, to: 2)))

        typealias Wave = ElectromagneticWaveModel
        // Lesson quiz: 100 MHz has λ = 3.00 m; practice: green light of 500 nm has f = 6.00 · 10¹⁴ Hz.
        precondition(close(Wave.wavelength(frequency: Wave.radioFrequency), 3))
        precondition(close(Wave.frequency(wavelength: Wave.greenWavelength) / 1e14, 6, 1e-9))
        // The light's frequency is 6 million times the radio's.
        precondition(close(Wave.frequency(wavelength: Wave.greenWavelength) / Wave.radioFrequency, 6e6, 1e-3))
        print("Relativity, hydrogen spectrum, and electromagnetic wave lab models verified")
    }
}
