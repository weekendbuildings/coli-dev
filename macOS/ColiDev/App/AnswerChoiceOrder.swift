import Foundation

struct AnswerChoiceOrder: Equatable {
    private(set) var displayedOriginalIndices: [Int]

    init(optionCount: Int) {
        var generator = SystemRandomNumberGenerator()
        self.init(optionCount: optionCount, using: &generator)
    }

    init<Generator: RandomNumberGenerator>(optionCount: Int, using generator: inout Generator) {
        precondition(optionCount > 0, "A multiple-choice question needs at least one option.")
        displayedOriginalIndices = Array(0..<optionCount).shuffled(using: &generator)
    }

    init<Generator: RandomNumberGenerator>(
        optionCount: Int,
        placingOriginalIndex originalIndex: Int,
        atDisplayedIndex displayedIndex: Int,
        using generator: inout Generator
    ) {
        precondition(
            optionCount > 0 && (0..<optionCount).contains(originalIndex) && (0..<optionCount).contains(displayedIndex),
            "A pinned answer must refer to a valid option and display slot. / Закреплённый ответ должен ссылаться на существующий вариант и позицию."
        )

        var displayedIndices = Array<Int?>(repeating: nil, count: optionCount)
        displayedIndices[displayedIndex] = originalIndex
        var distractors = (0..<optionCount).filter { $0 != originalIndex }
        distractors.shuffle(using: &generator)

        var distractorIndex = 0
        for index in displayedIndices.indices where displayedIndices[index] == nil {
            displayedIndices[index] = distractors[distractorIndex]
            distractorIndex += 1
        }
        self.displayedOriginalIndices = displayedIndices.map { $0! }
    }

    mutating func reshuffle() {
        var generator = SystemRandomNumberGenerator()
        reshuffle(using: &generator)
    }

    mutating func reshuffle<Generator: RandomNumberGenerator>(using generator: inout Generator) {
        displayedOriginalIndices = Array(displayedOriginalIndices.indices).shuffled(using: &generator)
    }

    func originalIndex(forDisplayedIndex index: Int) -> Int? {
        guard displayedOriginalIndices.indices.contains(index) else { return nil }
        return displayedOriginalIndices[index]
    }

    func isCorrect(displayedIndex: Int, answerOriginalIndex: Int) -> Bool {
        originalIndex(forDisplayedIndex: displayedIndex) == answerOriginalIndex
    }
}

struct QuizAnswerOrder: Equatable {
    let answerOriginalIndex: Int
    private let choiceOrder: AnswerChoiceOrder

    var displayedOriginalIndices: [Int] { choiceOrder.displayedOriginalIndices }
    var correctDisplayedIndex: Int { displayedOriginalIndices.firstIndex(of: answerOriginalIndex)! }

    init(optionCount: Int, answerOriginalIndex: Int) {
        precondition(optionCount > 0 && (0..<optionCount).contains(answerOriginalIndex), "The answer index must match an option.")
        var generator = SystemRandomNumberGenerator()
        self.init(optionCount: optionCount, answerOriginalIndex: answerOriginalIndex, using: &generator)
    }

    init<Generator: RandomNumberGenerator>(
        optionCount: Int,
        answerOriginalIndex: Int,
        using generator: inout Generator
    ) {
        precondition(optionCount > 0 && (0..<optionCount).contains(answerOriginalIndex), "The answer index must match an option.")
        self.answerOriginalIndex = answerOriginalIndex
        choiceOrder = AnswerChoiceOrder(optionCount: optionCount, using: &generator)
    }

    fileprivate init<Generator: RandomNumberGenerator>(
        optionCount: Int,
        answerOriginalIndex: Int,
        correctDisplayedIndex: Int,
        using generator: inout Generator
    ) {
        precondition(
            optionCount > 0 && (0..<optionCount).contains(answerOriginalIndex) && (0..<optionCount).contains(correctDisplayedIndex),
            "A balanced answer slot must refer to a valid option. / Сбалансированная позиция должна ссылаться на существующий вариант."
        )
        self.answerOriginalIndex = answerOriginalIndex
        choiceOrder = AnswerChoiceOrder(
            optionCount: optionCount,
            placingOriginalIndex: answerOriginalIndex,
            atDisplayedIndex: correctDisplayedIndex,
            using: &generator
        )
    }

