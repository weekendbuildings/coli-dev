import Foundation

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

func verifyBalancedPracticeSequence(
    name: String,
    optionCount: Int,
    answerOriginalIndices: [Int],
    seed: UInt64
) {
    var generator = SeededGenerator(seed: seed)
    let orders = QuizAnswerOrder.balancedSequence(
        optionCount: optionCount,
        answerOriginalIndices: answerOriginalIndices,
        using: &generator
    )
    let positions = orders.map(\.correctDisplayedIndex)
    let counts = (0..<optionCount).map { position in positions.filter { $0 == position }.count }
    precondition(
        positions.count == answerOriginalIndices.count
            && zip(positions, positions.dropFirst()).allSatisfy { $0.0 != $0.1 }
            && counts.max()! - counts.min()! <= 1,
        "\(name): answer positions must be balanced and not repeat consecutively. / Позиции ответов должны быть сбалансированы и не повторяться подряд."
    )
    for (order, answerIndex) in zip(orders, answerOriginalIndices) {
        precondition(
            Set(order.displayedOriginalIndices) == Set(0..<optionCount)
                && order.displayedOriginalIndices[order.correctDisplayedIndex] == answerIndex
                && order.isCorrect(displayedIndex: order.correctDisplayedIndex),
            "\(name): shuffling must preserve all options and the correct answer. / Перемешивание должно сохранять варианты и правильный ответ."
        )
    }
}

func verifyBalancedOrderIsWired(into viewNames: [String]) {
    let source = try! String(contentsOfFile: "macOS/ColiDev/App/LearningViews.swift", encoding: .utf8)
    let lines = source.components(separatedBy: .newlines)
    for viewName in viewNames {
        guard let start = lines.firstIndex(where: { $0.contains("private struct \(viewName): View") }) else {
            preconditionFailure("Missing learner-facing view \(viewName). / Не найден экран тренажёра \(viewName).")
        }
        let end = lines[(start + 1)...].firstIndex(where: { $0.contains("private struct ") }) ?? lines.endIndex
        let viewBody = lines[start..<end].joined(separator: "\n")
        precondition(
            viewBody.contains("QuizAnswerOrder.balancedSequence"),
            "\(viewName) must use the verified balanced-order generator. / Экран \(viewName) должен использовать проверенный генератор сбалансированного порядка."
        )
    }
}

