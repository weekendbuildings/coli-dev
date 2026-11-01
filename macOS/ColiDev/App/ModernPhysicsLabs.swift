import Foundation

/// Time dilation for the physics lesson on special relativity (OpenStax College Physics 2e, 28.2):
/// Δt = γΔt₀ with γ = 1 / √(1 − v²/c²).
enum RelativityModel {
    static let speedRange = 0.0...0.99          // v / c
    static let properTimeRange = 1.0...100.0    // s
    static let muonHalfLife = 1.52              // µs at rest

    static func gamma(speed: Double) -> Double { 1 / (1 - speed * speed).squareRoot() }

    static func dilatedTime(properTime: Double, speed: Double) -> Double { gamma(speed: speed) * properTime }
}

/// Hydrogen lines for the physics lesson on quantum energy levels (OpenStax College Physics 2e, 30.3):
/// Eₙ = −13.6 eV / n², a transition emits ΔE, and λ (nm) = 1240 / ΔE (eV); a shell n holds 2n² electrons.
enum HydrogenSpectrumModel {
    static let levelRange = 1...6
    /// Roughly the wavelengths the eye can see, used only to colour the line.
    static let visibleRange = 380.0...760.0

    static func energy(level: Int) -> Double { -13.6 / Double(level * level) }

    static func photonEnergy(from upper: Int, to lower: Int) -> Double { energy(level: upper) - energy(level: lower) }

    static func wavelength(from upper: Int, to lower: Int) -> Double { 1240 / photonEnergy(from: upper, to: lower) }

    static func shellCapacity(level: Int) -> Int { 2 * level * level }
}

/// c = fλ for the physics lesson on Maxwell's equations (OpenStax College Physics 2e, 24.1–24.3).
enum ElectromagneticWaveModel {
    static let speedOfLight = 3.00e8                 // m/s
    static let exponentRange = 6.0...18.0            // log₁₀ of the frequency in Hz
    static let radioFrequency = 1.00e8               // a 100 MHz station
    static let greenWavelength = 500e-9              // m

    static func wavelength(frequency: Double) -> Double { speedOfLight / frequency }

    static func frequency(wavelength: Double) -> Double { speedOfLight / wavelength }
}