    static func balancedSequence(optionCount: Int, answerOriginalIndices: [Int]) -> [QuizAnswerOrder] {
        var generator = SystemRandomNumberGenerator()
        return balancedSequence(optionCount: optionCount, answerOriginalIndices: answerOriginalIndices, using: &generator)
    }

    static func balancedSequence<Generator: RandomNumberGenerator>(
        optionCount: Int,
        answerOriginalIndices: [Int],
        using generator: inout Generator
    ) -> [QuizAnswerOrder] {
        precondition(optionCount > 0, "A multiple-choice question needs at least one option.")

        var positionCounts = Array(repeating: 0, count: optionCount)
        var previousPosition: Int?
        var orders: [QuizAnswerOrder] = []
        orders.reserveCapacity(answerOriginalIndices.count)

        for answerOriginalIndex in answerOriginalIndices {
            precondition(
                (0..<optionCount).contains(answerOriginalIndex),
                "Every answer must match an available option. / Каждый правильный ответ должен соответствовать одному из вариантов."
            )

            var eligiblePositions = Array(0..<optionCount)
            if optionCount > 1, let previousPosition {
                eligiblePositions.removeAll { $0 == previousPosition }
            }
            let leastUsedCount = eligiblePositions.map { positionCounts[$0] }.min()!
            let leastUsedPositions = eligiblePositions.filter { positionCounts[$0] == leastUsedCount }
            let displayedIndex = leastUsedPositions.randomElement(using: &generator)!

            orders.append(QuizAnswerOrder(
                optionCount: optionCount,
                answerOriginalIndex: answerOriginalIndex,
                correctDisplayedIndex: displayedIndex,
                using: &generator
            ))
            positionCounts[displayedIndex] += 1
            previousPosition = displayedIndex
        }

        return orders
    }

    func originalIndex(forDisplayedIndex index: Int) -> Int? {
        choiceOrder.originalIndex(forDisplayedIndex: index)
    }

    func isCorrect(displayedIndex: Int) -> Bool {
        choiceOrder.isCorrect(displayedIndex: displayedIndex, answerOriginalIndex: answerOriginalIndex)
    }
}

struct QuizAnswerOrderSequence {
    private let optionCount: Int
    private var positionCounts: [Int]
    private var previousPosition: Int?

    init(optionCount: Int) {
        precondition(optionCount > 0, "A multiple-choice sequence needs at least one option.")
        self.optionCount = optionCount
        positionCounts = Array(repeating: 0, count: optionCount)
    }

    mutating func nextOrder(
        answerOriginalIndex: Int,
        following previousOrder: QuizAnswerOrder? = nil
    ) -> QuizAnswerOrder {
        var generator = SystemRandomNumberGenerator()
        return nextOrder(
            answerOriginalIndex: answerOriginalIndex,
            following: previousOrder,
            using: &generator
        )
    }

    mutating func nextOrder<Generator: RandomNumberGenerator>(
        answerOriginalIndex: Int,
        following previousOrder: QuizAnswerOrder? = nil,
        using generator: inout Generator
    ) -> QuizAnswerOrder {
        precondition(
            (0..<optionCount).contains(answerOriginalIndex),
            "The answer must match an available option. / Правильный ответ должен соответствовать одному из вариантов."
        )

        if previousPosition == nil, let previousOrder {
            precondition(
                previousOrder.displayedOriginalIndices.count == optionCount,
                "The previous quiz must have the same option count. / В предыдущем вопросе должно быть столько же вариантов."
            )
            let previousDisplayedIndex = previousOrder.correctDisplayedIndex
            positionCounts[previousDisplayedIndex] += 1
            previousPosition = previousDisplayedIndex
        }

        var eligiblePositions = Array(0..<optionCount)
        if optionCount > 1, let previousPosition {
            eligiblePositions.removeAll { $0 == previousPosition }
        }
        let leastUsedCount = eligiblePositions.map { positionCounts[$0] }.min()!
        let leastUsedPositions = eligiblePositions.filter { positionCounts[$0] == leastUsedCount }
        let displayedIndex = leastUsedPositions.randomElement(using: &generator)!
        positionCounts[displayedIndex] += 1
        previousPosition = displayedIndex

        return QuizAnswerOrder(
            optionCount: optionCount,
            answerOriginalIndex: answerOriginalIndex,
            correctDisplayedIndex: displayedIndex,
            using: &generator
        )
    }
}

