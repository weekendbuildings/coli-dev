import Foundation

@main
enum LeastSquaresFitVerification {
    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    static func main() {
        typealias Model = LeastSquaresFitModel
        // Lesson program: slope 4.053 s²/m, intercept -0.012 s², g 9.74 m/s².
        let best = Model.bestFit()
        precondition(close(best.slope, 4.053, 5e-4) && close(best.intercept, -0.012, 5e-4))
        precondition(close(Model.gravity(slope: best.slope), 9.74, 5e-3))
        // Quiz: a slope of 4.00 s²/m gives g = π².
        precondition(close(Model.gravity(slope: 4), Double.pi * Double.pi))
        // Practice task: the same offset in every length leaves the slope unchanged and moves the intercept.
        let shifted = Model.bestFit(lengthOffset: 0.02)
        precondition(close(shifted.slope, best.slope))
        precondition(close(shifted.intercept, best.intercept - best.slope * 0.02))
        precondition(close(Model.sumOfSquaredErrors(shifted, lengthOffset: 0.02), Model.sumOfSquaredErrors(best)))
        // The best line has the smallest SSE: every nearby line on a grid does worse.
        let bestError = Model.sumOfSquaredErrors(best)
        for slopeStep in -5...5 {
            for interceptStep in -5...5 where slopeStep != 0 || interceptStep != 0 {
                let other = Model.Line(intercept: best.intercept + Double(interceptStep) * 0.01,
                                       slope: best.slope + Double(slopeStep) * 0.01)
                precondition(Model.sumOfSquaredErrors(other) > bestError, "a nearby line beat the least-squares line")
            }
        }
        // The best line is reachable with the lab's sliders for every offset.
        for offset in stride(from: Model.offsetRange.lowerBound, through: Model.offsetRange.upperBound, by: 0.01) {
            let line = Model.bestFit(lengthOffset: offset)
            precondition(Model.slopeRange.contains(line.slope) && Model.interceptRange.contains(line.intercept))
        }
        precondition(Model.points().map(\.y) == Model.periods.map { $0 * $0 })
        print("Least-squares lab model verified: slope \(best.slope), intercept \(best.intercept), SSE \(bestError)")
    }
}
