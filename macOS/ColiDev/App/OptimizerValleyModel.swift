import Foundation

enum OptimizerKind: String, CaseIterable, Identifiable {
    case plain, momentum, adam

    var id: String { rawValue }
}

struct ValleyPoint: Equatable {
    var x: Double
    var y: Double
}

/// A long valley, 0.005x² + y², and the three rules of the lesson. / Длинная долина 0,005x² + y² и три правила из урока.
enum OptimizerValley {
    static let goal = 0.01
    static let stepsLimit = 1500

    static func loss(_ point: ValleyPoint) -> Double {
        0.005 * point.x * point.x + point.y * point.y
    }

    static func path(_ kind: OptimizerKind, rate: Double, start: ValleyPoint, steps: Int = stepsLimit) -> [ValleyPoint] {
        var x = start.x
        var y = start.y
        var result = [start]
        result.reserveCapacity(steps + 1)
        var firstX = 0.0
        var firstY = 0.0
        var secondX = 0.0
        var secondY = 0.0
        let beta = 0.9
        let beta2 = 0.999
        for t in 1...steps {
            let gx = 0.01 * x
            let gy = 2 * y
            switch kind {
            case .plain:
                x -= rate * gx
                y -= rate * gy
            case .momentum:
                firstX = beta * firstX + gx
                firstY = beta * firstY + gy
                x -= rate * firstX
                y -= rate * firstY
            case .adam:
                firstX = beta * firstX + (1 - beta) * gx
                firstY = beta * firstY + (1 - beta) * gy
                secondX = beta2 * secondX + (1 - beta2) * gx * gx
                secondY = beta2 * secondY + (1 - beta2) * gy * gy
                let fixFirst = 1 - pow(beta, Double(t))
                let fixSecond = 1 - pow(beta2, Double(t))
                x -= rate * (firstX / fixFirst) / ((secondX / fixSecond).squareRoot() + 1e-8)
                y -= rate * (firstY / fixFirst) / ((secondY / fixSecond).squareRoot() + 1e-8)
            }
            result.append(ValleyPoint(x: x, y: y))
        }
        return result
    }

    static func stepsToGoal(_ path: [ValleyPoint]) -> Int? {
        path.firstIndex { loss($0) < goal }
    }

    static func diverged(_ path: [ValleyPoint]) -> Bool {
        guard let last = path.last else { return false }
        return abs(last.x) > 1000 || abs(last.y) > 1000 || !last.x.isFinite || !last.y.isFinite
    }
}

/// The race on the valley, with no drawing, so a script can check it. / Гонка по долине без рисования.
struct OptimizerRaceState {
    static let defaultStart = ValleyPoint(x: -8, y: 2)
    /// How many steps the animation shows. / Сколько шагов показывает анимация.
    static let lastStep = 200

    private(set) var rates: [OptimizerKind: Double] = [.plain: 0.1, .momentum: 0.1, .adam: 0.1]
    private(set) var start = OptimizerRaceState.defaultStart
    private(set) var step = 0
    private(set) var revision = 0
    private(set) var sawDivergence = false
    private(set) var paths: [OptimizerKind: [ValleyPoint]] = [:]

    init() {
        recompute()
    }

    private mutating func recompute() {
        for kind in OptimizerKind.allCases {
            paths[kind] = OptimizerValley.path(kind, rate: rates[kind] ?? 0.1, start: start)
        }
        if OptimizerValley.diverged(paths[.plain] ?? []) { sawDivergence = true }
        step = 0
        revision += 1
    }

    func rate(_ kind: OptimizerKind) -> Double { rates[kind] ?? 0.1 }

    mutating func setRate(_ kind: OptimizerKind, _ value: Double) {
        rates[kind] = value
        recompute()
    }

    mutating func setStart(_ point: ValleyPoint) {
        start = point
        recompute()
    }

    mutating func restart() {
        step = 0
        revision += 1
    }

    mutating func advance() {
        if step < Self.lastStep { step += 1 }
    }

    func steps(_ kind: OptimizerKind) -> Int? { OptimizerValley.stepsToGoal(paths[kind] ?? []) }
    func diverged(_ kind: OptimizerKind) -> Bool { OptimizerValley.diverged(paths[kind] ?? []) }

    /// You saw the limit of plain descent and then found good steps for all three. / Увидел предел обычного спуска и нашёл хорошие шаги для всех трёх.
    var solved: Bool {
        guard sawDivergence, let plain = steps(.plain), let momentum = steps(.momentum), let adam = steps(.adam) else { return false }
        return plain < 200 && momentum < 100 && adam < 30
    }
}
