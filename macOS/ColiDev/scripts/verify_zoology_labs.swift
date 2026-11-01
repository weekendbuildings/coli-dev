import Foundation

@main
enum ZoologyLabsVerification {
    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    static func main() {
        typealias Logistic = LogisticGrowthModel
        // Lesson quiz: rmax 0.1, K 1000, N 500 gives 25 per unit time; exponential growth would give 50.
        precondition(close(Logistic.growth(population: 500, rate: 0.1, capacity: 1000), 25))
        precondition(close(Logistic.exponentialGrowth(population: 500, rate: 0.1), 50))
        // Practice task: N = 100, 500, 900 give 9, 25, 9; at N = K growth stops.
        precondition(close(Logistic.growth(population: 100, rate: 0.1, capacity: 1000), 9) && close(Logistic.growth(population: 900, rate: 0.1, capacity: 1000), 9))
        precondition(close(Logistic.growth(population: 1000, rate: 0.1, capacity: 1000), 0))
        precondition(close(Logistic.fastestPopulation(capacity: 1000), 500))
        for population in stride(from: 0.0, through: 1000, by: 10) where population != 500 {
            precondition(Logistic.growth(population: population, rate: 0.1, capacity: 1000) < 25)
        }

        typealias Recapture = MarkRecaptureModel
        // Lesson: 80 · 100 / 20 = 400 deer; quiz: 50 · 60 / 15 = 200 lizards; practice: 120 · 90 / 30 = 360 fish.
        precondition(Recapture.estimate(marked: 80, caught: 100, recaptured: 20) == 400)
        precondition(Recapture.estimate(marked: 50, caught: 60, recaptured: 15) == 200)
        precondition(Recapture.estimate(marked: 120, caught: 90, recaptured: 30) == 360)
        // Trap-shy marked fish (15 instead of 30) double the estimate: it overshoots the true population.
        precondition(Recapture.estimate(marked: 120, caught: 90, recaptured: 15) == 720)
        precondition(Recapture.estimate(marked: 50, caught: 60, recaptured: 0) == nil && Recapture.estimate(marked: 50, caught: 60, recaptured: 61) == nil)

        typealias Shape = SurfaceVolumeModel
        // Lesson: a sphere's ratio is 3/r, so doubling r halves it.
        precondition(close(Shape.ratio(size: 1, sphere: true), 3) && close(Shape.ratio(size: 2, sphere: true), 1.5))
        // Practice task: cubes of 1, 2, and 4 cm have ratios 6, 3, and 1.5.
        precondition([1.0, 2, 4].map { Shape.ratio(size: $0, sphere: false) } == [6, 3, 1.5])
        precondition(close(Shape.sphere(radius: 2).surface / Shape.sphere(radius: 1).surface, 4) && close(Shape.sphere(radius: 2).volume / Shape.sphere(radius: 1).volume, 8))
        print("Logistic growth, mark-recapture, and surface-to-volume lab models verified")
    }
}
