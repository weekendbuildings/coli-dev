import Foundation

/// The lessons' small generator: the same numbers in Swift and in the Python programs.
/// Маленький генератор уроков: те же числа в Swift и в программах на Python.
struct RLRand {
    private var state: UInt64

    init(_ seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / 9007199254740992
    }
}

enum BanditRule: Equatable {
    case epsilon(Double)
    case ucb
}

enum BanditModel {
    static let probabilities = [0.2, 0.35, 0.5, 0.65, 0.8]
    static let best = 0.8
    static let horizon = 3000
    static let runs = 100

    static func choose(_ rule: BanditRule, values: [Double], counts: [Int], step: Int, rand: inout RLRand) -> Int {
        switch rule {
        case .epsilon(let epsilon):
            if rand.next() < epsilon { return Int(rand.next() * Double(values.count)) }
            let top = values.max() ?? 0
            let ties = values.indices.filter { values[$0] == top }
            return ties[Int(rand.next() * Double(ties.count))]
        case .ucb:
            if let unseen = counts.firstIndex(of: 0) { return unseen }
            var bestArm = 0
            var bestScore = -Double.infinity
            for arm in values.indices {
                let bonus: Double = (2 * log(Double(step)) / Double(counts[arm])).squareRoot()
                if values[arm] + bonus > bestScore {
                    bestScore = values[arm] + bonus
                    bestArm = arm
                }
            }
            return bestArm
        }
    }

    /// One game: the regret after each step and how often each machine was pulled. / Одна игра: сожаление после каждого хода и сколько раз тянули каждый автомат.
    static func play(_ rule: BanditRule, steps: Int, seed: UInt64) -> (regret: [Double], counts: [Int]) {
        var rand = RLRand(seed)
        var values = [Double](repeating: 0, count: probabilities.count)
        var counts = [Int](repeating: 0, count: probabilities.count)
        var regret: [Double] = []
        regret.reserveCapacity(steps)
        var total = 0.0
        for step in 1...steps {
            let arm = choose(rule, values: values, counts: counts, step: step, rand: &rand)
            let reward: Double = rand.next() < probabilities[arm] ? 1 : 0
            counts[arm] += 1
            values[arm] += (reward - values[arm]) / Double(counts[arm])
            total += best - probabilities[arm]
            regret.append(total)
        }
        return (regret, counts)
    }

    /// Mean regret over the lesson's runs, with the lesson's seeds. / Среднее сожаление по запускам урока, с его зёрнами.
    static func meanRegret(_ rule: BanditRule, steps: Int = horizon, runs: Int = runs) -> [Double] {
        var mean = [Double](repeating: 0, count: steps)
        for run in 0..<runs {
            let curve = play(rule, steps: steps, seed: UInt64(1000 + run)).regret
            for index in 0..<steps { mean[index] += curve[index] / Double(runs) }
        }
        return mean
    }
}

/// The learner's own game with hidden, shuffled machines. / Своя игра ученика со спрятанными и перемешанными автоматами.
struct BanditHandGame {
    private(set) var probabilities: [Double]
    private(set) var values: [Double]
    private(set) var counts: [Int]
    private(set) var pulls = 0
    private(set) var wins = 0
    private(set) var regret = 0.0
    private var rand: RLRand

    init(seed: UInt64) {
        rand = RLRand(seed)
        var shuffled = BanditModel.probabilities
        for index in stride(from: shuffled.count - 1, to: 0, by: -1) {
            shuffled.swapAt(index, Int(rand.next() * Double(index + 1)))
        }
        probabilities = shuffled
        values = [Double](repeating: 0, count: shuffled.count)
        counts = [Int](repeating: 0, count: shuffled.count)
    }

    mutating func pull(_ arm: Int) {
        let reward: Double = rand.next() < probabilities[arm] ? 1 : 0
        counts[arm] += 1
        pulls += 1
        wins += Int(reward)
        values[arm] += (reward - values[arm]) / Double(counts[arm])
        regret += BanditModel.best - probabilities[arm]
    }
}

/// The world of the Bellman and Q-learning lessons; cells are numbered row by row.
/// Мир уроков о Беллмане и Q-обучении; клетки пронумерованы по строкам.
enum GridWorld {
    static let rows = 5
    static let columns = 6
    static let cellCount = rows * columns
    static let start = 24
    static let goal = 29
    static let pits: Set<Int> = [25, 26, 27, 28]
    static let stepCost = -0.04
    /// Up, right, down, left. / Вверх, вправо, вниз, влево.
    static let moves: [(row: Int, column: Int)] = [(-1, 0), (0, 1), (1, 0), (0, -1)]

