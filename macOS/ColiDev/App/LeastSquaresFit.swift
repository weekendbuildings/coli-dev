import Foundation

/// Least-squares line through pendulum data for the physics lesson "Experiment and Computation"
/// (OpenStax College Physics 2e, 16.4; Introductory Statistics 2e, 12.3). T² = (4π²/g)·L, so the points (L, T²)
/// lie on a line whose slope gives g = 4π²/slope; the best line is the one with the smallest sum of squared errors.
enum LeastSquaresFitModel {
    /// The lesson's measurements: lengths in metres and stopwatch periods in seconds.
    static let lengths: [Double] = [0.25, 0.50, 0.75, 1.00]
    static let periods: [Double] = [1.00, 1.42, 1.74, 2.01]

    static let slopeRange = 2.0...6.0          // s²/m
    static let interceptRange = -0.5...0.5     // s²
    static let offsetRange = 0.0...0.05        // m, the same systematic error added to every length

    struct Line: Equatable {
        var intercept: Double
        var slope: Double

        func value(at x: Double) -> Double { intercept + slope * x }
    }

    struct Point: Equatable {
        var x: Double
        var y: Double
    }

    static func points(lengthOffset: Double = 0) -> [Point] {
        zip(lengths, periods).map { Point(x: $0 + lengthOffset, y: $1 * $1) }
    }

    static func sumOfSquaredErrors(_ line: Line, lengthOffset: Double = 0) -> Double {
        points(lengthOffset: lengthOffset).reduce(0) { sum, point in
            let residual = point.y - line.value(at: point.x)
            return sum + residual * residual
        }
    }

    static func bestFit(lengthOffset: Double = 0) -> Line {
        let data = points(lengthOffset: lengthOffset)
        let count = Double(data.count)
        let meanX = data.reduce(0) { $0 + $1.x } / count
        let meanY = data.reduce(0) { $0 + $1.y } / count
        let covariance = data.reduce(0) { $0 + ($1.x - meanX) * ($1.y - meanY) }
        let spread = data.reduce(0) { $0 + ($1.x - meanX) * ($1.x - meanX) }
        let slope = covariance / spread
        return Line(intercept: meanY - slope * meanX, slope: slope)
    }

    static func gravity(slope: Double) -> Double { 4 * Double.pi * Double.pi / slope }
}
