import Foundation

// Checks the models of the importance B and C lessons against the numbers printed in the lessons.
// Проверяет модели уроков важности B и C по числам, которые напечатаны в уроках.

@main
struct VerifyLessonsFinalLabs {
    static func check(_ condition: Bool, _ message: String) {
        if !condition {
            FileHandle.standardError.write(Data(("FAIL: " + message + "\n").utf8))
            exit(1)
        }
    }

    static func near(_ a: Double, _ b: Double, _ tolerance: Double = 0.0005) -> Bool { abs(a - b) <= tolerance }

    static func bigram() {
        check(BigramCounter.letters.count == 28, "alphabet should have 28 letters, got \(BigramCounter.letters.count)")
        check(BigramCounter.rowTotal("м") == 18, "«м» should be followed 18 times")
        let after = BigramCounter.probabilities(after: "м", temperature: 1)
        check(after.first?.0 == "а" && near(after.first?.1 ?? 0, 0.556), "P(а | м) should be 0.556")
        check(BigramCounter.generate(temperature: 0.3) == "мала книла ма па па сыл кот па книл л книгу. ч", "T = 0.3 text differs from the lesson")
        check(BigramCounter.generate(temperature: 1.0) == "мапёс кнечиде. кнокнутал сыла па кота а л коть", "T = 1 text differs from the lesson")
        check(BigramCounter.generate(temperature: 3.0) == "мофел гу. пил па у витамапу рал гилюби. л деро", "T = 3 text differs from the lesson")
        check(near(BigramCounter.randomGuess, 3.332), "random guess should be ln 28 = 3.332")
        check(BigramCounter.loss(BigramCounter.test, alpha: 0).isInfinite, "α = 0 must give an infinite test error")
        check(near(BigramCounter.loss(BigramCounter.test, alpha: 0.01), 1.538), "test error at α = 0.01 should be 1.538")
        check(near(BigramCounter.loss(BigramCounter.train, alpha: 0), 1.371), "train error at α = 0 should be 1.371")
        check(near(BigramCounter.loss(BigramCounter.test, alpha: 3), 2.610), "test error at α = 3 should be 2.610")
        let best = BigramCounter.bestSmoothingIndex
        check(best != 0 && BigramCounter.smoothingSteps[best] <= 0.03, "the best smoothing should be small but not zero")
        check(BigramCounter.commonLetters.first == "а" || BigramCounter.commonLetters.first == " ", "common letters are sorted by count")
        print("bigram ok: best α = \(BigramCounter.smoothingSteps[best])")
    }

    static func sampling() {
        let probabilities = RealTop20.probabilities
        check(near(probabilities[0], 0.631), "P(Paris) should be 0.631")
        check(near(probabilities.reduce(0, +), 0.920, 0.001), "the 20 best should hold 0.92")
        check(RealTop20.nucleusSize(0.5) == 1 && RealTop20.nucleusSize(0.8) == 6 && RealTop20.nucleusSize(0.9) == 14, "nucleus sizes differ from the lesson")
        check(RealTop20.nucleusSize(0.95) == nil, "p = 0.95 needs more than the 20 recorded tokens")
        check(RealTop20.kept(k: 3, p: 0.99) == 3 && RealTop20.kept(k: 20, p: 0.95) == nil, "kept() combines top-k and top-p")
        let hits = RealTop20.pick(kept: 3, count: 50, seed: 1)
        check(hits.reduce(0, +) == 50 && hits[3...].allSatisfy { $0 == 0 }, "picks stay inside the kept tokens")
        check(hits[0] > hits[1] && hits[0] > hits[2], "Paris should come up most often")
        check(RealTop20.shown(0) == "␣Paris" && RealTop20.shown(2) == ":↵", "token labels")
        print("sampling ok: picks \(hits.prefix(3))")
    }

