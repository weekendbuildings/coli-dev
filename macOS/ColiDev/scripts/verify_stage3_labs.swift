import Foundation

/// The labs compute the same numbers as the lessons' programs. / Тренажёры считают те же числа, что программы уроков.
@main
enum Stage3LabsVerification {
    static func main() {
        let pairs = PreferenceModel.lessonPairs()
        precondition(pairs.count == 162, "\(pairs.count)")
        let weight = PreferenceModel.fitReward(pairs)
        precondition(abs((weight["спасибо"] ?? 0) - 2.500266684608095) < 1e-6, "\(weight)")
        let free = PreferenceModel.shift(weight, klWeight: 0).log
        precondition(free.count == 11 && free[10].different == 2 && abs(free[10].reward - 24.93) < 0.01 && abs(free[10].person - -7.97) < 0.01, "\(free[10])")
        precondition(free[5].different == 211 && abs(free[5].person - 0.48) < 0.01, "\(free[5])")
        let held = PreferenceModel.shift(weight, klWeight: 1).log
        precondition(held[10].different == 239 && abs(held[10].person - 0.3) < 0.01, "\(held[10])")

        var source = RLRand(21)
        var winner0 = 0.0
        for _ in 0..<40 { winner0 += WinnerCurse.winner(models: 1, testSize: 20, rand: &source) / 40 }
        precondition(abs(winner0 - 0.7150000000000001) < 1e-9, "\(winner0)")
        var winner1 = 0.0
        for _ in 0..<40 { winner1 += WinnerCurse.winner(models: 10, testSize: 20, rand: &source) / 40 }
        precondition(abs(winner1 - 0.8525) < 1e-9, "\(winner1)")
        var winner2 = 0.0
        for _ in 0..<40 { winner2 += WinnerCurse.winner(models: 1, testSize: 100, rand: &source) / 40 }
        precondition(abs(winner2 - 0.689) < 1e-9, "\(winner2)")
        var winner3 = 0.0
        for _ in 0..<40 { winner3 += WinnerCurse.winner(models: 10, testSize: 100, rand: &source) / 40 }
        precondition(abs(winner3 - 0.77475) < 1e-9, "\(winner3)")
        let interval = WinnerCurse.wilson(hits: 80, count: 100)
        precondition(abs(interval.low - 0.711) < 0.001 && abs(interval.high - 0.867) < 0.001, "\(interval)")

        var flat = SuperpositionTrainer(features: 5, dims: 2, sparsity: 0.9, seed: 31)
        flat.run(steps: 5000)
        precondition(abs(flat.vectors[0][0] - 0.5427146848534457) < 1e-6, "\(flat.vectors)")
        precondition(abs(flat.vectors[0][1] - 0.9415759123856462) < 1e-6, "\(flat.vectors)")
        precondition(abs(flat.vectors[1][0] - -0.7708430649897512) < 1e-6, "\(flat.vectors)")
        precondition(abs(flat.vectors[1][1] - 0.8791329215321231) < 1e-6, "\(flat.vectors)")
        precondition(abs(flat.vectors[2][0] - 0.07686826319268412) < 1e-6, "\(flat.vectors)")
        precondition(abs(flat.vectors[2][1] - -1.0857526438686356) < 1e-6, "\(flat.vectors)")
        precondition(abs(flat.vectors[3][0] - 1.0509610872077508) < 1e-6, "\(flat.vectors)")
        precondition(abs(flat.vectors[3][1] - -0.19025382482182748) < 1e-6, "\(flat.vectors)")
        precondition(abs(flat.vectors[4][0] - -1.0241132454446433) < 1e-6, "\(flat.vectors)")
        precondition(abs(flat.vectors[4][1] - -0.4667021943559439) < 1e-6, "\(flat.vectors)")
        precondition(flat.aliveCount == 5, "The pentagon. / Пятиугольник.")
        var solid = SuperpositionTrainer(features: 6, dims: 3, sparsity: 0.95, seed: 32)
        solid.run(steps: 4000)
        precondition(solid.aliveCount == 6 && abs(solid.vectors[0][0] - -0.8294731821235166) < 1e-6, "\(solid.vectors)")

        let points = ProbeRecording.points(untrained: false, question: "next_space")
        precondition(points.count > 100 && (ProbeRecording.full["next_space-own"] ?? 0) > (ProbeRecording.full["next_space-blank"] ?? 1) - 0.0001, "Probe data. / Данные зонда.")
        precondition(ProbeGeometry.accuracy(points: [(0, 1, true), (0, -1, false)], from: (-1, 0), to: (1, 0)) == 1, "A line splits. / Прямая делит.")
        precondition(FineTuneRecording.methods.count == 6 && FineTuneRecording.startLoss == 3.451, "Recording. / Запись.")
        print("Stage 3 labs verified. / Тренажёры этапа 3 проверены.")
    }
}