enum StudyErrorCategory: String, CaseIterable, Codable, Equatable, Identifiable {
    case understanding
    case memory
    case application
    case attention
    case logic
    case foundation
    case method

    var id: String { rawValue }
    var titleKey: String { "module.errorCategory.\(rawValue)" }
    var guidanceKey: String { "module.errorGuidance.\(rawValue)" }
}

struct CurriculumCheckAttempt: Equatable {
    let answerOriginalIndex: Int
    let itemID: String
    private(set) var choiceOrder: AnswerChoiceOrder
    private(set) var selectedOriginalIndex: Int?
    private(set) var attemptCount: Int
    private(set) var firstTryCorrect: Bool?
    private(set) var reportedErrorCategories: [StudyErrorCategory]

    var isCorrect: Bool { selectedOriginalIndex == answerOriginalIndex }
    var canComplete: Bool { isCorrect }
    var canRetry: Bool { selectedOriginalIndex != nil && !isCorrect }
    var hasAnswered: Bool { selectedOriginalIndex != nil }
    var assessmentEvidence: StudyAssessmentEvidence? {
        guard canComplete, attemptCount > 0, let firstTryCorrect else { return nil }
        return StudyAssessmentEvidence(
            taskType: "knowledge_check",
            attempts: attemptCount,
            firstTryCorrect: firstTryCorrect,
            hintsUsed: 0,
            errorCategories: reportedErrorCategories.isEmpty ? nil : reportedErrorCategories,
            itemID: itemID
        )
    }

    func currentAnswerEventEvidence(errorCategory: StudyErrorCategory? = nil) -> StudyAssessmentEvidence? {
        guard hasAnswered else { return nil }
        return StudyAssessmentEvidence(
            taskType: "knowledge_check",
            attempts: 1,
            firstTryCorrect: isCorrect,
            hintsUsed: 0,
            errorCategories: errorCategory.map { [$0] },
            passed: isCorrect,
            itemID: itemID
        )
    }

    init?(optionCount: Int, answerOriginalIndex: Int, itemID: String) {
        var generator = SystemRandomNumberGenerator()
        self.init(optionCount: optionCount, answerOriginalIndex: answerOriginalIndex, itemID: itemID, using: &generator)
    }

    init?<Generator: RandomNumberGenerator>(
        optionCount: Int,
        answerOriginalIndex: Int,
        itemID: String,
        using generator: inout Generator
    ) {
        guard optionCount > 0, (0..<optionCount).contains(answerOriginalIndex) else { return nil }
        self.answerOriginalIndex = answerOriginalIndex
        self.itemID = itemID
        choiceOrder = AnswerChoiceOrder(optionCount: optionCount, using: &generator)
        selectedOriginalIndex = nil
        attemptCount = 0
        firstTryCorrect = nil
        reportedErrorCategories = []
    }

    mutating func select(displayedIndex: Int) {
        guard !hasAnswered,
              let originalIndex = choiceOrder.originalIndex(forDisplayedIndex: displayedIndex) else { return }
        selectedOriginalIndex = originalIndex
        attemptCount += 1
        if firstTryCorrect == nil {
            firstTryCorrect = originalIndex == answerOriginalIndex
        }
    }

    mutating func retry(errorCategory: StudyErrorCategory? = nil) {
        var generator = SystemRandomNumberGenerator()
        retry(errorCategory: errorCategory, using: &generator)
    }

    mutating func retry<Generator: RandomNumberGenerator>(
        errorCategory: StudyErrorCategory? = nil,
        using generator: inout Generator
    ) {
        guard canRetry else { return }
        if let errorCategory {
            reportedErrorCategories.append(errorCategory)
        }
        choiceOrder = AnswerChoiceOrder(optionCount: choiceOrder.displayedOriginalIndices.count, using: &generator)
        selectedOriginalIndex = nil
    }
}

