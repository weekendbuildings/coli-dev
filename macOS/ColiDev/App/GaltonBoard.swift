import Foundation

/// A true Galton board: each ball makes one independent random choice per row, and the bins count where they land.
/// Настоящая доска Гальтона: шарик делает по одному независимому случайному выбору на ряд, корзины считают, куда он попал.
struct GaltonBoardModel: Equatable {
    static let rowRange: ClosedRange<Int> = 4...14
    /// The task: at this many rows, bring the mean to this bin, on at least this many balls.
    static let challengeRows = 12
    static let challengeMean = 9.0
    static let challengeBalls = 100
    static let challengeTolerance = 0.3

    private(set) var rows: Int
    private(set) var rightChance: Double
    private(set) var bins: [Int]
    private var state: Int

    init(rows: Int = 12, rightChance: Double = 0.5, seed: Int = 20261102) {
        self.rows = rows
        self.rightChance = rightChance
        bins = [Int](repeating: 0, count: rows + 1)
        state = seed
    }

    private mutating func nextRandom() -> Double {
        state = state * 16807 % 2147483647
        return Double(state) / 2147483647
    }

    /// Drops one ball and returns its choices: true means right. / Бросает шарик и возвращает его выборы: true значит вправо.
    @discardableResult
    mutating func drop() -> [Bool] {
        var path: [Bool] = []
        for _ in 0..<rows {
            let choice = nextRandom() < rightChance
            path.append(choice)
        }
        bins[path.filter { $0 }.count] += 1
        return path
    }

    /// Changes the board and empties it, since old balls came from another distribution.
    mutating func configure(rows newRows: Int, rightChance newChance: Double) {
        rows = newRows
        rightChance = newChance
        bins = [Int](repeating: 0, count: newRows + 1)
    }

    var balls: Int { bins.reduce(0, +) }
    var theoryMean: Double { Double(rows) * rightChance }
    var theoryVariance: Double { Double(rows) * rightChance * (1 - rightChance) }

    var sampleMean: Double {
        guard balls > 0 else { return 0 }
        return Double(bins.enumerated().map { $0.offset * $0.element }.reduce(0, +)) / Double(balls)
    }

    var sampleVariance: Double {
        guard balls > 0 else { return 0 }
        let mean = sampleMean
        return bins.enumerated().map { Double($0.element) * pow(Double($0.offset) - mean, 2) }.reduce(0, +) / Double(balls)
    }

    /// The exact binomial probability of a bin. / Точная биномиальная вероятность корзины.
    func theoryChance(bin: Int) -> Double {
        var ways = 1.0
        if bin > 0 {
            for i in 1...bin { ways *= Double(rows - bin + i) / Double(i) }
        }
        return ways * pow(rightChance, Double(bin)) * pow(1 - rightChance, Double(rows - bin))
    }

    var solvesChallenge: Bool {
        rows == Self.challengeRows && balls >= Self.challengeBalls && abs(sampleMean - Self.challengeMean) <= Self.challengeTolerance
    }
}
