import Foundation

/// Logistic growth for the zoology lesson (OpenStax Biology 2e, 45.3): dN/dt = rmax · N · (K − N) / K.
enum LogisticGrowthModel {
    static let rateRange = 0.05...0.5
    static let capacityRange = 100.0...2000.0

    static func growth(population: Double, rate: Double, capacity: Double) -> Double {
        rate * population * (capacity - population) / capacity
    }

    static func exponentialGrowth(population: Double, rate: Double) -> Double { rate * population }

    /// The logistic increase is largest at half the carrying capacity.
    static func fastestPopulation(capacity: Double) -> Double { capacity / 2 }
}

/// Mark and recapture for the zoology lesson (OpenStax Biology 2e, 45.1): N = marked · caught / recaptured.
enum MarkRecaptureModel {
    static let countRange = 1...300

    static func estimate(marked: Int, caught: Int, recaptured: Int) -> Double? {
        guard recaptured > 0, recaptured <= caught, recaptured <= marked else { return nil }
        return Double(marked * caught) / Double(recaptured)
    }
}

/// Surface-to-volume ratio for the zoology lesson on body size (OpenStax Biology 2e, 33.1):
/// a sphere has 3/r, a cube 6/a, so the ratio falls as size grows.
enum SurfaceVolumeModel {
    static let sizeRange = 1.0...10.0

    static func sphere(radius: Double) -> (surface: Double, volume: Double) {
        (4 * .pi * radius * radius, 4.0 / 3.0 * .pi * radius * radius * radius)
    }

    static func cube(side: Double) -> (surface: Double, volume: Double) { (6 * side * side, side * side * side) }

    static func ratio(size: Double, sphere isSphere: Bool) -> Double {
        let shape = isSphere ? sphere(radius: size) : cube(side: size)
        return shape.surface / shape.volume
    }
}