@main
enum AnswerChoiceOrderVerification {
    static func main() {
        verifyBalancedOrderIsWired(into: [
            "ConditionalsLab",
            "ReportedSpeechLab",
            "SQLSchemaQueryLab",
            "GitWorkflowLab",
            "DataStructureChoiceLab"
        ])

        var choiceAssessment = InteractiveChoiceAssessmentTracker(
            itemIDs: [
                "routine-1", "animal-group-1", "lineage-1",
                "missing", "invalid-number", "valid-numbers",
                "name-error", "index-error", "assertion-error",
                "present-simple-continuous.scenario-0", "present-simple-continuous.scenario-1",
                "present-perfect.question-0", "present-perfect.question-1", "present-perfect.question-2"
            ]
        )
        let firstChoice = choiceAssessment.recordSubmission(
            selectedAnswerIndex: 0,
            correctAnswerIndex: 1,
            optionCount: 3,
            itemID: "routine-1"
        )
        precondition(
            firstChoice == StudyAssessmentEvidence(
                taskType: "interactive_practice",
                attempts: 1,
                firstTryCorrect: false,
                hintsUsed: 0,
                itemID: "routine-1"
            ),
            "Record a wrong first choice with stable item identity. / Записывай неверный первый ответ со стабильным ID вопроса."
        )
        precondition(
            choiceAssessment.recordSubmission(
                selectedAnswerIndex: 0,
                correctAnswerIndex: 1,
                optionCount: 3,
                itemID: "routine-1"
            ) == nil,
            "Do not inflate attempts when the same answer is submitted twice. / Не накручивай попытки повторной отправкой того же ответа."
        )
        let choiceRetry = choiceAssessment.recordSubmission(
            selectedAnswerIndex: 1,
            correctAnswerIndex: 1,
            optionCount: 3,
            itemID: "routine-1"
        )
        precondition(
            choiceRetry?.attempts == 2
                && choiceRetry?.firstTryCorrect == false
                && choiceRetry?.itemID == "routine-1",
            "Keep the first result after a correct retry. / Сохраняй результат первой попытки после верного повтора."
        )
        let choiceEvent = StudyAssessmentEvent(
            id: "00000000-0000-0000-0000-000000000003",
            lessonID: "english.daily_routines_and_collocations",
            assessment: choiceRetry!
        )
        let choiceEventData = try! JSONEncoder().encode(choiceEvent)
        let choiceEventObject = try! JSONSerialization.jsonObject(with: choiceEventData) as! [String: Any]
        let choiceAssessmentObject = choiceEventObject["assessment"] as! [String: Any]
        precondition(
            choiceAssessmentObject["task_type"] as? String == "interactive_practice"
                && choiceAssessmentObject["item_id"] as? String == "routine-1"
                && Set(choiceAssessmentObject.keys) == Set(["task_type", "item_id", "attempts", "first_try_correct", "hints_used"]),
            "Choice evidence must use the backend's persisted practice-event contract. / Результат выбора должен соответствовать формату сохраняемого события тренажёра."
        )
        let restoredChoiceEvent = try! JSONDecoder().decode(StudyAssessmentEvent.self, from: choiceEventData)
        precondition(
            restoredChoiceEvent.assessment.itemID == "routine-1" && restoredChoiceEvent.assessment.attempts == 2,
            "Restoring a queued choice event must preserve its question and attempt count. / Восстановление события должно сохранять вопрос и число попыток."
        )
        precondition(
            choiceAssessment.recordSubmission(
                selectedAnswerIndex: 1,
                correctAnswerIndex: 1,
                optionCount: 3,
                itemID: "missing-item"
            ) == nil,
            "Reject unregistered item identities. / Отклоняй незарегистрированные ID вопросов."
        )
        precondition(
            choiceAssessment.recordSubmission(
                selectedAnswerIndex: 3,
                correctAnswerIndex: 1,
                optionCount: 3,
                itemID: "animal-group-1"
            ) == nil,
            "Reject answer indices outside the option range. / Отклоняй номер ответа вне диапазона вариантов."
        )
        let independentChoice = choiceAssessment.recordSubmission(
            selectedAnswerIndex: 2,
            correctAnswerIndex: 2,
            optionCount: 3,
            itemID: "animal-group-1"
        )
        precondition(
            independentChoice?.attempts == 1 && independentChoice?.firstTryCorrect == true,
            "Track independent questions separately. / Веди независимый учёт для разных вопросов."
        )
        let fileReadingChoice = choiceAssessment.recordSubmission(
            selectedAnswerIndex: 0,
            correctAnswerIndex: 1,
            optionCount: 3,
            itemID: "missing"
        )
        precondition(
            fileReadingChoice?.taskType == "interactive_practice" && fileReadingChoice?.itemID == "missing",
            "Accept registered file-reading scenarios. / Принимай зарегистрированные сценарии чтения файла."
        )
        let debuggingChoice = choiceAssessment.recordSubmission(
            selectedAnswerIndex: 2,
            correctAnswerIndex: 0,
            optionCount: 3,
            itemID: "name-error"
        )
        precondition(
            debuggingChoice?.attempts == 1 && debuggingChoice?.firstTryCorrect == false,
            "Accept registered debugging scenarios. / Принимай зарегистрированные сценарии отладки."
        )
        let twoChoicePractice = choiceAssessment.recordSubmission(
            selectedAnswerIndex: 0,
            correctAnswerIndex: 0,
            optionCount: 2,
            itemID: "present-simple-continuous.scenario-0"
        )
        precondition(
            twoChoicePractice?.attempts == 1 && twoChoicePractice?.firstTryCorrect == true,
            "Support binary grammar practice independently from three-choice items. / Поддерживай двухвариантные грамматические задания отдельно от тестов с тремя вариантами."
        )
        precondition(
            choiceAssessment.recordSubmission(
                selectedAnswerIndex: 1,
                correctAnswerIndex: 1,
                optionCount: 2,
                itemID: "present-simple-continuous.scenario-0"
            ) == nil,
            "Reject a changed answer key within one active attempt. / Не принимай изменившийся ключ ответа внутри одной попытки."
        )
        let presentPerfectChoice = choiceAssessment.recordSubmission(
            selectedAnswerIndex: 1,
            correctAnswerIndex: 0,
            optionCount: 2,
            itemID: "present-perfect.question-0"
        )
        precondition(
            presentPerfectChoice?.attempts == 1 && presentPerfectChoice?.firstTryCorrect == false,
            "Track each present-perfect scenario independently. / Веди отдельный учёт для каждого сценария Present Perfect."
        )
        choiceAssessment.reset()
        let resetChoice = choiceAssessment.recordSubmission(
            selectedAnswerIndex: 2,
            correctAnswerIndex: 2,
            optionCount: 3,
            itemID: "routine-1"
        )
        precondition(
            resetChoice?.attempts == 1 && resetChoice?.firstTryCorrect == true,
            "A restarted activity begins a fresh in-memory attempt. / После перезапуска тренажёра начинается новая серия попыток."
        )

        let osmosisScenarios: [(inside: Int, outside: Int, expected: OsmosisWaterFlow, optionIndex: Int)] = [
            (inside: 4, outside: 6, expected: .waterLeavesCell, optionIndex: 1),
            (inside: 6, outside: 4, expected: .waterEntersCell, optionIndex: 0),
            (inside: 4, outside: 4, expected: .dynamicEquilibrium, optionIndex: 2)
        ]
        for scenario in osmosisScenarios {
            let prediction = OsmosisWaterFlow.predict(
                insideSolute: scenario.inside,
                outsideSolute: scenario.outside
            )
            precondition(
                prediction == scenario.expected && prediction.answerOriginalIndex == scenario.optionIndex,
                "Osmosis predictions must match the three learner-facing options. / Прогноз осмоса должен соответствовать трём вариантам ответа ученика."
            )
        }

        for optionCount in [2, 3] {
            let correctOriginalIndices = [1, 1, 2, 2, 1, 0, 2, 1, 0, 0, 2, 1, 2, 0, 1, 1, 2]
                .map { $0 % optionCount }

            for seed in 0..<64 {
                var generator = SeededGenerator(seed: UInt64(seed))
                let sequence = QuizAnswerOrder.balancedSequence(
                    optionCount: optionCount,
                    answerOriginalIndices: correctOriginalIndices,
                    using: &generator
                )
                let correctPositions = sequence.map(\.correctDisplayedIndex)
                let positionCounts = (0..<optionCount).map { position in
                    correctPositions.filter { $0 == position }.count
                }

                precondition(
                    zip(correctPositions, correctPositions.dropFirst()).allSatisfy { $0.0 != $0.1 },
                    "Correct answer positions must not repeat consecutively. / Позиция правильного ответа не должна повторяться подряд."
                )
                precondition(
                    positionCounts.max()! - positionCounts.min()! <= 1,
                    "Correct answer positions must stay balanced within a question sequence. / Позиции правильных ответов должны равномерно распределяться в серии вопросов."
                )

                for (order, answerIndex) in zip(sequence, correctOriginalIndices) {
                    precondition(
                        Set(order.displayedOriginalIndices) == Set(0..<optionCount),
                        "Every balanced quiz must keep all options exactly once. / В каждом тесте все варианты должны встретиться ровно один раз."
                    )
                    precondition(
                        order.isCorrect(displayedIndex: order.correctDisplayedIndex)
                            && order.displayedOriginalIndices[order.correctDisplayedIndex] == answerIndex,
                        "Balancing must preserve the original correct answer. / Балансировка должна сохранять исходный правильный ответ."
                    )
                }
            }
        }

        verifyBalancedPracticeSequence(
            name: "English conditionals / Условные предложения",
            optionCount: EnglishConditionalForm.allCases.count,
            answerOriginalIndices: EnglishConditionalPractice.scenarios.map { $0.correctForm.rawValue },
            seed: 301
        )
        verifyBalancedPracticeSequence(
            name: "Reported speech / Косвенная речь",
            optionCount: 3,
            answerOriginalIndices: EnglishReportedSpeechPractice.questions.map(\.correctOption),
            seed: 302
        )
        verifyBalancedPracticeSequence(
            name: "SQL query practice / Практика SQL",
            optionCount: SQLQueryPractice.steps[0].optionKeys.count,
            answerOriginalIndices: SQLQueryPractice.steps.map(\.correctOptionIndex),
            seed: 303
        )
        verifyBalancedPracticeSequence(
            name: "Git workflow / Работа с Git",
            optionCount: GitWorkflowPractice.steps[0].commandKeys.count,
            answerOriginalIndices: GitWorkflowPractice.steps.map(\.correctCommandIndex),
            seed: 304
        )
        verifyBalancedPracticeSequence(
            name: "Data structures / Структуры данных",
            optionCount: DataStructureChoicePractice.scenarios[0].optionKeys.count,
            answerOriginalIndices: DataStructureChoicePractice.scenarios.map(\.correctOptionIndex),
            seed: 305
        )

        for optionCount in [2, 3] {
            let correctOriginalIndices = [1, 1, 2, 0, 2, 1, 0, 0, 2, 1, 1, 2, 0]
                .map { $0 % optionCount }
            var sequence = QuizAnswerOrderSequence(optionCount: optionCount)
            var generator = SeededGenerator(seed: UInt64(optionCount * 101))
            let orders: [QuizAnswerOrder] = correctOriginalIndices.map { answerIndex in
                sequence.nextOrder(answerOriginalIndex: answerIndex, using: &generator)
            }
            let positions = orders.map(\.correctDisplayedIndex)
            let positionCounts = (0..<optionCount).map { position in
                positions.filter { $0 == position }.count
            }

            precondition(
                zip(positions, positions.dropFirst()).allSatisfy { $0.0 != $0.1 },
                "Repeated interactive values must not keep the correct answer in the same slot. / При последовательной настройке интерактивных параметров правильный ответ не должен застревать в одном слоте."
            )
            precondition(
                positionCounts.max()! - positionCounts.min()! <= 1,
                "Interactive answer positions must stay balanced over time. / Позиции правильного ответа должны оставаться сбалансированными во времени."
            )

            for (order, answerIndex) in zip(orders, correctOriginalIndices) {
                precondition(
                    Set(order.displayedOriginalIndices) == Set(0..<optionCount)
                        && order.displayedOriginalIndices[order.correctDisplayedIndex] == answerIndex
                        && order.isCorrect(displayedIndex: order.correctDisplayedIndex),
                    "A balanced interactive order must preserve all options and the correct answer. / Сбалансированный интерактивный порядок должен сохранять все варианты и правильный ответ."
                )
            }
        }

        var initialOrderGenerator = SeededGenerator(seed: 91)
        let initialOrder = QuizAnswerOrder(
            optionCount: 3,
            answerOriginalIndex: 1,
            using: &initialOrderGenerator
        )
        var firstChangeSequence = QuizAnswerOrderSequence(optionCount: 3)
        var nextOrderGenerator = SeededGenerator(seed: 107)
        let afterInitialOrder = firstChangeSequence.nextOrder(
            answerOriginalIndex: 2,
            following: initialOrder,
            using: &nextOrderGenerator
        )
        precondition(
            afterInitialOrder.correctDisplayedIndex != initialOrder.correctDisplayedIndex,
            "The first parameter change must account for the already-visible answer slot. / Первое изменение параметра должно учитывать уже показанный слот правильного ответа."
        )

        for optionCount in [2, 3] {
            for answerIndex in 0..<optionCount {
                var correctPositionCounts = Array(repeating: 0, count: optionCount)
                for seed in 0..<256 {
                    var generator = SeededGenerator(seed: UInt64(seed))
                    let quizOrder = QuizAnswerOrder(
                        optionCount: optionCount,
                        answerOriginalIndex: answerIndex,
                        using: &generator
                    )
                    precondition(
                        Set(quizOrder.displayedOriginalIndices) == Set(0..<optionCount),
                        "Every quiz order must be a permutation. / Порядок вариантов должен быть перестановкой."
                    )

                    let correctDisplayIndex = quizOrder.displayedOriginalIndices.firstIndex(of: answerIndex)!
                    correctPositionCounts[correctDisplayIndex] += 1
                    for displayIndex in 0..<optionCount {
                        precondition(
                            quizOrder.isCorrect(displayedIndex: displayIndex)
                                == (quizOrder.originalIndex(forDisplayedIndex: displayIndex) == answerIndex),
                            "The quiz answer mapping must stay stable. / Сопоставление ответов не должно меняться."
                        )
                    }
                }

                precondition(
                    correctPositionCounts.allSatisfy { $0 > 0 },
                    "The correct answer must reach every quiz position. / Правильный ответ должен попадать в каждую позицию."
                )
            }
        }

        for answerIndex in 0..<3 {
            var correctPositionCounts = Array(repeating: 0, count: 3)
            for seed in 0..<256 {
                var generator = SeededGenerator(seed: UInt64(seed))
                let order = AnswerChoiceOrder(optionCount: 3, using: &generator)
                precondition(
                    Set(order.displayedOriginalIndices) == Set(0..<3),
                    "The order must be a permutation. / Порядок должен быть перестановкой."
                )

                let correctDisplayedIndex = order.displayedOriginalIndices.firstIndex(of: answerIndex)!
                correctPositionCounts[correctDisplayedIndex] += 1
                for displayedIndex in 0..<3 {
                    precondition(
                        order.isCorrect(displayedIndex: displayedIndex, answerOriginalIndex: answerIndex)
                            == (order.originalIndex(forDisplayedIndex: displayedIndex) == answerIndex),
                        "Displayed answer mapping changed. / Сопоставление ответа изменилось."
                    )
                }
            }

            precondition(
                correctPositionCounts.allSatisfy { $0 > 0 },
                "The correct answer must reach every position. / Правильный ответ должен попадать в каждую позицию."
            )
        }

        for answerIndex in 0..<3 {
            var retryPositionCounts = Array(repeating: 0, count: 3)
            for seed in 0..<256 {
                var initialGenerator = SeededGenerator(seed: UInt64(seed))
                var order = AnswerChoiceOrder(optionCount: 3, using: &initialGenerator)
                var retryGenerator = SeededGenerator(seed: UInt64(seed + 10_000))
                order.reshuffle(using: &retryGenerator)
                precondition(
                    Set(order.displayedOriginalIndices) == Set(0..<3),
                    "Retry must keep every answer exactly once. / При повторе каждый ответ должен встречаться ровно один раз."
                )

                let correctDisplayedIndex = order.displayedOriginalIndices.firstIndex(of: answerIndex)!
                retryPositionCounts[correctDisplayedIndex] += 1
                for displayIndex in 0..<3 {
                    precondition(
                        order.isCorrect(displayedIndex: displayIndex, answerOriginalIndex: answerIndex)
                            == (order.originalIndex(forDisplayedIndex: displayIndex) == answerIndex),
                        "Retry must preserve the original answer mapping. / При повторе должно сохраняться соответствие исходному ответу."
                    )
                }
            }

            precondition(
                retryPositionCounts.allSatisfy { $0 > 0 },
                "A fresh attempt must be able to place the correct answer in every position. / В новой попытке правильный ответ должен попадать в каждую позицию."
            )
        }

        var attemptGenerator = SeededGenerator(seed: 19)
        let curriculumQuestionID = "biology.passive_transport_osmosis.knowledge_check"
        guard var attempt = CurriculumCheckAttempt(
            optionCount: 3,
            answerOriginalIndex: 2,
            itemID: curriculumQuestionID,
            using: &attemptGenerator
        ) else {
            preconditionFailure("A valid answer index must start a quiz attempt. / Допустимый индекс ответа должен создавать попытку.")
        }
        let firstOrder = attempt.choiceOrder.displayedOriginalIndices
        attempt.select(displayedIndex: -1)
        precondition(
            attempt.attemptCount == 0,
            "An invalid screen index must not count as a submitted answer. / Недопустимый индекс на экране не должен засчитываться как отправленный ответ."
        )
        guard let wrongDisplayIndex = firstOrder.firstIndex(where: { $0 != 2 }) else {
            preconditionFailure("The quiz must include an incorrect choice. / В тесте должен быть неправильный вариант.")
        }
        attempt.select(displayedIndex: wrongDisplayIndex)
        precondition(attempt.selectedOriginalIndex == firstOrder[wrongDisplayIndex])
        precondition(!attempt.canComplete && attempt.canRetry)
        precondition(
            attempt.currentAnswerEventEvidence(errorCategory: .foundation) == StudyAssessmentEvidence(
                taskType: "knowledge_check",
                attempts: 1,
                firstTryCorrect: false,
                hintsUsed: 0,
                errorCategories: [.foundation],
                passed: false,
                itemID: curriculumQuestionID
            ),
            "A failed check event must remain distinct from a pass. / Событие неудачной проверки должно оставаться отдельно от успешной."
        )
        precondition(
            attempt.attemptCount == 1 && attempt.firstTryCorrect == false,
            "A wrong first answer must remain visible as learning evidence after a retry. / Ошибочный первый ответ должен остаться в учебном свидетельстве после повтора."
        )

        let firstSelection = attempt.selectedOriginalIndex
        attempt.select(displayedIndex: firstOrder.firstIndex(of: 2)!)
        precondition(
            attempt.selectedOriginalIndex == firstSelection,
            "An answered attempt must stay locked until retry. / После ответа попытка блокируется до повтора."
        )

        var retryGenerator = SeededGenerator(seed: 241)
        attempt.retry(errorCategory: .understanding, using: &retryGenerator)
        precondition(attempt.selectedOriginalIndex == nil && !attempt.canComplete && !attempt.canRetry)
        precondition(
            attempt.attemptCount == 1 && attempt.firstTryCorrect == false,
            "Retry must reset the selected answer without erasing the failed first attempt. / Повтор должен сбрасывать выбранный ответ, но сохранять неудачную первую попытку."
        )
        guard let correctDisplayIndex = attempt.choiceOrder.displayedOriginalIndices.firstIndex(of: 2) else {
            preconditionFailure("Retry must preserve the correct answer mapping. / Повтор должен сохранять соответствие правильного ответа.")
        }
        attempt.select(displayedIndex: correctDisplayIndex)
        precondition(attempt.isCorrect && attempt.canComplete && !attempt.canRetry)
        precondition(
            attempt.attemptCount == 2 && attempt.assessmentEvidence == StudyAssessmentEvidence(
                taskType: "knowledge_check",
                attempts: 2,
                firstTryCorrect: false,
                hintsUsed: 0,
                errorCategories: [.understanding],
                itemID: curriculumQuestionID
            ),
            "A completed check must expose its attempt evidence without changing the answer result. / Завершённая проверка должна передавать число попыток, не меняя правильность ответа."
        )
        let legacyAssessmentJSON = Data(
            #"{"task_type":"knowledge_check","attempts":1,"first_try_correct":true,"hints_used":0}"#.utf8
        )
        let legacyAssessment = try! JSONDecoder().decode(StudyAssessmentEvidence.self, from: legacyAssessmentJSON)
        precondition(
            legacyAssessment.errorCategories == nil,
            "Older progress without error categories must continue to decode. / Старый прогресс без категорий ошибок должен продолжать читаться."
        )
        let savedAssessmentData = try! JSONEncoder().encode(attempt.assessmentEvidence!)
        let restoredAssessment = try! JSONDecoder().decode(StudyAssessmentEvidence.self, from: savedAssessmentData)
        precondition(
            restoredAssessment == attempt.assessmentEvidence,
            "Self-reported categories must survive local progress encoding. / Самооценка категорий ошибок должна сохраняться в локальном прогрессе."
        )

        var firstTryGenerator = SeededGenerator(seed: 99)
        let firstTryQuestionID = "physics.net_force_and_acceleration.knowledge_check"
        guard var firstTryAttempt = CurriculumCheckAttempt(
            optionCount: 3,
            answerOriginalIndex: 1,
            itemID: firstTryQuestionID,
            using: &firstTryGenerator
        ) else {
            preconditionFailure("A valid answer index must start a quiz attempt. / Допустимый индекс ответа должен создавать попытку.")
        }
        let firstTryDisplayIndex = firstTryAttempt.choiceOrder.displayedOriginalIndices.firstIndex(of: 1)!
        firstTryAttempt.select(displayedIndex: firstTryDisplayIndex)
        precondition(
            firstTryAttempt.assessmentEvidence == StudyAssessmentEvidence(
                taskType: "knowledge_check",
                attempts: 1,
                firstTryCorrect: true,
                hintsUsed: 0,
                itemID: firstTryQuestionID
            ),
            "A first-try correct answer must be recorded as independent check evidence. / Правильный ответ с первой попытки должен сохраняться как результат проверки без повторов."
        )
        precondition(
            firstTryAttempt.currentAnswerEventEvidence()?.passed == true,
            "A correct answer event must be explicitly marked as passed. / Правильный ответ должен явно помечаться как успешный."
        )

        var predictionGenerator = SeededGenerator(seed: 307)
        guard var prediction = InteractivePredictionAttempt(
            optionCount: 3,
            answerOriginalIndex: 2,
            using: &predictionGenerator
        ) else {
            preconditionFailure("A valid option must start an interactive prediction. / Допустимый вариант должен запускать интерактивный прогноз.")
        }
        let predictionOrder = prediction.choiceOrder.displayedOriginalIndices
        precondition(Set(predictionOrder) == Set(0..<3))
        prediction.select(displayedIndex: -1)
        precondition(prediction.attemptCount == 0 && prediction.currentAnswerEventEvidence() == nil)
        let wrongPredictionIndex = predictionOrder.firstIndex(where: { $0 != 2 })!
        prediction.select(displayedIndex: wrongPredictionIndex)
        precondition(!prediction.isCorrect && prediction.canRetry)
        precondition(
            prediction.currentAnswerEventEvidence() == StudyAssessmentEvidence(
                taskType: "interactive_prediction",
                attempts: 1,
                firstTryCorrect: false,
                hintsUsed: 1
            ),
            "An incorrect interactive prediction must be saved as its own piece of evidence. / Неверный интерактивный прогноз должен сохраняться как отдельное учебное свидетельство."
        )
        let lockedPrediction = prediction.selectedOriginalIndex
        prediction.select(displayedIndex: predictionOrder.firstIndex(of: 2)!)
        precondition(prediction.selectedOriginalIndex == lockedPrediction)
        var predictionRetryGenerator = SeededGenerator(seed: 241)
        prediction.retry(using: &predictionRetryGenerator)
        precondition(prediction.selectedOriginalIndex == nil && prediction.attemptCount == 1)
        precondition(Set(prediction.choiceOrder.displayedOriginalIndices) == Set(0..<3))
        let correctPredictionIndex = prediction.choiceOrder.displayedOriginalIndices.firstIndex(of: 2)!
        prediction.select(displayedIndex: correctPredictionIndex)
        precondition(prediction.isCorrect && !prediction.canRetry && prediction.attemptCount == 2)
        precondition(
            prediction.currentAnswerEventEvidence() == StudyAssessmentEvidence(
                taskType: "interactive_prediction",
                attempts: 2,
                firstTryCorrect: false,
                hintsUsed: 1
            ),
            "A retry must preserve first-try correctness and cumulative attempts. / Повтор должен сохранять результат первой попытки и общее число попыток."
        )

        print("Answer choice order checks passed. / Проверки порядка вариантов прошли.")
    }
}