struct InteractivePredictionAttempt: Equatable {
    let answerOriginalIndex: Int
    let itemID: String?
    private(set) var choiceOrder: AnswerChoiceOrder
    private(set) var selectedOriginalIndex: Int?
    private(set) var attemptCount: Int
    private(set) var firstTryCorrect: Bool?
    private(set) var hintsUsed: Int

    var hasAnswered: Bool { selectedOriginalIndex != nil }
    var isCorrect: Bool { selectedOriginalIndex == answerOriginalIndex }
    var canRetry: Bool { hasAnswered && !isCorrect }

    init?(optionCount: Int, answerOriginalIndex: Int, itemID: String? = nil) {
        var generator = SystemRandomNumberGenerator()
        self.init(
            optionCount: optionCount,
            answerOriginalIndex: answerOriginalIndex,
            itemID: itemID,
            using: &generator
        )
    }

    init?<Generator: RandomNumberGenerator>(
        optionCount: Int,
        answerOriginalIndex: Int,
        itemID: String? = nil,
        using generator: inout Generator
    ) {
        guard optionCount > 0, (0..<optionCount).contains(answerOriginalIndex) else { return nil }
        self.answerOriginalIndex = answerOriginalIndex
        self.itemID = itemID
        choiceOrder = AnswerChoiceOrder(optionCount: optionCount, using: &generator)
        selectedOriginalIndex = nil
        attemptCount = 0
        firstTryCorrect = nil
        hintsUsed = 0
    }

    mutating func select(displayedIndex: Int) {
        guard !hasAnswered,
              let originalIndex = choiceOrder.originalIndex(forDisplayedIndex: displayedIndex) else { return }
        selectedOriginalIndex = originalIndex
        attemptCount += 1
        if firstTryCorrect == nil {
            firstTryCorrect = originalIndex == answerOriginalIndex
        }
        if originalIndex != answerOriginalIndex {
            hintsUsed += 1
        }
    }

    mutating func retry() {
        var generator = SystemRandomNumberGenerator()
        retry(using: &generator)
    }

    mutating func retry<Generator: RandomNumberGenerator>(using generator: inout Generator) {
        guard canRetry else { return }
        choiceOrder = AnswerChoiceOrder(optionCount: choiceOrder.displayedOriginalIndices.count, using: &generator)
        selectedOriginalIndex = nil
    }

    func currentAnswerEventEvidence() -> StudyAssessmentEvidence? {
        guard hasAnswered, let firstTryCorrect else { return nil }
        return StudyAssessmentEvidence(
            taskType: "interactive_prediction",
            attempts: attemptCount,
            firstTryCorrect: firstTryCorrect,
            hintsUsed: hintsUsed,
            itemID: itemID
        )
    }
}

enum OsmosisWaterFlow: Equatable {
    case waterEntersCell
    case waterLeavesCell
    case dynamicEquilibrium

    var answerOriginalIndex: Int {
        switch self {
        case .waterEntersCell: return 0
        case .waterLeavesCell: return 1
        case .dynamicEquilibrium: return 2
        }
    }

    var explanationKey: String {
        switch self {
        case .waterEntersCell: return "lab.osmosisWaterEnters"
        case .waterLeavesCell: return "lab.osmosisWaterLeaves"
        case .dynamicEquilibrium: return "lab.osmosisBalanced"
        }
    }

    var arrowSymbol: String {
        switch self {
        case .waterEntersCell: return "arrow.right"
        case .waterLeavesCell: return "arrow.left"
        case .dynamicEquilibrium: return "arrow.left.and.right"
        }
    }

    /// Net water flow goes toward the side with more non-penetrating solute.
    /// Чистый поток воды идёт к стороне, где больше непроникающего растворённого вещества.
    static func predict(insideSolute: Int, outsideSolute: Int) -> Self {
        if insideSolute > outsideSolute { return .waterEntersCell }
        if outsideSolute > insideSolute { return .waterLeavesCell }
        return .dynamicEquilibrium
    }
}

struct StudyAssessmentEvidence: Codable, Equatable {
    let taskType: String
    let itemID: String?
    let attempts: Int
    let firstTryCorrect: Bool
    let hintsUsed: Int
    let errorCategories: [StudyErrorCategory]?
    let passed: Bool?