    static func dpo() {
        check(DPOToy.pairs(truthRule: false).count == 9, "the rules should label 9 pairs")
        check(DPOToy.breaks(prompt: 0, answer: 3, truthRule: false).isEmpty, "«Пять, то есть 5» breaks no rule")
        check(DPOToy.breaks(prompt: 1, answer: 1, truthRule: false) == ["polite", "on topic"], "«Семь, дурак» is rude and has no digit")
        let at50 = DPOToy.probabilities(DPOToy.train(beta: 1, steps: 50))
        check(near(at50[0][0], 0.47, 0.006) && near(at50[0][1], 0.05, 0.006), "50 steps: [0.47, 0.05, 0.01, 0.47]")
        let at300 = DPOToy.probabilities(DPOToy.train(beta: 1, steps: 300))
        check(near(at300[0][0], 0.49, 0.006) && near(at300[0][3], 0.49, 0.006), "300 steps: right and wrong split the probability")
        check(near(DPOToy.kl(at300[0]), 0.64, 0.006), "KL from start after 300 steps should be 0.64")
        let small = DPOToy.probabilities(DPOToy.train(beta: 0.1, steps: 300))
        check(near(small[1][0], 0.5, 0.006) && near(DPOToy.kl(small[1]), 0.67, 0.006), "β = 0.1 gives the same split")
        let truth = DPOToy.probabilities(DPOToy.train(beta: 1, steps: 300, truthRule: true))
        check(truth[0][3] < 0.05 && truth[1][3] < 0.05, "with the truth rule the wrong answers fall below 0.05")
        check(truth[0][0] > 0.9 && truth[1][0] > 0.9, "with the truth rule the right polite answer wins")
        print("dpo ok: truth rule gives \(truth[0].map { (($0 * 100).rounded()) / 100 })")
    }

    static func scaling() {
        check(near(ScalingLaw.loss(n: 70e9, d: 1.4e12), 1.937) && near(ScalingLaw.loss(n: 280e9, d: 300e9), 1.993), "Chinchilla 1.937, Gopher 1.993")
        let chinchilla = ScalingLaw.best(compute: 5.88e23)
        check(abs(chinchilla.n / 3.2e10 - 1) < 0.03 && (chinchilla.d / chinchilla.n).rounded() == 94, "best size at Chinchilla's budget: 3.2e10 and 94 tokens per weight")
        check((ScalingLaw.best(compute: 1e18).d / ScalingLaw.best(compute: 1e18).n).rounded() == 25, "25 tokens per weight at 1e18")
        check(abs(ScalingLaw.mySpeed / 8.7e7 - 1) < 0.01, "own speed about 8.7e7 operations per second")
        let big = 6.0 * 7e9 * 140e9
        check(abs(ScalingLaw.years(compute: big, speed: ScalingLaw.mySpeed) / 2.2e6 - 1) < 0.03, "about 2.2 million years in pure Python")
        check(ScalingLaw.years(compute: big, speed: ScalingLaw.gpuPeak).rounded() == 72, "72 years at the M1 GPU peak")
        print("scaling ok")
    }

    static func dedup() {
        check(DedupToy.quality(DedupToy.docs[2]) == .noFullStop && DedupToy.quality(DedupToy.docs[4]) == .repeats && DedupToy.quality(DedupToy.docs[6]) == .tooShort, "filter reasons")
        check(DedupToy.afterFilters == [0, 1, 3, 5, 7, 8, 9, 10, 11], "kept after filters")
        check(DedupToy.exactCopies == [3: 0] && DedupToy.unique == [0, 1, 5, 7, 8, 9, 10, 11], "exact copy [3]")
        check(near(DedupToy.jaccard(0, 9), 0.79, 0.005) && near(DedupToy.jaccard(1, 5), 0.70, 0.005) && near(DedupToy.jaccard(8, 11), 0.31, 0.005), "Jaccard 0.79, 0.70, 0.31")
        check(DedupToy.nearCopies(threshold: 0.95).isEmpty, "the starting threshold removes nothing, so the task is not solved at the start")
        check(DedupToy.nearCopies(threshold: 0.6) == [9: 0, 5: 1], "at 0.6 both near-copies go and the retelling stays")
        check(DedupToy.nearCopies(threshold: 0.3)[11] == 8, "at 0.3 the retelling goes too")
        print("dedup ok")
    }

