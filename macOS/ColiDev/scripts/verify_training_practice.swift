import Foundation

@main
enum TrainingPracticeVerification {
    static func reads(batch: Int, rate: Double) -> Int {
        var model = MinibatchLineModel()
        while model.readsAtTarget == nil && !model.isFinished { model.step(batch: batch, rate: rate) }
        return model.readsAtTarget ?? Int.max
    }

    static func rounded(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }

    static func main() {
        // The numbers of the lesson's program. / Числа программы урока.
        precondition(reads(batch: 1, rate: 0.1) == 19 && reads(batch: 1, rate: 0.2) == 27, "batch 1")
        precondition(reads(batch: 4, rate: 0.1) == 88 && reads(batch: 4, rate: 0.2) == 44, "batch 4")
        precondition(reads(batch: 24, rate: 0.1) == 528 && reads(batch: 24, rate: 0.2) == 240, "batch 24")
        precondition(rounded(MinibatchLineModel.loss(w: MinibatchLineModel.best.w, b: MinibatchLineModel.best.b)) == 0.129, "the best error")

        // The true slope matches a numerical one, and the best point has zero slope.
        let h = 1e-6
        let probe = (w: 0.4, b: -0.6)
        let exact = MinibatchLineModel.slope(w: probe.w, b: probe.b)
        let dw = (MinibatchLineModel.loss(w: probe.w + h, b: probe.b) - MinibatchLineModel.loss(w: probe.w - h, b: probe.b)) / (2 * h)
        let db = (MinibatchLineModel.loss(w: probe.w, b: probe.b + h) - MinibatchLineModel.loss(w: probe.w, b: probe.b - h)) / (2 * h)
        precondition(abs(dw - exact.x) < 1e-6 && abs(db - exact.y) < 1e-6, "slope")
        let flat = MinibatchLineModel.slope(w: MinibatchLineModel.best.w, b: MinibatchLineModel.best.b)
        precondition(abs(flat.x) < 1e-9 && abs(flat.y) < 1e-9, "the bottom is flat")

        // The task: full passes never reach the target in one pass, at any rate of the slider. The opening does not solve it.
        // Полный проход не достигает цели за один проход при любой скорости ползунка, а начальное состояние задание не решает.
        let opening = MinibatchLineModel()
        precondition(!opening.solvesChallenge && opening.batchSlope == nil)
        for rate in stride(from: MinibatchLineModel.rateRange.lowerBound, through: MinibatchLineModel.rateRange.upperBound, by: 0.01) {
            precondition(reads(batch: 24, rate: rate) > MinibatchLineModel.challengeReads, "a full pass cannot solve the task")
        }
        var solved = MinibatchLineModel()
        while solved.readsAtTarget == nil { solved.step(batch: 1, rate: 0.1) }
        precondition(solved.solvesChallenge, "one point at a time solves it")
        // The batch gradient differs from the true one, and averages to it over an epoch.
        var single = MinibatchLineModel()
        single.step(batch: 1, rate: 0)
        let trueAtStart = MinibatchLineModel.slope(w: MinibatchLineModel.start.w, b: MinibatchLineModel.start.b)
        precondition(single.batchSlope != trueAtStart, "a batch of one is noisy")
        var whole = MinibatchLineModel()
        whole.step(batch: 24, rate: 0)
        precondition(abs(whole.batchSlope!.x - trueAtStart.x) < 1e-9, "a full batch is the true gradient")
        // The read limit stops training. / Предел чтений останавливает обучение.
        var long = MinibatchLineModel()
        for _ in 0..<2000 { long.step(batch: 1, rate: 0.01) }
        precondition(long.reads == MinibatchLineModel.readLimit)

        func trained(_ decay: Double) -> WaveFitModel {
            var model = WaveFitModel(decay: decay)
            while !model.isFinished { model.step() }
            return model
        }
        // Overfitting, as printed by the program. / Переобучение, как в выводе программы.
        let plain = trained(0)
        precondition(rounded(plain.trainError) == 0.005 && rounded(plain.heldError) == 0.427, "no decay")
        precondition(rounded(plain.bestHeld.error) == 0.316 && plain.bestHeld.step == 31, "the best moment, no decay")
        let decayed = trained(0.1)
        precondition(rounded(decayed.trainError) == 0.074 && rounded(decayed.heldError) == 0.338, "decay 0.1")
        precondition(rounded(decayed.bestHeld.error) == 0.323 && decayed.bestHeld.step == 41, "the best moment, decay 0.1")

        // The task: no decay fails, a good one passes, and too much decay fails too.
        // Без ослабления задание не решить, при хорошем значении можно, при слишком большом снова нельзя.
        precondition(!plain.solvesChallenge, "no decay does not solve the task")
        precondition(decayed.solvesChallenge, "decay 0.1 solves it")
        precondition(!trained(0.01).solvesChallenge && !trained(1).solvesChallenge, "the good decay is a real choice")
        precondition(!WaveFitModel().solvesChallenge, "the opening does not solve it")

        // The curves diverge without decay. / Без ослабления кривые расходятся.
        precondition(plain.trainHistory.last! < plain.trainHistory[31] && plain.heldHistory.last! > plain.heldHistory[31], "divergence")

        print("Training practice verification passed.")
    }
}
