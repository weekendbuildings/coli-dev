import Foundation

/// The formula L = (a · b + c) · f as a graph, with the backward pass revealed one stage at a time.
/// Формула L = (a · b + c) · f как граф; обратный проход открывается по одному этапу.
struct GradGraphState: Equatable {
    enum Input: String, CaseIterable, Identifiable {
        case a, b, c, f

        var id: String { rawValue }
    }

    enum Node: String, CaseIterable, Identifiable {
        case a, b, c, f, product, sum, result

        var id: String { rawValue }
    }

    /// What the backward pass reaches at each stage, from the end to the start. / Что проход достигает на каждом этапе, от конца к началу.
    static let stages: [[Node]] = [[.result], [.sum, .f], [.product, .c], [.a, .b]]
    static let nudgeSize = 0.5
    static let nudgeLimit = 3

    private(set) var a = 2.0
    private(set) var b = -3.0
    private(set) var c = 10.0
    private(set) var f = -2.0
    private(set) var stage = 0
    private(set) var nudges = 0
    private(set) var lastPredicted: Double?
    private(set) var lastReal: Double?

    var product: Double { a * b }
    var sum: Double { product + c }
    var result: Double { sum * f }

    func value(of node: Node) -> Double {
        switch node {
        case .a: return a
        case .b: return b
        case .c: return c
        case .f: return f
        case .product: return product
        case .sum: return sum
        case .result: return result
        }
    }

    /// The true gradient of L by each node, by the chain rule. / Настоящий градиент L по каждому узлу по правилу цепочки.
    func gradient(of node: Node) -> Double {
        switch node {
        case .result: return 1
        case .sum: return f
        case .f: return sum
        case .product, .c: return f
        case .a: return f * b
        case .b: return f * a
        }
    }

    func revealedGradient(of node: Node) -> Double? {
        let reached = Self.stages.prefix(stage).contains { $0.contains(node) }
        return reached ? gradient(of: node) : nil
    }

    var finished: Bool { stage == Self.stages.count }

    /// The biggest push: the input with the largest gradient. / Самый сильный толчок: вход с наибольшим градиентом.
    var strongestInput: Input {
        Input.allCases.max { abs(gradient(of: Node(rawValue: $0.rawValue)!)) < abs(gradient(of: Node(rawValue: $1.rawValue)!)) }!
    }

    mutating func stepBack() {
        if stage < Self.stages.count { stage += 1 }
    }

    mutating func finishBackward() {
        stage = Self.stages.count
    }

    /// Moves one input; the old gradient predicts the change and the formula shows the real one.
    /// Сдвигает один вход: старый градиент предсказывает изменение, а формула показывает настоящее.
    mutating func nudge(_ input: Input, up: Bool) {
        let delta = up ? Self.nudgeSize : -Self.nudgeSize
        let before = result
        lastPredicted = gradient(of: Node(rawValue: input.rawValue)!) * delta
        switch input {
        case .a: a += delta
        case .b: b += delta
        case .c: c += delta
        case .f: f += delta
        }
        lastReal = result - before
        nudges += 1
        stage = 0
    }

    mutating func reset() {
        self = GradGraphState()
    }

    /// L above zero in three pushes works only with the largest gradient. / L выше нуля за три толчка выходит только через самый большой градиент.
    var solved: Bool { result > 0 && nudges <= Self.nudgeLimit }
}