    static func isTerminal(_ cell: Int) -> Bool { cell == goal || pits.contains(cell) }

    static func reward(_ cell: Int) -> Double {
        if cell == goal { return 1 }
        return pits.contains(cell) ? -1 : stepCost
    }

    static func move(_ cell: Int, _ action: Int, walls: Set<Int> = []) -> Int {
        let row = cell / columns + moves[action].row
        let column = cell % columns + moves[action].column
        guard row >= 0, row < rows, column >= 0, column < columns else { return cell }
        let next = row * columns + column
        return walls.contains(next) ? cell : next
    }

    static func actionValue(_ cell: Int, _ action: Int, values: [Double], gamma: Double, slip: Double) -> Double {
        func outcome(_ direction: Int) -> Double {
            let next = move(cell, direction)
            return reward(next) + gamma * values[next]
        }
        var total = (1 - slip) * outcome(action)
        if slip > 0 {
            total += slip / 2 * outcome((action + 3) % 4)
            total += slip / 2 * outcome((action + 1) % 4)
        }
        return total
    }

    static func sweep(_ values: [Double], gamma: Double, slip: Double) -> [Double] {
        (0..<cellCount).map { cell in
            if isTerminal(cell) { return 0 }
            var best = -Double.infinity
            for action in 0..<4 { best = max(best, actionValue(cell, action, values: values, gamma: gamma, slip: slip)) }
            return best
        }
    }

    /// Value iteration, stopped early when a limit on sweeps is given. / Итерация ценности; останавливается раньше, если задан предел проходов.
    static func solve(gamma: Double, slip: Double, limit: Int? = nil, tolerance: Double = 1e-4) -> (values: [Double], sweeps: Int, converged: Bool) {
        var values = [Double](repeating: 0, count: cellCount)
        var sweeps = 0
        while limit == nil || sweeps < limit! {
            let new = sweep(values, gamma: gamma, slip: slip)
            var change = 0.0
            for cell in 0..<cellCount { change = max(change, abs(new[cell] - values[cell])) }
            values = new
            sweeps += 1
            if change < tolerance { return (values, sweeps, true) }
        }
        return (values, sweeps, false)
    }

    static func greedy(_ cell: Int, values: [Double], gamma: Double, slip: Double) -> Int {
        var best = 0
        var bestValue = -Double.infinity
        for action in 0..<4 {
            let raw = actionValue(cell, action, values: values, gamma: gamma, slip: slip)
            let value: Double = (raw * 1e9).rounded() / 1e9
            if value > bestValue {
                bestValue = value
                best = action
            }
        }
        return best
    }

    /// The route by the arrows; nil when they lead in a circle or into a wall. / Маршрут по стрелкам; nil, если стрелки ведут по кругу или в стену.
    static func route(values: [Double], gamma: Double, slip: Double) -> [Int]? {
        var cell = start
        var cells = [start]
        while !isTerminal(cell) {
            cell = move(cell, greedy(cell, values: values, gamma: gamma, slip: slip))
            if cells.contains(cell) { return nil }
            cells.append(cell)
        }
        return cells
    }

    /// The fewest steps from start to goal around walls and pits. / Наименьшее число шагов от старта к цели в обход стен и ям.
    static func shortestSteps(walls: Set<Int>) -> Int? {
        var distance = [start: 0]
        var queue = [start]
        var head = 0
        while head < queue.count {
            let cell = queue[head]
            head += 1
            if cell == goal { return distance[cell] }
            for action in 0..<4 {
                let next = move(cell, action, walls: walls)
                if distance[next] == nil, !pits.contains(next) {
                    distance[next] = (distance[cell] ?? 0) + 1
                    queue.append(next)
                }
            }
        }
        return nil
    }
}

/// Q-learning and SARSA by the formula of the lesson, one environment step at a time.
/// Q-обучение и SARSA по формуле урока, по одному шагу в мире.
struct QLearner {
    struct Episode: Equatable {
        let total: Double
        let steps: Int
        let fell: Bool
    }

    static let stepLimit = 200

    var alpha: Double
    var epsilon: Double
    let gamma: Double
    var sarsa: Bool
    var walls: Set<Int> = []
    private(set) var q: [[Double]]
    private(set) var log: [Episode] = []
    private(set) var cell = GridWorld.start
    private var action = 0
    private var total = 0.0
    private var steps = 0
    private var inEpisode = false
    private var rand: RLRand