    init(
        taskType: String,
        attempts: Int,
        firstTryCorrect: Bool,
        hintsUsed: Int,
        errorCategories: [StudyErrorCategory]? = nil,
        passed: Bool? = nil,
        itemID: String? = nil
    ) {
        self.taskType = taskType
        self.itemID = itemID
        self.attempts = attempts
        self.firstTryCorrect = firstTryCorrect
        self.hintsUsed = hintsUsed
        self.errorCategories = errorCategories
        self.passed = passed
    }

    // The backend stores knowledge checks in the compact form {task_type, passed, error_categories?, item_id?}
    // and returns it in progress records and evidence summaries, so attempt fields are optional for that type.
    // Бэкенд хранит проверки знаний в сжатом виде без полей попытки и так же возвращает их в прогрессе.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let taskType = try container.decode(String.self, forKey: .taskType)
        let itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        let errorCategories = try container.decodeIfPresent([StudyErrorCategory].self, forKey: .errorCategories)
        let passed = try container.decodeIfPresent(Bool.self, forKey: .passed)
        if container.contains(.attempts) {
            self.init(
                taskType: taskType,
                attempts: try container.decode(Int.self, forKey: .attempts),
                firstTryCorrect: try container.decode(Bool.self, forKey: .firstTryCorrect),
                hintsUsed: try container.decode(Int.self, forKey: .hintsUsed),
                errorCategories: errorCategories,
                passed: passed,
                itemID: itemID
            )
        } else if taskType == "knowledge_check", let passed {
            self.init(
                taskType: taskType,
                attempts: 1,
                firstTryCorrect: passed,
                hintsUsed: 0,
                errorCategories: errorCategories,
                passed: passed,
                itemID: itemID
            )
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.attempts,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Interactive assessments need attempt evidence; knowledge checks need a pass result. / Для интерактивных заданий нужны данные попытки, для проверки знаний — итоговый результат.")
            )
        }
    }

    enum CodingKeys: String, CodingKey {
        case taskType = "task_type"
        case itemID = "item_id"
        case attempts
        case firstTryCorrect = "first_try_correct"
        case hintsUsed = "hints_used"
        case errorCategories = "error_categories"
        case passed
    }
}

struct InteractiveChoiceAssessmentTracker {
    private struct ItemState {
        var attempts = 0
        var firstTryCorrect: Bool?
        var lastSubmittedAnswerIndex: Int?
        var correctAnswerIndex: Int?
        var optionCount: Int?
    }

    private let itemIDs: Set<String>
    private var itemStates: [String: ItemState] = [:]

