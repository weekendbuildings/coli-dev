import Foundation

/// A town of people and a test. The counts are exact expected values, rounded to whole people for the picture, and the
/// probabilities are the true ones from Bayes' rule. / Город людей и тест. Вероятности настоящие, из формулы Байеса.
struct BayesTownModel: Equatable {
    static let population = 1000
    static let columns = 40
    static let rows = 25
    /// The task: at a rate of 1 %, reach at least this chance of disease after one positive test.
    static let challengeRate = 0.01
    static let challengeChance = 0.5

    var diseaseRate = 0.01
    var hitRate = 0.99
    var falseAlarmRate = 0.05
    var secondTest = false

    /// P(sick | one positive test), by Bayes' rule. / P(болен | один положительный тест), по формуле Байеса.
    static func bayes(prior: Double, hit: Double, falseAlarm: Double) -> Double {
        let top = prior * hit
        let total = top + (1 - prior) * falseAlarm
        return total > 0 ? top / total : 0
    }

    var chanceAfterOneTest: Double { Self.bayes(prior: diseaseRate, hit: hitRate, falseAlarm: falseAlarmRate) }
    var chanceAfterTwoTests: Double { Self.bayes(prior: chanceAfterOneTest, hit: hitRate, falseAlarm: falseAlarmRate) }
    var chance: Double { secondTest ? chanceAfterTwoTests : chanceAfterOneTest }

    var sickCount: Int { Int((Double(Self.population) * diseaseRate).rounded()) }
    var healthyCount: Int { Self.population - sickCount }

    /// Positive people among the sick and healthy, after one or both tests.
    var positiveSick: Int {
        let share = secondTest ? hitRate * hitRate : hitRate
        return Int((Double(sickCount) * share).rounded())
    }

    var positiveHealthy: Int {
        let share = secondTest ? falseAlarmRate * falseAlarmRate : falseAlarmRate
        return Int((Double(healthyCount) * share).rounded())
    }

    /// Who is who in the grid. The order is a fixed shuffle, so that the sick do not stand in one block, and the same
    /// people stay in place when a slider moves. / Порядок постоянный: больные не стоят кучей, и люди не меняются местами.
    static let order: [Int] = {
        var indices = Array(0..<population)
        var state = 20261102
        var i = population - 1
        while i > 0 {
            state = state * 16807 % 2147483647
            let j = Int(Double(state) / 2147483647 * Double(i + 1))
            indices.swapAt(i, j)
            i -= 1
        }
        return indices
    }()

    /// A person's role: the first ones in the shuffled order are sick, and within each group the first ones test positive.
    func person(at cell: Int) -> (sick: Bool, positive: Bool) {
        let rank = Self.order[cell]
        if rank < sickCount { return (true, rank < positiveSick) }
        return (false, rank - sickCount < positiveHealthy)
    }

    var solvesChallenge: Bool {
        diseaseRate <= Self.challengeRate + 1e-9 && !secondTest && chanceAfterOneTest >= Self.challengeChance
    }
}
