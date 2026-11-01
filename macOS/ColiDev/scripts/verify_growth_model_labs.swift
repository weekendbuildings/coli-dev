import Foundation

@main
enum GrowthModelLabsVerification {
    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    static func main() {
        typealias Euler = EulerMethodModel
        // Lesson quiz: two steps with h = 1 give 110 and then 121.
        let quiz = Euler.eulerPoints(stepSize: 1, endTime: 2)
        precondition(quiz.count == 3 && close(quiz[1].value, 110) && close(quiz[2].value, 121))
        // Practice task: four steps with h = 0.5 give 100 · 1.05⁴, and the exact value is 100 · e^0.2 ≈ 122.14.
        precondition(close(Euler.eulerValue(stepSize: 0.5, endTime: 2), 121.550625))
        precondition(close(Euler.exactValue(at: 2), 122.14, 5e-3))
        // Twenty steps with h = 0.1 give 100 · 1.01²⁰.
        precondition(Euler.stepCount(stepSize: 0.1, endTime: 2) == 20)
        precondition(close(Euler.eulerValue(stepSize: 0.1, endTime: 2), 100 * pow(1.01, 20)))
        // A smaller step is always closer to the exact solution, and Euler stays below it for this growth law.
        for endTime in Euler.endTimeRange {
            let errors = Euler.stepSizes.map { Euler.exactValue(at: Double(endTime)) - Euler.eulerValue(stepSize: $0, endTime: endTime) }
            precondition(errors.allSatisfy { $0 > 0 })
            precondition(zip(errors, errors.dropFirst()).allSatisfy { $0 > $1 }, "error must shrink with the step at t = \(endTime)")
            for stepSize in Euler.stepSizes {
                precondition(close(Euler.eulerPoints(stepSize: stepSize, endTime: endTime).last!.t, Double(endTime), 1e-9))
            }
        }

        typealias Auto = AutocatalysisModel
        // Lesson quiz: one molecule doubling for 10 hours gives 2¹⁰ = 1024; the catalyst gives 11.
        precondition(Auto.autocatalytic(hours: 10) == 1024 && Auto.catalysed(hours: 10) == 11)
        // Both start equal, are still equal after the first hour, and doubling leads from the second hour on.
        precondition(Auto.autocatalytic(hours: 0) == Auto.catalysed(hours: 0))
        precondition(Auto.autocatalytic(hours: 1) == Auto.catalysed(hours: 1))
        precondition(Auto.overtakingHour == 2)
        precondition(Auto.autocatalytic(hours: 20) == 1_048_576)
        print("Euler method and autocatalysis lab models verified")
    }
}