    init(itemIDs: [String]) {
        self.itemIDs = Set(itemIDs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    mutating func recordSubmission(
        selectedAnswerIndex: Int,
        correctAnswerIndex: Int,
        optionCount: Int,
        itemID: String
    ) -> StudyAssessmentEvidence? {
        guard itemIDs.contains(itemID),
              optionCount > 1,
              (0..<optionCount).contains(selectedAnswerIndex),
              (0..<optionCount).contains(correctAnswerIndex) else {
            return nil
        }

        var state = itemStates[itemID] ?? ItemState()
        if let knownCorrectAnswer = state.correctAnswerIndex, knownCorrectAnswer != correctAnswerIndex {
            return nil
        }
        if let knownOptionCount = state.optionCount, knownOptionCount != optionCount {
            return nil
        }
        guard state.lastSubmittedAnswerIndex != selectedAnswerIndex else { return nil }

        let isCorrect = selectedAnswerIndex == correctAnswerIndex
        state.attempts += 1
        if state.firstTryCorrect == nil {
            state.firstTryCorrect = isCorrect
        }
        state.lastSubmittedAnswerIndex = selectedAnswerIndex
        state.correctAnswerIndex = correctAnswerIndex
        state.optionCount = optionCount
        itemStates[itemID] = state

        return StudyAssessmentEvidence(
            taskType: "interactive_practice",
            attempts: state.attempts,
            firstTryCorrect: state.firstTryCorrect ?? isCorrect,
            hintsUsed: 0,
            itemID: itemID
        )
    }

    mutating func reset() {
        itemStates.removeAll()
    }
}

struct FrictionPredictionQuestion: Equatable, Identifiable {
    let id: String
    let appliedForce: Double
    let expectedSliding: Bool

    var correctOptionIndex: Int { expectedSliding ? 1 : 0 }
}

enum FrictionPredictionFeedback: Equatable {
    case correct
    case review
}

struct FrictionPredictionPracticeSession {
    static let questions = [
        FrictionPredictionQuestion(id: "friction.at-15n", appliedForce: 15, expectedSliding: false),
        FrictionPredictionQuestion(id: "friction.at-25n", appliedForce: 25, expectedSliding: true)
    ]

    private(set) var questionIndex = 0
    private(set) var selectedDisplayedIndex: Int?
    private(set) var feedback: FrictionPredictionFeedback?
    private(set) var isComplete = false

    private var optionOrders: [QuizAnswerOrder]
    private var assessmentTracker: InteractiveChoiceAssessmentTracker

    init() {
        optionOrders = Self.makeOptionOrders()
        assessmentTracker = InteractiveChoiceAssessmentTracker(itemIDs: Self.questions.map(\.id))
    }

    var currentQuestion: FrictionPredictionQuestion? {
        guard !isComplete, Self.questions.indices.contains(questionIndex) else { return nil }
        return Self.questions[questionIndex]
    }

    var currentOptionOriginalIndices: [Int] {
        guard currentQuestion != nil else { return [] }
        return optionOrders[questionIndex].displayedOriginalIndices
    }

    mutating func selectOption(at displayedIndex: Int) {
        guard feedback != .correct,
              currentOptionOriginalIndices.indices.contains(displayedIndex) else {
            return
        }
        selectedDisplayedIndex = displayedIndex
        feedback = nil
    }

    mutating func checkAnswer() -> StudyAssessmentEvidence? {
        guard feedback != .correct,
              let question = currentQuestion,
              let selectedDisplayedIndex,
              currentOptionOriginalIndices.indices.contains(selectedDisplayedIndex) else {
            return nil
        }

        let selectedOriginalIndex = currentOptionOriginalIndices[selectedDisplayedIndex]
        feedback = selectedOriginalIndex == question.correctOptionIndex ? .correct : .review
        return assessmentTracker.recordSubmission(
            selectedAnswerIndex: selectedOriginalIndex,
            correctAnswerIndex: question.correctOptionIndex,
            optionCount: 2,
            itemID: question.id
        )
    }

    mutating func advance() {
        guard feedback == .correct, currentQuestion != nil else { return }
        if questionIndex == Self.questions.count - 1 {
            isComplete = true
        } else {
            questionIndex += 1
        }
        selectedDisplayedIndex = nil
        feedback = nil
    }

    mutating func restart() {
        questionIndex = 0
        selectedDisplayedIndex = nil
        feedback = nil
        isComplete = false
        optionOrders = Self.makeOptionOrders()
        assessmentTracker.reset()
    }

    private static func makeOptionOrders() -> [QuizAnswerOrder] {
        QuizAnswerOrder.balancedSequence(
            optionCount: 2,
            answerOriginalIndices: questions.map(\.correctOptionIndex)
        )
    }
}

struct StudyAssessmentEvent: Codable, Identifiable {
    let id: String
    let lessonID: String
    let assessment: StudyAssessmentEvidence

    enum CodingKeys: String, CodingKey {
        case id = "event_id"
        case lessonID = "lesson_id"
        case assessment
    }

    init(id: String, lessonID: String, assessment: StudyAssessmentEvidence) {
        self.id = id
        self.lessonID = lessonID
        self.assessment = assessment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        lessonID = try container.decode(String.self, forKey: .lessonID)
        assessment = try container.decode(StudyAssessmentEvidence.self, forKey: .assessment)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(lessonID, forKey: .lessonID)

        var assessmentContainer = container.nestedContainer(keyedBy: AssessmentCodingKeys.self, forKey: .assessment)
        try assessmentContainer.encode(assessment.taskType, forKey: .taskType)
        if assessment.taskType == "knowledge_check" {
            guard let passed = assessment.passed else {
                throw EncodingError.invalidValue(
                    assessment,
                    EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Knowledge-check events need a pass result. / Для проверки знаний нужен итоговый результат.")
                )
            }
            try assessmentContainer.encode(passed, forKey: .passed)
            try assessmentContainer.encodeIfPresent(assessment.errorCategories, forKey: .errorCategories)
            try assessmentContainer.encodeIfPresent(assessment.itemID, forKey: .itemID)
        } else if assessment.taskType == "interactive_prediction" || assessment.taskType == "interactive_practice" {
            try assessmentContainer.encode(assessment.attempts, forKey: .attempts)
            try assessmentContainer.encode(assessment.firstTryCorrect, forKey: .firstTryCorrect)
            try assessmentContainer.encode(assessment.hintsUsed, forKey: .hintsUsed)
            try assessmentContainer.encodeIfPresent(assessment.itemID, forKey: .itemID)
            try assessmentContainer.encodeIfPresent(assessment.errorCategories, forKey: .errorCategories)
        } else {
            throw EncodingError.invalidValue(
                assessment.taskType,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported assessment event type. / Неподдерживаемый тип события проверки знаний.")
            )
        }
    }

    private enum AssessmentCodingKeys: String, CodingKey {
        case taskType = "task_type"
        case itemID = "item_id"
        case attempts
        case firstTryCorrect = "first_try_correct"
        case hintsUsed = "hints_used"
        case errorCategories = "error_categories"
        case passed
    }
}

struct LessonAnswerFeedback: Equatable {
    let statusMessage: String
    let explanation: String?
    let canRevealExplanation: Bool

    static func presentation(
        isCorrect: Bool,
        explanationRevealed: Bool = false,
        explanation: String,
        correctPrompt: String,
        retryPrompt: String
    ) -> LessonAnswerFeedback {
        let cleanedExplanation = explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        let availableExplanation = cleanedExplanation.isEmpty ? nil : cleanedExplanation

        if isCorrect {
            return LessonAnswerFeedback(
                statusMessage: correctPrompt,
                explanation: availableExplanation,
                canRevealExplanation: false
            )
        }

        return LessonAnswerFeedback(
            statusMessage: retryPrompt,
            explanation: explanationRevealed ? availableExplanation : nil,
            canRevealExplanation: !explanationRevealed && availableExplanation != nil
        )
    }
}

enum TenseContrastFeedback {
    static func explanationKey(scenario: Int, isCorrect: Bool) -> String? {
        guard (0...1).contains(scenario) else { return nil }
        return "lab.tenseExplanation.\(scenario).\(isCorrect ? "correct" : "incorrect")"
    }
}

enum GeneRegulationPractice {
    static func predictionItemID(variant: Int, signalPresent: Bool) -> String {
        let signal = signalPresent ? "present" : "absent"
        return "biology.gene_regulation.variant-\(variant).signal-\(signal)"
    }

    static func isProductMade(variant: Int, signalPresent: Bool) -> Bool {
        variant == 0 && signalPresent
    }

    static func correctPredictionAnswerOriginalIndex(variant: Int, signalPresent: Bool) -> Int {
        isProductMade(variant: variant, signalPresent: signalPresent) ? 0 : 1
    }

    static func geneActivityKey(productMade: Bool, outcomeRevealed: Bool) -> String {
        guard outcomeRevealed else { return "lab.dnaOutcomeHidden" }
        return productMade ? "lab.dnaGeneOn" : "lab.dnaGeneOff"
    }

    static func productKey(productMade: Bool, outcomeRevealed: Bool) -> String {
        guard outcomeRevealed else { return "lab.dnaOutcomeHidden" }
        return productMade ? "lab.dnaProductMade" : "lab.dnaProductAbsent"
    }

    static func makePredictionAttempt(variant: Int, signalPresent: Bool) -> InteractivePredictionAttempt {
        guard let attempt = InteractivePredictionAttempt(
            optionCount: 2,
            answerOriginalIndex: correctPredictionAnswerOriginalIndex(
                variant: variant,
                signalPresent: signalPresent
            ),
            itemID: predictionItemID(variant: variant, signalPresent: signalPresent)
        ) else {
            preconditionFailure("A valid gene-regulation scenario must produce a prediction attempt. / Для корректного сценария регуляции гена должна создаваться попытка прогноза.")
        }
        return attempt
    }

    static func explanationKey(isCorrect: Bool) -> String {
        isCorrect ? "lab.dnaPredictExplanation.correct" : "lab.dnaPredictExplanation.incorrect"
    }
}
