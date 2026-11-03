import Foundation

/// The labs compute the same numbers as the lessons' programs. / Тренажёры считают те же числа, что программы уроков.
@main
enum Stage4LabsVerification {
    private static func close(_ value: Double, _ expected: Double, _ tolerance: Double = 1e-6) -> Bool {
        abs(value - expected) <= tolerance
    }

    static func main() {
        let table = IntelligenceModel.table(steps: 100)
        precondition(close(table[2][0], 0.8549999999999999) && close(table[1][0], 0.9006666666666666) && close(table[0][7], 0.49966666666666676), "\(table)")
        precondition(close(IntelligenceModel.leggHutter(table[2]), 0.6209427083333333), "Legg and Hutter")
        precondition(IntelligenceModel.score(table[1], simplicity: 1) < IntelligenceModel.score(table[2], simplicity: 1), "The learner wins by the weighted score. / Ученик выигрывает по взвешенной сумме.")

        precondition(DynaModel.run(plans: 5, games: 50, seed: 500) == [165, 55, 10, 25, 10, 9, 11, 9, 9, 9, 9, 10, 9, 9, 10, 10, 10, 12, 13, 9, 11, 9, 9, 12, 9, 10, 9, 18, 9, 9, 10, 11, 10, 9, 12, 9, 11, 9, 9, 9, 9, 9, 13, 10, 9, 9, 9, 11, 12, 9], "Five plans. / Пять шагов.")
        precondition(DynaModel.run(plans: 50, games: 50, seed: 503) == [261, 29, 15, 13, 12, 15, 11, 11, 9, 9, 10, 11, 10, 11, 10, 9, 11, 13, 11, 11, 11, 10, 9, 11, 11, 12, 10, 13, 9, 9, 12, 9, 9, 11, 9, 9, 11, 9, 12, 17, 9, 9, 9, 9, 9, 9, 9, 9, 11, 10], "Fifty plans. / Пятьдесят шагов.")
        precondition(DynaModel.run(plans: 50, games: 60, seed: 700, moveAt: 30) == [300, 90, 16, 10, 9, 11, 12, 11, 9, 9, 9, 11, 11, 9, 9, 9, 11, 11, 9, 11, 9, 10, 9, 9, 21, 11, 10, 11, 9, 11, 10, 11, 9, 11, 14, 9, 11, 11, 15, 9, 14, 11, 9, 11, 9, 11, 9, 9, 12, 14, 9, 10, 9, 11, 9, 9, 9, 9, 9, 9], "A moved wall. / Переезд стены.")

        var net = ReplayNet(seed: 11)
        var rand = RLRand(12)
        let trainA = ReplayNet.points(side: -1, count: 200, seed: 1)
        let trainB = ReplayNet.points(side: 1, count: 200, seed: 2)
        let checkA = ReplayNet.points(side: -1, count: 300, seed: 3)
        let checkB = ReplayNet.points(side: 1, count: 300, seed: 4)
        net.train(trainA, steps: 12000, rand: &rand)
        precondition(close(net.accuracy(checkA), 1.0, 0.0006), "\(net.accuracy(checkA))")
        var forgetful = net
        var source = RLRand(13)
        forgetful.train(trainB, steps: 8000, rand: &source)
        precondition(close(forgetful.accuracy(checkA), 0.003, 0.0006), "\(forgetful.accuracy(checkA))")
        var helped = net
        source = RLRand(13)
        helped.train(trainB, steps: 8000, rand: &source, replay: Array(trainA.prefix(20)), share: 0.5)
        precondition(close(helped.accuracy(checkA), 0.853, 0.0006), "\(helped.accuracy(checkA))")
        var enough = net
        source = RLRand(13)
        enough.train(trainB, steps: 8000, rand: &source, replay: Array(trainA.prefix(100)), share: 0.5)
        precondition(enough.accuracy(checkA) >= 0.9 && enough.accuracy(checkB) >= 0.9, "The lab's task can be solved. / Задачу тренажёра можно решить.")

        let fit = ScalingFit.fit(Array(ScalingRecording.sizes.prefix(4)), Array(ScalingRecording.errors.prefix(4)))
        precondition(close(fit.slope, -0.30500085752919953, 0.001) && close(fit.scale, 8.88092485093058, 0.01), "\(fit)")
        precondition(ArcRecording.tasks.count == 10 && ArcRecording.tasks.filter(\.search).count == 9 && ArcRecording.tasks.filter(\.coderRight).count == 4 && ArcRecording.tasks.filter(\.qwenRight).count == 4, "Results. / Итоги.")
        print("Stage 4 labs verified. / Тренажёры этапа 4 проверены.")
    }
}
