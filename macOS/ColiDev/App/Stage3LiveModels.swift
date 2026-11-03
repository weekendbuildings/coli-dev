import Foundation

/// Choosing between answering at once and reasoning, from the recorded results.
/// Выбор между ответом сразу и рассуждением по записанным результатам.
enum ReasoningChoice {
    /// The lesson's REINFORCE on two modes. / REINFORCE урока на двух режимах.
    static func train(price: Double, steps: Int = 4000, rate: Double = 0.02, seed: UInt64 = 3) -> [Double] {
        var rand = RLRand(seed)
        var theta = 0.0
        var base = 0.0
        var curve: [Double] = []
        for step in 0..<steps {
            let p = 1 / (1 + exp(-theta))
            let think = rand.next() < p
            let task = ReasoningRecording.tasks[Int(rand.next() * Double(ReasoningRecording.tasks.count))]
            let right = think ? task.reasonRight : task.directRight
            let tokens = think ? task.reasonTokens : task.directTokens
            let reward: Double = (right ? 1 : 0) - price * Double(tokens) / 1000
            base += 0.05 * (reward - base)
            theta += rate * (reward - base) * (think ? 1 - p : -p)
            if step % 40 == 0 { curve.append(p) }
        }
        curve.append(1 / (1 + exp(-theta)))
        return curve
    }

    static func solved(limit: Int) -> Int {
        ReasoningRecording.tasks.filter { $0.reasonRight && $0.reasonTokens <= limit }.count
    }
}

/// The track with reappearing coins from the safety lesson. / Дорожка с появляющимися монетами из урока о безопасности.
struct BoatRace {
    static let cells = 8
    static let limit = 60
    let coin: Double
    let once: Bool
    private(set) var q: [[Double]]

    private static func bit(_ cell: Int) -> Int { cell == 2 ? 1 : (cell == 3 ? 2 : 0) }

    private static func state(_ cell: Int, _ taken: Int) -> Int { cell + cells * taken }

    private func step(_ cell: Int, _ taken: Int, _ action: Int) -> (cell: Int, taken: Int, reward: Double, done: Bool) {
        let next = action == 1 ? cell + 1 : max(cell - 1, 0)
        if next == Self.cells - 1 { return (next, taken, 1, true) }
        var reward = -0.01
        var mask = taken
        let bit = Self.bit(next)
        if bit != 0, !(once && taken & bit != 0) {
            reward += coin
            mask |= bit
        }
        return (next, mask, reward, false)
    }

    init(coin: Double, once: Bool, episodes: Int, seed: UInt64) {
        self.coin = coin
        self.once = once
        q = [[Double]](repeating: [0, 0], count: Self.cells * 4)
        var rand = RLRand(seed)
        for _ in 0..<episodes {
            var cell = 0
            var taken = 0
            for _ in 0..<Self.limit {
                let index = Self.state(cell, taken)
                let row = q[index]
                let action: Int
                if rand.next() < 0.1 {
                    action = Int(rand.next() * 2)
                } else {
                    action = row[0] >= row[1] ? 0 : 1
                }
                let result = step(cell, taken, action)
                let ahead = q[Self.state(result.cell, result.taken)]
                let future: Double = result.done ? 0 : 0.95 * max(ahead[0], ahead[1])
                q[index][action] += 0.2 * (result.reward + future - q[index][action])
                cell = result.cell
                taken = result.taken
                if result.done { break }
            }
        }
    }

    /// The route without randomness, the game score and whether it finished. / Маршрут без случайности, счёт и дошёл ли до финиша.
    func play() -> (route: [Int], score: Double, finished: Bool) {
        var cell = 0
        var taken = 0
        var score = 0.0
        var route = [0]
        for _ in 0..<Self.limit {
            let row = q[Self.state(cell, taken)]
            let result = step(cell, taken, row[1] > row[0] ? 1 : 0)
            score += result.done ? result.reward : result.reward + 0.01
            cell = result.cell
            taken = result.taken
            route.append(cell)
            if result.done { return (route, score, true) }
        }
        return (route, score, false)
    }
}

/// Mean measures of a search from ranked places. / Средние меры поиска по местам в выдаче.
enum SearchScore {
    static func foundShare(places: [Int], within k: Int) -> Double {
        Double(places.filter { $0 < k }.count) / Double(max(places.count, 1))
    }

    static func meanReciprocalRank(places: [Int]) -> Double {
        places.reduce(0.0) { $0 + 1 / Double($1 + 1) } / Double(max(places.count, 1))
    }
}
