import Foundation

@main
enum OsmosisPracticeVerification {
    static func main() {
        let cases: [(inside: Int, outside: Int, expected: OsmosisWaterFlow, answer: Int, arrow: String)] = [
            // More solute outside (hypertonic) draws water out; more inside draws it in.
            // Снаружи больше вещества (гипертонический раствор) — вода выходит; внутри больше — входит.
            (inside: 4, outside: 6, expected: .waterLeavesCell, answer: 1, arrow: "arrow.left"),
            (inside: 6, outside: 4, expected: .waterEntersCell, answer: 0, arrow: "arrow.right"),
            (inside: 4, outside: 4, expected: .dynamicEquilibrium, answer: 2, arrow: "arrow.left.and.right")
        ]

        for testCase in cases {
            let flow = OsmosisWaterFlow.predict(
                insideSolute: testCase.inside,
                outsideSolute: testCase.outside
            )
            precondition(flow == testCase.expected)
            precondition(flow.answerOriginalIndex == testCase.answer)
            precondition(flow.arrowSymbol == testCase.arrow)
        }

        let itemID = "biology.passive_transport_osmosis.water_flow"
        var attempt = InteractivePredictionAttempt(
            optionCount: 3,
            answerOriginalIndex: OsmosisWaterFlow.predict(insideSolute: 6, outsideSolute: 4).answerOriginalIndex,
            itemID: itemID
        )!
        precondition(attempt.currentAnswerEventEvidence() == nil)

        let wrongDisplayIndex = attempt.choiceOrder.displayedOriginalIndices.firstIndex(of: 1)!
        attempt.select(displayedIndex: wrongDisplayIndex)
        let firstEvidence = attempt.currentAnswerEventEvidence()
        precondition(firstEvidence == StudyAssessmentEvidence(
            taskType: "interactive_prediction",
            attempts: 1,
            firstTryCorrect: false,
            hintsUsed: 1,
            itemID: itemID
        ))
        precondition(attempt.canRetry)

        attempt.select(displayedIndex: wrongDisplayIndex)
        precondition(attempt.currentAnswerEventEvidence() == firstEvidence)

        attempt.retry()
        let correctDisplayIndex = attempt.choiceOrder.displayedOriginalIndices.firstIndex(of: 0)!
        attempt.select(displayedIndex: correctDisplayIndex)
        precondition(attempt.currentAnswerEventEvidence() == StudyAssessmentEvidence(
            taskType: "interactive_prediction",
            attempts: 2,
            firstTryCorrect: false,
            hintsUsed: 1,
            itemID: itemID
        ))

        print("Osmosis prediction and evidence checks passed. / Проверка прогноза осмоса и учебного свидетельства пройдена.")
    }
}
