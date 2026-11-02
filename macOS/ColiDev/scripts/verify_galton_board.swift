import Foundation

@main
enum GaltonBoardVerification {
    typealias Model = GaltonBoardModel

    static func main() {
        // Exact probabilities sum to one, and their mean and variance match np and np(1 − p).
        for (rows, chance) in [(4, 0.5), (12, 0.75), (14, 0.2)] {
            let model = Model(rows: rows, rightChance: chance)
            let probabilities = (0...rows).map { model.theoryChance(bin: $0) }
            precondition(abs(probabilities.reduce(0, +) - 1) < 1e-9, "the probabilities sum to one")
            let mean = probabilities.enumerated().map { Double($0.offset) * $0.element }.reduce(0, +)
            let variance = probabilities.enumerated().map { pow(Double($0.offset) - mean, 2) * $0.element }.reduce(0, +)
            precondition(abs(mean - model.theoryMean) < 1e-9, "mean")
            precondition(abs(variance - model.theoryVariance) < 1e-9, "variance")
        }

        // Many balls land near the theory, and more balls land nearer. / Много шариков ложатся около теории, больше шариков ещё ближе.
        var many = Model(rows: 12, rightChance: 0.75)
        for _ in 0..<40000 { many.drop() }
        precondition(abs(many.sampleMean - 9) < 0.03, "the law of large numbers, mean")
        precondition(abs(many.sampleVariance - 2.25) < 0.08, "the law of large numbers, variance")
        for bin in 0...12 {
            let observed = Double(many.bins[bin]) / 40000
            precondition(abs(observed - many.theoryChance(bin: bin)) < 0.01, "the bins follow the binomial law")
        }

        // Each drop makes one choice per row and adds one ball.
        var one = Model(rows: 6, rightChance: 0.5)
        let path = one.drop()
        precondition(path.count == 6 && one.balls == 1 && one.bins[path.filter { $0 }.count] == 1)

        // The opening does not solve the task. p = 0.5 cannot, and p = 0.75 can. / При p = 0,5 задание не решить, при p = 0,75 можно.
        var opening = Model()
        precondition(opening.rows == 12 && opening.rightChance == 0.5 && !opening.solvesChallenge)
        for _ in 0..<500 { opening.drop() }
        precondition(!opening.solvesChallenge, "the middle of the board is not the task")
        var right = Model(rows: 12, rightChance: 0.75)
        for _ in 0..<(Model.challengeBalls - 1) { right.drop() }
        precondition(!right.solvesChallenge, "too few balls earn nothing")
        for _ in 0..<50 { right.drop() }
        precondition(right.solvesChallenge, "p = 0.75 solves it")

        // Changing the board empties it. / Смена доски её опустошает.
        right.configure(rows: 8, rightChance: 0.3)
        precondition(right.balls == 0 && right.bins.count == 9)

        print("Galton board verification passed.")
    }
}
