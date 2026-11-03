import Foundation

/// The labs compute the same numbers as the lessons' programs. / Тренажёры считают те же числа, что программы уроков.
@main
enum RLLabsVerification {
    private static func close(_ value: Double, _ expected: Double, _ tolerance: Double = 1e-6) -> Bool {
        abs(value - expected) <= tolerance
    }

    static func main() {
        let eps = BanditModel.play(.epsilon(0.1), steps: 3000, seed: 1000).regret
        precondition(close(eps[2999], 84.6, 0.01), "\(eps[2999])")
        let ucb = BanditModel.play(.ucb, steps: 3000, seed: 1001).regret
        precondition(close(ucb[2999], 140.1, 0.01), "\(ucb[2999])")
        let mean = BanditModel.meanRegret(.epsilon(0.1))
        precondition(mean[2999] < 115, "The lab's task can be solved. / Задачу тренажёра можно решить.")
        var game = BanditHandGame(seed: 3)
        precondition(game.probabilities.sorted() == BanditModel.probabilities, "Shuffled, not changed. / Перемешаны, но не изменены.")
        game.pull(0)
        precondition(game.pulls == 1 && game.counts[0] == 1, "One pull. / Один ход.")

        let still = GridWorld.solve(gamma: 0.95, slip: 0)
        precondition(still.converged && still.sweeps == 10 && close(still.values[GridWorld.start], 0.5231654031249996), "\(still.sweeps) \(still.values[GridWorld.start])")
        precondition(GridWorld.route(values: still.values, gamma: 0.95, slip: 0)?.count == 8, "Seven steps. / Семь шагов.")
        let slippery = GridWorld.solve(gamma: 0.95, slip: 0.2)
        precondition(slippery.sweeps == 26 && close(slippery.values[GridWorld.start], 0.06532953423530476), "\(slippery.sweeps)")
        let cells = GridWorld.route(values: slippery.values, gamma: 0.95, slip: 0.2)
        precondition(cells?.count == 10 && (cells?.map { $0 / GridWorld.columns }.min() ?? 9) == 2, "The route moves away from the pit. / Маршрут уходит от ямы.")
        let waiting = GridWorld.solve(gamma: 0.95, slip: 0.3)
        precondition(close(waiting.values[GridWorld.start], -0.11203647237796135), "\(waiting.values[GridWorld.start])")
        precondition(GridWorld.route(values: waiting.values, gamma: 0.95, slip: 0.3) == nil, "It waits at the wall. / Ждёт у стены.")
        precondition(GridWorld.greedy(GridWorld.start, values: waiting.values, gamma: 0.95, slip: 0.3) == 3, "It presses left. / Жмёт влево.")
        let far = GridWorld.solve(gamma: 0.8, slip: 0.2)
        precondition(far.sweeps == 24 && close(far.values[GridWorld.start], -0.15947448939770043), "\(far.sweeps)")
        precondition(GridWorld.solve(gamma: 0.95, slip: 0, limit: 1).values[23] == 1, "The first sweep reaches one cell. / Первый проход доходит до одной клетки.")
        precondition(GridWorld.shortestSteps(walls: []) == 7 && GridWorld.shortestSteps(walls: [20]) == 9, "Shortest routes. / Кратчайшие пути.")

        var learner = QLearner(alpha: 0.5, epsilon: 0.1, gamma: 0.95, sarsa: false, seed: 11)
        learner.train(episodes: 300)
        precondition(learner.log.count == 300 && close(learner.q[GridWorld.start].max() ?? 0, 0.5231654031249993), "\(learner.q[GridWorld.start])")
        precondition(learner.log[299].steps == 5 && learner.route.count == 8, "\(learner.route)")
        var sarsa = QLearner(alpha: 0.1, epsilon: 0.2, gamma: 0.95, sarsa: true, seed: 2005)
        sarsa.train(episodes: 400)
        precondition(close(sarsa.q[GridWorld.start].max() ?? 0, 0.04887118178229441), "\(sarsa.q[GridWorld.start])")
        precondition(sarsa.log.filter(\.fell).count == 110, "Falls. / Падения.")
        var walled = QLearner(alpha: 0.5, epsilon: 0.1, gamma: 0.95, sarsa: false, seed: 11)
        walled.walls = [20]
        walled.train(episodes: 400)
        precondition(walled.reachesGoal && walled.route.count - 1 == 9, "It learns the way round a wall. / Учится обходить стену.")

        precondition(close(CorridorModel.exactValue(CorridorModel.bestProbability), -11.657, 0.001), "The best value. / Лучшее значение.")
        let baseline = CorridorModel.reinforce(episodes: 600, rate: pow(2, -10), baselineRate: 1.0 / 64, seed: 3000)
        precondition(close(baseline[599].probability, 0.5200582149463617, 1e-5) && baseline[599].total == -12.0, "\(baseline[599])")
        let plain = CorridorModel.reinforce(episodes: 600, rate: pow(2, -13), baselineRate: 0, seed: 3004)
        precondition(close(plain[599].probability, 0.4302534660000731, 1e-5), "\(plain[599])")
        let broken = CorridorModel.reinforce(episodes: 80, rate: pow(2, -9), baselineRate: 0, seed: 3000)
        precondition(broken[79].probability > 0.99 && close(broken[79].probability, 0.9999999991939696, 1e-5), "\(broken[79])")
        print("RL labs verified. / Тренажёры обучения с подкреплением проверены.")
    }
}