    init(alpha: Double, epsilon: Double, gamma: Double, sarsa: Bool, seed: UInt64) {
        self.alpha = alpha
        self.epsilon = epsilon
        self.gamma = gamma
        self.sarsa = sarsa
        q = [[Double]](repeating: [0, 0, 0, 0], count: GridWorld.cellCount)
        rand = RLRand(seed)
    }

    private mutating func choose(_ row: [Double]) -> Int {
        if rand.next() < epsilon { return Int(rand.next() * 4) }
        let top = row.max() ?? 0
        let ties = (0..<4).filter { row[$0] == top }
        return ties[Int(rand.next() * Double(ties.count))]
    }

    private func firstBest(_ row: [Double]) -> Int {
        row.firstIndex(of: row.max() ?? 0) ?? 0
    }

    mutating func advance() {
        if !inEpisode {
            cell = GridWorld.start
            total = 0
            steps = 0
            action = choose(q[cell])
            inEpisode = true
        }
        let next = GridWorld.move(cell, action, walls: walls)
        let reward = GridWorld.reward(next)
        let done = GridWorld.isTerminal(next)
        let nextAction = choose(q[next])
        let target = sarsa ? nextAction : firstBest(q[next])
        let future: Double = done ? 0 : gamma * q[next][target]
        q[cell][action] += alpha * (reward + future - q[cell][action])
        cell = next
        action = nextAction
        total += reward
        steps += 1
        if done || steps >= Self.stepLimit {
            log.append(Episode(total: total, steps: steps, fell: reward == -1))
            inEpisode = false
        }
    }

    mutating func train(episodes: Int) {
        let target = log.count + episodes
        while log.count < target { advance() }
    }

    mutating func restartEpisode() {
        inEpisode = false
        cell = GridWorld.start
    }

    func bestAction(_ cell: Int) -> Int { firstBest(q[cell]) }

    /// The route when acting without randomness. / Маршрут, если действовать без случайности.
    var route: [Int] {
        var current = GridWorld.start
        var cells = [current]
        while !GridWorld.isTerminal(current), cells.count < 40 {
            current = GridWorld.move(current, bestAction(current), walls: walls)
            cells.append(current)
        }
        return cells
    }

    var reachesGoal: Bool { route.last == GridWorld.goal }
}

/// The corridor with swapped buttons from Sutton and Barto, Example 13.1.
/// Коридор с перепутанными кнопками из книги Саттона и Барто, пример 13.1.
enum CorridorModel {
    struct Episode: Equatable {
        let total: Double
        let probability: Double
    }

    static let stepLimit = 500
    static let bestProbability = 2 - 2.0.squareRoot()

    static func exactValue(_ p: Double) -> Double { -2 * (2 - p) / (p * (1 - p)) }

    static func rightProbability(_ first: Double, _ second: Double) -> Double {
        1 / (1 + exp(max(-30, min(30, second - first))))
    }

    private static func step(_ state: Int, right: Bool) -> (next: Int, done: Bool) {
        switch state {
        case 1: return (right ? 2 : 1, false)
        case 2: return (right ? 1 : 3, false)
        default: return right ? (4, true) : (2, false)
        }
    }

    static func reinforce(episodes: Int, rate: Double, baselineRate: Double, seed: UInt64) -> [Episode] {
        var rand = RLRand(seed)
        var first = 0.0
        var second = log(9.0)
        var baseline = 0.0
        var curve: [Episode] = []
        curve.reserveCapacity(episodes)
        for _ in 0..<episodes {
            let start = rightProbability(first, second)
            var state = 1
            var done = false
            var tape: [Bool] = []
            while !done, tape.count < stepLimit {
                let right = rand.next() < start
                let result = step(state, right: right)
                state = result.next
                done = result.done
                tape.append(right)
            }
            curve.append(Episode(total: -Double(tape.count), probability: start))
            var future = 0.0
            for right in tape.reversed() {
                future -= 1
                let p = rightProbability(first, second)
                let advantage: Double = baselineRate > 0 ? future - baseline : future
                if baselineRate > 0 { baseline += baselineRate * advantage }
                let change: Double = right ? rate * advantage * (1 - p) : rate * advantage * -p
                first += change
                second -= change
            }
        }
        return curve
    }
}
