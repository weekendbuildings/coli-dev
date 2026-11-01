import Foundation

@main
enum RegulationLabsVerification {
    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-6) -> Bool { abs(a - b) < tolerance }

    static func main() {
        typealias Dating = RadioactiveDatingModel
        let carbon = Dating.carbon14
        // Lesson quiz: 25% of carbon-14 left means two half-lives, about 11 460 years.
        precondition(close(Dating.age(remainingPercent: 25, isotope: carbon), 11_460))
        precondition(close(Dating.halfLives(remainingPercent: 25), 2) && close(Dating.age(remainingPercent: 100, isotope: carbon), 0))
        // Practice task: after 5730, 11 460, and 17 190 years, 1/2, 1/4, and 1/8 remain.
        precondition(close(Dating.remainingShare(after: 5730, isotope: carbon), 0.5))
        precondition(close(Dating.remainingShare(after: 11_460, isotope: carbon), 0.25))
        precondition(close(Dating.remainingShare(after: 17_190, isotope: carbon), 0.125))
        // A 3-billion-year-old rock is over half a million carbon-14 half-lives: nothing measurable is left.
        precondition(Int(Dating.halfLivesElapsed(years: 3e9, isotope: carbon)) == 523_560)
        precondition(Dating.remainingShare(after: 3e9, isotope: carbon) == 0)
        // Uranium-238: half remains after 4.5 billion years.
        precondition(close(Dating.age(remainingPercent: 50, isotope: Dating.uranium238) / 1e9, 4.5))

        typealias Loop = FeedbackLoopModel
        // Negative feedback shrinks the deviation every step; positive feedback grows it every step.
        let negative = Loop.temperatures(initial: 2, gain: 0.3, negative: true)
        let positive = Loop.temperatures(initial: 2, gain: 0.3, negative: false)
        precondition(close(negative[0], 39) && close(positive[0], 39))
        precondition(zip(negative, negative.dropFirst()).allSatisfy { abs($1 - Loop.setPoint) < abs($0 - Loop.setPoint) })
        precondition(zip(positive, positive.dropFirst()).allSatisfy { abs($1 - Loop.setPoint) > abs($0 - Loop.setPoint) })
        precondition(close(Loop.deviation(after: 1, initial: 2, gain: 0.3, negative: true), 1.4))
        precondition(abs(negative.last! - Loop.setPoint) < 0.01)
        // Cooling below the set point is corrected the same way, from the other side.
        precondition(Loop.temperatures(initial: -2, gain: 0.3, negative: true).allSatisfy { $0 <= Loop.setPoint })
        print("Radioactive dating and feedback loop lab models verified")
    }
}