    static func sparse() {
        check(SparseAutoencoder.data.filter { $0.0 == 0 && $0.1 == 0 }.count == 1176, "1176 empty points")
        let expected: [(Double, Double, Int, Int)] = [(0.0000, 4.00, 4, 0), (0.0002, 0.92, 3, 0), (0.0164, 0.48, 5, 0), (0.0768, 0.25, 5, 0), (0.1570, 0.00, 0, 5)]
        for (index, lambda) in SparseAutoencoder.penalties.enumerated() {
            let r = SparseAutoencoder.train(lambda: lambda)
            let e = expected[index]
            check(near(r.error, e.0, 0.00006) && near(r.activePerPoint, e.1, 0.006) && r.found == e.2 && r.dead == e.3,
                  "λ = \(lambda): got error \(r.error), active \(r.activePerPoint), found \(r.found), dead \(r.dead)")
        }
        let start = SparseAutoencoder.train(lambda: SparseAutoencoder.penalties[0])
        check(!(start.found == 5 && abs(start.activePerPoint - 0.5) < 0.1), "the starting λ must not solve the task")
        print("sparse ok")
    }

    static func circuit() {
        let all = Set(0..<6)
        check(TinyCircuit.accuracy(keep: all) == 8, "all six neurons answer 8 of 8")
        check((0..<6).map { TinyCircuit.accuracy(keep: all.subtracting([$0])) } == [8, 8, 7, 8, 8, 8], "single ablations as in the lesson")
        check(TinyCircuit.accuracy(keep: [2, 3]) == 8 && (0..<6).allSatisfy { TinyCircuit.accuracy(keep: [$0]) < 8 }, "the smallest circuit has two neurons, [2, 3]")
        check(near(TinyCircuit.patched(2), 0.993, 0.0006) && near(TinyCircuit.patched(5), 0.080, 0.0006), "patching neuron 2 gives 0.993, neuron 5 gives 0.080")
        print("circuit ok")
    }

    static func planning() {
        check((1...21).filter { !StickGame.win[$0] } == [4, 8, 12, 16, 20], "losing piles are multiples of 4")
        check(StickGame.perfectMoves(21) == [1], "from 21 take 1")
        let counts = [10, 50, 200, 1000].map { StickGame.results(simulations: $0).values.filter { $0 }.count }
        check(counts == [8, 12, 13, 13], "right moves at 10, 50, 200, 1000 simulations: got \(counts)")
        let top = StickGame.mcts(21, simulations: 1000, seed: 21)
        check(top.move == 1 && top.visits == [1: 977, 2: 330, 3: 339], "visits from 21: got \(top.visits)")
        check(!StickGame.results(simulations: 10).values.allSatisfy { $0 }, "the starting 10 simulations must not solve the task")
        let options = [5, 10, 20, 50, 100, 200, 500, 1000]
        let first = options.first { StickGame.results(simulations: $0).values.allSatisfy { $0 } }
        check(first != nil, "some option must make every winning pile right")
        print("planning ok: smallest option with 13 of 13 is \(first ?? 0)")
    }

    static func addition() {
        let base = AdditionNet.train(high: 1)
        check(near(base.error(base.near), 0.00004, 0.000006), "error inside [0, 1] should be 0.00004, got \(base.error(base.near))")
        check(near(base.error(base.far), 0.1156, 0.0006), "error on [1, 2] should be 0.1156")
        check(near(base.predict((2, 2)), 3.23, 0.006) && near(base.predict((1.5, 1.5)), 2.71, 0.006), "(2, 2) → 3.23 and (1.5, 1.5) → 2.71")
        let start = base.predict((2, 2)) - 4
        check(start * start >= 0.1, "the starting range must not solve the task")
        let solving = AdditionNet.trainingRanges.filter { let e = AdditionNet.train(high: $0).predict((2, 2)) - 4; return e * e < 0.1 }
        check(!solving.isEmpty, "a wider range should bring the error at (2, 2) below 0.1")
        print("addition ok: ranges that solve it \(solving)")
    }

    static func replacement() {
        check(near(ReplacementBrain.neuron(0.5), 0.6225) && near(ReplacementBrain.chip(0.5), 0.6225), "neuron and chip agree at 0.5")
        let trace = ReplacementBrain.run(chips: 0)
        check(zip(trace.prefix(6), [0.5, 0.659, 0.729, 0.8, 0.819, 0.84]).allSatisfy { near($0, $1) }, "trace of neuron 9 differs from the lesson: \(trace.prefix(6))")
        check((0...10).allSatisfy { ReplacementBrain.largestDifference(chips: $0) < 1e-14 }, "replacing neurons must not change behaviour beyond rounding")
        print("replacement ok")
    }

