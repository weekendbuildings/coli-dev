import Foundation

@main
enum ErrorLandscapeVerification {
    typealias Model = ErrorLandscapeModel

    static func run(from start: Model.Point, rate: Double) -> Model {
        var model = Model(start: start)
        while !model.isFinished && model.phase != .stalled { model.step(learningRate: rate) }
        return model
    }

    static func main() {
        // The frozen weights are a real training run of the lesson's network, rounded to tenths.
        var trained = XORNetworkModel(architecture: .hiddenLayer, start: .first)
        for _ in 0..<6000 { trained.step(learningRate: 1) }
        precondition(trained.weights.map { ($0 * 10).rounded() / 10 } == Model.frozenWeights, "frozen weights come from training")

        // The gradient is the true slope of the drawn surface.
        for point in [Model.Point(w11: 1, w12: 1), Model.Point(w11: -2, w12: 0.5), Model.Point(w11: 3, w12: -1)] {
            let h = 1e-6
            let dx = (Model.loss(at: .init(w11: point.w11 + h, w12: point.w12)) - Model.loss(at: .init(w11: point.w11 - h, w12: point.w12))) / (2 * h)
            let dy = (Model.loss(at: .init(w11: point.w11, w12: point.w12 + h)) - Model.loss(at: .init(w11: point.w11, w12: point.w12 - h))) / (2 * h)
            let gradient = Model.gradient(at: point)
            precondition(abs(dx - gradient.x) < 1e-6 && abs(dy - gradient.y) < 1e-6, "gradient equals the numerical slope")
        }

        // Each terrace label names the true number of wrong answers, and its height is about that many quarters.
        for terrace in Model.terraces {
            precondition(Model.wrongAnswers(at: terrace.point) == terrace.wrongAnswers, "terrace label")
            precondition(abs(Model.loss(at: terrace.point) - Double(terrace.wrongAnswers) / 4) < 0.02, "terrace height")
        }

        // The start of the lab does not solve the task: at η = 1 the ball stalls on the shelf with one wrong answer.
        let opening = Model()
        precondition(opening.phase == .ready && !opening.solvesChallenge)
        let shelf = run(from: Model.defaultStart, rate: 1)
        precondition(shelf.phase == .stalled && !shelf.solvesChallenge && shelf.correctAnswers == 3, "default run stalls on the shelf")
        precondition(abs(shelf.loss - 0.245) < 0.002, "shelf height")

        // A start at the top of the valley's slope learns XOR within the step limit.
        let learned = run(from: .init(w11: 0, w12: 5), rate: 1)
        precondition(learned.phase == .learned && learned.solvesChallenge && learned.correctAnswers == 4, "the task can be solved")
        precondition(learned.startLoss >= Model.challengeStartLoss)
        precondition(learned.iterations <= Model.stepLimit)
        precondition(learned.loss < learned.startLoss)

        // The rate matters: from this point on the shelf, η = 1 stalls and η = 5 crosses into the valley.
        precondition(run(from: .init(w11: -1, w12: 5), rate: 1).phase == .stalled, "small rate stalls")
        precondition(run(from: .init(w11: -1, w12: 5), rate: 5).phase == .learned, "larger rate crosses")

        // Too large a step leaves the terrain.
        precondition(run(from: .init(w11: 3, w12: 3), rate: 100).phase == .leftTerrain, "huge rate flies off")

        // On the high plateau the slope has vanished: the ball barely moves even at η = 30.
        let plateau = run(from: .init(w11: -6, w12: -6), rate: 30)
        precondition(plateau.phase == .stalled && plateau.correctAnswers == 2, "plateau stalls")
        precondition(abs(plateau.position.w11 + 6) < 0.1, "plateau keeps the ball in place")

        // Starting inside the valley cannot solve the task.
        let inside = Model(start: .init(w11: 8, w12: 8))
        precondition(inside.phase == .learned && !inside.solvesChallenge, "no credit for starting in the valley")

        // After a stall a resumed run with a higher rate can still reach the valley.
        var resumed = run(from: .init(w11: -1, w12: 5), rate: 1)
        resumed.resume()
        precondition(resumed.phase != .stalled)
        while !resumed.isFinished && resumed.phase != .stalled { resumed.step(learningRate: 5) }
        precondition(resumed.phase == .learned && resumed.solvesChallenge, "raising the rate gets off the shelf")

        // Restart returns to the same start, and starts outside the terrain are clamped to it.
        var restarted = shelf
        restarted.restart()
        precondition(restarted.iterations == 0 && restarted.position == Model.defaultStart && restarted.path == [Model.defaultStart])
        precondition(Model(start: .init(w11: 20, w12: -20)).start == .init(w11: 8, w12: -8))

        // No more steps after the limit.
        var long = Model(start: .init(w11: -6, w12: -6))
        for _ in 0..<(Model.stepLimit + 50) { long.step(learningRate: 0.1) }
        precondition(long.iterations == Model.stepLimit && long.phase == .outOfSteps, "step limit")

        // The surface mesh has the true height everywhere.
        let mesh = Model.surfaceMesh(resolution: 16, heightScale: 14)!
        precondition(mesh.positions.count == 17 * 17)
        let corner = mesh.positions[0]
        precondition(abs(corner.z - 14 * Model.loss(at: .init(w11: corner.x, w12: corner.y))) < 1e-9, "mesh height")

        print("Error landscape verification passed.")
    }
}
