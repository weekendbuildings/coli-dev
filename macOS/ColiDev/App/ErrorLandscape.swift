import Foundation

/// The hidden-layer XOR network of the programming lesson with only two trainable weights: w₁₁ and w₁₂ of the first
/// hidden neuron. The other seven stay frozen at values from a real training run, so the error over these two weights
/// is a true surface that can be drawn, and gradient descent on it is true training of this network.
/// Сеть XOR из урока, в которой обучаются только два веса первого скрытого нейрона. Остальные семь заморожены на
/// значениях из настоящего обучения, поэтому рельеф ошибки настоящий, а спуск по нему настоящее обучение этой сети.
struct ErrorLandscapeModel: Equatable {
    struct Point: Equatable {
        var w11: Double
        var w12: Double
    }

    enum Phase: Equatable {
        case ready, training, learned, stalled, leftTerrain, outOfSteps
    }

    /// `XORNetworkModel.Start.first` after 6000 iterations at η = 1, rounded to tenths; the first two are replaced.
    static let frozenWeights = [6.8, 6.8, -3.0, -5.1, -5.1, 7.6, 8.0, 8.2, -11.9]
    static let domain: ClosedRange<Double> = -8...8
    /// A start on the slope above the near shelf: at η = 1 the ball reaches the shelf and stays, so the task is not solved.
    static let defaultStart = Point(w11: 2, w12: -5)
    static let learningRateExponents: ClosedRange<Double> = -1...2
    static let stepLimit = 300
    /// Below this mean squared error each answer is within 0.2 of its target, so all four count as correct.
    static let learnedLoss = 0.01
    /// The task must begin at this error or higher: starting inside the valley teaches nothing.
    static let challengeStartLoss = 0.2
    /// The ball counts as stuck when the error has changed by less than this over the last `stallWindow` steps.
    static let stallChange = 1e-4
    static let stallWindow = 20
    /// Terraces of the surface with the number of wrong answers there, for the labels on the scene.
    static let terraces: [(point: Point, wrongAnswers: Int)] = [
        (Point(w11: -3, w12: -3), 2),
        (Point(w11: -4.5, w12: 6.5), 1),
        (Point(w11: 5.5, w12: -6), 1),
        (Point(w11: 5.5, w12: 5.5), 0)
    ]

    private(set) var start: Point
    /// The true weights; they may leave the drawn terrain after a large step.
    private(set) var position: Point
    /// Every position so far, starting with `start`.
    private(set) var path: [Point]
    /// The mean error before each step so far.
    private(set) var lossHistory: [Double] = []
    private var stallCheckStart = 0

    init(start: Point = Self.defaultStart) {
        let clamped = Point(w11: min(max(start.w11, Self.domain.lowerBound), Self.domain.upperBound),
                            w12: min(max(start.w12, Self.domain.lowerBound), Self.domain.upperBound))
        self.start = clamped
        position = clamped
        path = [clamped]
    }

    private static func network(at point: Point) -> XORNetworkModel {
        var network = XORNetworkModel(architecture: .hiddenLayer, start: .first)
        var weights = frozenWeights
        weights[0] = point.w11
        weights[1] = point.w12
        network.weights = weights
        return network
    }

    static func loss(at point: Point) -> Double { network(at: point).loss }

    static func gradient(at point: Point) -> SIMD2<Double> {
        let gradient = network(at: point).gradient
        return SIMD2(gradient[0], gradient[1])
    }

    static func wrongAnswers(at point: Point) -> Int {
        XORNetworkModel.examples.count - network(at: point).correctAnswers
    }

    /// The surface in units where height is the error times `heightScale`, with horizontal units equal to weights.
    static func surfaceMesh(resolution: Int, heightScale: Double) -> SurfaceMesh? {
        SurfacePlot3D.mesh(
            domain: domain,
            resolution: resolution,
            gridStride: 8,
            function: { heightScale * loss(at: Point(w11: $0, w12: $1)) },
            gradient: { heightScale * gradient(at: Point(w11: $0, w12: $1)) }
        )
    }

    var network: XORNetworkModel { Self.network(at: position) }
    var loss: Double { network.loss }
    var startLoss: Double { Self.loss(at: start) }
    var gradient: SIMD2<Double> { Self.gradient(at: position) }
    var iterations: Int { lossHistory.count }
    var correctAnswers: Int { network.correctAnswers }

    var isOnTerrain: Bool { Self.domain.contains(position.w11) && Self.domain.contains(position.w12) }

    /// Where to draw the ball: at the true position, or at the edge once it has left the drawn terrain.
    var ballPosition: Point {
        Point(w11: min(max(position.w11, Self.domain.lowerBound), Self.domain.upperBound),
              w12: min(max(position.w12, Self.domain.lowerBound), Self.domain.upperBound))
    }

    var phase: Phase {
        if !isOnTerrain { return .leftTerrain }
        if loss < Self.learnedLoss { return .learned }
        if iterations >= Self.stepLimit { return .outOfSteps }
        if iterations - stallCheckStart >= Self.stallWindow,
           abs(lossHistory[iterations - Self.stallWindow] - loss) < Self.stallChange { return .stalled }
        return iterations == 0 ? .ready : .training
    }

    var isFinished: Bool { [.learned, .leftTerrain, .outOfSteps].contains(phase) }

    var solvesChallenge: Bool { phase == .learned && iterations > 0 && startLoss >= Self.challengeStartLoss }

    /// One step of gradient descent: w ← w − η · ∂L/∂w. No inertia, the ball is only a picture of the weights.
    mutating func step(learningRate: Double) {
        guard !isFinished else { return }
        lossHistory.append(loss)
        let slope = gradient
        position = Point(w11: position.w11 - learningRate * slope.x, w12: position.w12 - learningRate * slope.y)
        path.append(position)
    }

    /// After a stall the learner may raise the rate and press Play again, so the stall check starts over.
    mutating func resume() { stallCheckStart = iterations }

    mutating func restart() { self = Self(start: start) }

    static func learningRate(exponent: Double) -> Double { pow(10, exponent) }
}
