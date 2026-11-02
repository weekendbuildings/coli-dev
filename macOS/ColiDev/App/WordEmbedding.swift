import Foundation

/// The lesson's skip-gram model: 16 words, vectors of length 3, trained on all neighbour pairs with softmax and cross-entropy.
/// The start comes from the same simple generator as the lesson's program, so the numbers match it exactly.
/// Модель skip-gram из урока: 16 слов, векторы длиной 3, обучение по всем парам соседей. Начало задаёт тот же простой
/// генератор, что в программе урока, поэтому числа совпадают с ней в точности.
struct WordEmbeddingModel: Equatable {
    enum Group: Equatable {
        case animal, food, vehicle, verb, other
    }

    /// The same sentences word for word, so training does not depend on the language. / Предложения совпадают слово в слово, поэтому обучение не зависит от языка.
    static let sentencesEnglish = [
        "cat eats fish", "dog eats meat", "horse eats hay", "cat sleeps home", "dog sleeps home", "horse sleeps home",
        "car drives fast", "train drives fast", "bus drives fast", "car stands here", "train stands here", "bus stands here"
    ]
    static let sentencesRussian = [
        "кот ест рыбу", "пёс ест мясо", "конь ест сено", "кот спит дома", "пёс спит дома", "конь спит дома",
        "машина едет быстро", "поезд едет быстро", "автобус едет быстро", "машина стоит тут", "поезд стоит тут", "автобус стоит тут"
    ]
    static let extraEnglish = ["horse drives fast", "horse stands here"]
    static let extraRussian = ["конь едет быстро", "конь стоит тут"]
    /// How many times the new sentences repeat. / Сколько раз повторяются новые предложения.
    static let extraRepeats = 5
    static let vectorLength = 3
    static let rate = 1.0
    static let seed = 12345
    static let stepLimit = 3000
    static let trainedLoss = 1.0

    private static func tokens(_ lines: [String]) -> [[String]] { lines.map { $0.split(separator: " ").map(String.init) } }

    private static func vocabulary(_ lines: [String]) -> [String] {
        var seen: [String] = []
        for word in tokens(lines).flatMap({ $0 }) where !seen.contains(word) { seen.append(word) }
        return seen
    }

    static let wordsEnglish = vocabulary(sentencesEnglish)
    static let wordsRussian = vocabulary(sentencesRussian)
    static var count: Int { wordsEnglish.count }
    static let cat = wordsEnglish.firstIndex(of: "cat")!
    static let dog = wordsEnglish.firstIndex(of: "dog")!
    static let horse = wordsEnglish.firstIndex(of: "horse")!
    static let car = wordsEnglish.firstIndex(of: "car")!

    static func word(_ index: Int, language: AppLanguage) -> String {
        language == .ru ? wordsRussian[index] : wordsEnglish[index]
    }

    /// Colours chosen by people for the picture. The model never sees them. / Цвета для картинки выбрали люди, модель их не видит.
    static func group(_ index: Int) -> Group {
        switch wordsEnglish[index] {
        case "cat", "dog", "horse": return .animal
        case "fish", "meat", "hay": return .food
        case "car", "train", "bus": return .vehicle
        case "eats", "sleeps", "drives", "stands": return .verb
        default: return .other
        }
    }

    private static func pairs(_ lines: [String]) -> [(Int, Int)] {
        var found: [(Int, Int)] = []
        for line in tokens(lines) {
            for i in line.indices {
                for j in [i - 1, i + 1] where line.indices.contains(j) {
                    found.append((wordsEnglish.firstIndex(of: line[i])!, wordsEnglish.firstIndex(of: line[j])!))
                }
            }
        }
        return found
    }

    private(set) var wordVectors: [[Double]]
    private(set) var neighbourVectors: [[Double]]
    private(set) var history: [Double] = []
    private(set) var extraSentences = false
    /// True if the horse stood nearer the animals when the new sentences arrived. / Истина, если конь был ближе к животным, когда пришли новые предложения.
    private(set) var horseStartedWithAnimals = false
    private var usedPairs: [Int]

    static func == (left: Self, right: Self) -> Bool {
        left.wordVectors == right.wordVectors && left.neighbourVectors == right.neighbourVectors && left.extraSentences == right.extraSentences
    }

