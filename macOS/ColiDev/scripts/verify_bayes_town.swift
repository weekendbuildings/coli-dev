import Foundation

@main
enum BayesTownVerification {
    typealias Model = BayesTownModel

    static func rounded(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }

    static func main() {
        // The numbers of the lesson. / Числа урока.
        var model = Model()
        precondition(rounded(model.chanceAfterOneTest) == 0.167, "one test")
        precondition(rounded(model.chanceAfterTwoTests) == 0.798, "two tests")
        precondition(rounded(Model.bayes(prior: 0.01, hit: 0.99, falseAlarm: 0.01)) == 0.5, "fewer false alarms")

        // The town agrees with the formula, as far as whole cubes allow.
        precondition(Model.columns * Model.rows == Model.population)
        precondition(model.sickCount == 10 && model.positiveSick == 10 && model.positiveHealthy == 50)
        let picture = Double(model.positiveSick) / Double(model.positiveSick + model.positiveHealthy)
        precondition(abs(picture - model.chance) < 0.01, "the raised cubes show the true chance")

        // Each cube's role matches the counts. / Роль каждого кубика совпадает со счётом.
        func count(_ model: Model) -> (sick: Int, sickUp: Int, healthyUp: Int) {
            var result = (sick: 0, sickUp: 0, healthyUp: 0)
            for cell in 0..<Model.population {
                let person = model.person(at: cell)
                if person.sick { result.sick += 1 }
                if person.sick && person.positive { result.sickUp += 1 }
                if !person.sick && person.positive { result.healthyUp += 1 }
            }
            return result
        }
        let counted = count(model)
        precondition(counted.sick == 10 && counted.sickUp == 10 && counted.healthyUp == 50, "the grid holds the counts")
        precondition(Set(Model.order).count == Model.population, "the order is a true shuffle")

        // A second test keeps only those positive twice. / Второй тест оставляет только дважды положительных.
        model.secondTest = true
        let twice = count(model)
        precondition(twice.sickUp == 10 && twice.healthyUp == 2 || twice.healthyUp == 3, "the second test")
        model.secondTest = false

        // The task: the opening does not solve it, fewer false alarms do, and a common disease earns no credit.
        // Начальное состояние задание не решает, меньше ложных тревог решает, а частая болезнь не засчитывается.
        precondition(!model.solvesChallenge)
        model.falseAlarmRate = 0.01
        precondition(model.solvesChallenge, "one percent of false alarms solves it")
        var common = Model()
        common.diseaseRate = 0.2
        precondition(common.chanceAfterOneTest >= Model.challengeChance && !common.solvesChallenge, "a common disease is not the task")
        var twoTests = Model()
        twoTests.secondTest = true
        precondition(twoTests.chance >= Model.challengeChance && !twoTests.solvesChallenge, "the task is about one test")

        // The edges of the sliders stay finite. / Края ползунков дают конечные числа.
        precondition(Model.bayes(prior: 0, hit: 0.5, falseAlarm: 0) == 0)
        precondition(Model.bayes(prior: 1, hit: 0.5, falseAlarm: 0.5) == 1)

        print("Bayes town verification passed.")
    }
}