    static func preregistration() {
        check(near(Preregistration.gap(Preregistration.data, cut: 0.9) ?? 0, 0.41, 0.005), "difference 0.41 at the cut 0.9")
        let ci = Preregistration.interval(cut: 0.9)
        check(near(ci.low, -0.06, 0.005) && near(ci.high, 0.80, 0.005), "interval −0.06 … 0.80, got \(ci)")
        let copies = [1, 2, 4, 8].first { Preregistration.interval(cut: 0.9, copies: $0).low > 0 }
        check(copies != nil && copies != 1, "more answers should lift the interval above zero")
        print("preregistration ok: interval above zero from \((copies ?? 0) * 20) answers")
    }

    static func reading() {
        let rotation = SVD2.decompose(0.8, -0.6, 0.6, 0.8)
        check(near(rotation.s1, 1) && near(rotation.s2, 1), "a rotation has both singular values 1, so the start does not solve the task")
        let rankOne = SVD2.decompose(1, 2, 2, 4)
        check(near(rankOne.s1, 5) && rankOne.s2 < 1e-6, "[[1, 2], [2, 4]] has singular values 5 and 0")
        let diagonal = SVD2.decompose(3, 0, 0, 1)
        check(near(diagonal.s1, 3) && near(diagonal.s2, 1) && near(abs(diagonal.v1.0), 1), "diagonal matrix")
        check(near(JacobianMap.determinant((1, 1)), 3) && near(JacobianMap.determinant((1, -2)), 0), "det J is 3 at (1, 1) and 0 at (1, −2)")
        let j = JacobianMap.layerJacobian([0.4, -0.2])
        check(near(j[0][0], 0.4278, 0.00006) && near(j[1][0], 1.2084, 0.00006) && near(j[2][1], 0.6631, 0.00006), "layer Jacobian as in the lesson")
        let counts = [2.0, 5, 7, 10, 20].map { HodgkinHuxley.simulate(current: $0).spikes }
        check(counts == [0, 1, 3, 3, 4], "spikes at 2, 5, 7, 10, 20: got \(counts)")
        check(near(HodgkinHuxley.simulate(current: 10).trace.max() ?? 0, 40.5, 0.06), "peak at 10 should be 40.5 mV")
        let threshold = stride(from: 0.5, through: 20, by: 0.5).first { HodgkinHuxley.simulate(current: $0).spikes >= 3 }
        check(threshold != nil && threshold! > 2, "a current above the starting 2 gives three spikes")
        print("reading ok: three spikes from \(threshold ?? 0)")
    }

    static func loopsMatrices() {
        check(LoopsMatrices.measuredSizes == [16, 32, 64, 128, 256], "the lesson measured n = 16…256")
        check(LoopsMatrices.measuredTimesFaster == [133, 620, 1912, 3005, 3348], "times faster must match the lesson's table")
        check(LoopsMatrices.firstComputeBound == 64, "the arithmetic should outweigh the call from n = 64, got \(LoopsMatrices.firstComputeBound)")
        check(LoopsMatrices.computeShare(16) < 0.5, "the starting size 16 must not already solve the task")
        check(Int(LoopsMatrices.trainingTimesFaster.rounded()) == 129, "47.2 min against 22 s is about 129 times")
        for (index, n) in LoopsMatrices.measuredSizes.enumerated() where n >= 64 {
            let loops: Double = LoopsMatrices.loopSeconds(n) * 1000 / LoopsMatrices.loopMilliseconds[index]
            let fast: Double = LoopsMatrices.numpySeconds(n) * 1000 / LoopsMatrices.numpyMilliseconds[index]
            check(loops > 0.5 && loops < 2 && fast > 0.5 && fast < 2, "the rough model should stay within 2× of the measurement at n = \(n)")
        }
    }

    static func main() {
        reading()
        replacement()
        preregistration()
        planning()
        addition()
        bigram()
        sampling()
        dpo()
        scaling()
        dedup()
        sparse()
        circuit()
        loopsMatrices()
    }
}
