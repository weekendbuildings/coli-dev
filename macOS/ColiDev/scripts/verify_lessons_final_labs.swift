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

    static func main() {
        bigram()
        sampling()
        dpo()
        scaling()
        dedup()
    }
}