    init() {
        var state = Self.seed
        func next() -> Double {
            state = state * 16807 % 2147483647
            return Double(state) / 2147483647 - 0.5
        }
        var words: [[Double]] = []
        for _ in 0..<Self.count { words.append((0..<Self.vectorLength).map { _ in next() }) }
        var neighbours: [[Double]] = []
        for _ in 0..<Self.count { neighbours.append((0..<Self.vectorLength).map { _ in next() }) }
        wordVectors = words
        neighbourVectors = neighbours
        usedPairs = Self.encoded(extra: false)
    }

    /// The pairs of the sentences in use, flattened into one array of indices.
    private static func encoded(extra: Bool) -> [Int] {
        var lines = sentencesEnglish
        if extra {
            for _ in 0..<extraRepeats { lines += extraEnglish }
        }
        return pairs(lines).flatMap { [$0.0, $0.1] }
    }

    private static func dot(_ a: [Double], _ b: [Double]) -> Double {
        var total = 0.0
        for i in a.indices { total += a[i] * b[i] }
        return total
    }

    static func softmax(_ scores: [Double]) -> [Double] {
        let top = scores.max() ?? 0
        let powers = scores.map { exp($0 - top) }
        let total = powers.reduce(0, +)
        return powers.map { $0 / total }
    }

    var steps: Int { history.count }
    var pairCount: Int { usedPairs.count / 2 }

    /// The mean cross-entropy at the current vectors. / Средняя кросс-энтропия при текущих векторах.
    var loss: Double {
        var total = 0.0
        for pair in stride(from: 0, to: usedPairs.count, by: 2) {
            let scores = neighbourVectors.map { Self.dot(wordVectors[usedPairs[pair]], $0) }
            total -= log(Self.softmax(scores)[usedPairs[pair + 1]])
        }
        return total / Double(pairCount)
    }

    func cosine(_ a: Int, _ b: Int) -> Double {
        Self.dot(wordVectors[a], wordVectors[b]) / (Self.dot(wordVectors[a], wordVectors[a]) * Self.dot(wordVectors[b], wordVectors[b])).squareRoot()
    }

    /// The other words from most to least similar. / Остальные слова от самого похожего к наименее похожему.
    func neighbours(of word: Int) -> [Int] {
        (0..<Self.count).filter { $0 != word }.sorted { cosine(word, $0) > cosine(word, $1) }
    }

    var isFinished: Bool { steps >= Self.stepLimit }

    var isTrained: Bool { loss < Self.trainedLoss }

    /// The horse has moved: it now stands nearer a vehicle than an animal, after starting the other way round.
    var horseChangedPlace: Bool { extraSentences && horseStartedWithAnimals && cosine(Self.horse, Self.car) > cosine(Self.horse, Self.cat) }

    /// One step over all pairs: ∂L/∂v_w = Σ (q − p) u, ∂L/∂u = (q − p) v. The history keeps the error before the step.
    mutating func step() {
        guard !isFinished else { return }
        let size = Self.vectorLength
        var gradWords = [[Double]](repeating: [Double](repeating: 0, count: size), count: Self.count)
        var gradNeighbours = gradWords
        let share = 1 / Double(pairCount)
        var total = 0.0
        for pair in stride(from: 0, to: usedPairs.count, by: 2) {
            let word = usedPairs[pair], neighbour = usedPairs[pair + 1]
            let q = Self.softmax(neighbourVectors.map { Self.dot(wordVectors[word], $0) })
            total -= log(q[neighbour]) * share
            for k in 0..<Self.count {
                let difference = q[k] - (k == neighbour ? 1 : 0)
                for i in 0..<size {
                    gradWords[word][i] += difference * neighbourVectors[k][i] * share
                    gradNeighbours[k][i] += difference * wordVectors[word][i] * share
                }
            }
        }
        history.append(total)
        for k in 0..<Self.count {
            for i in 0..<size {
                wordVectors[k][i] -= Self.rate * gradWords[k][i]
                neighbourVectors[k][i] -= Self.rate * gradNeighbours[k][i]
            }
        }
    }

    /// Counts a step without training, for the check of the step limit. / Считает шаг без обучения, для проверки предела шагов.
    mutating func recordStepForCheck() { history.append(0) }

    /// Adds or removes the new sentences. The vectors stay, so the learner sees them move from where they are.
    mutating func setExtraSentences(_ enabled: Bool) {
        guard enabled != extraSentences else { return }
        if enabled { horseStartedWithAnimals = cosine(Self.horse, Self.cat) > cosine(Self.horse, Self.car) }
        extraSentences = enabled
        usedPairs = Self.encoded(extra: enabled)
    }
}
