import Foundation

@main
enum ConsciousnessIndicatorVerification {
    typealias Model = ConsciousnessIndicatorModel

    static func main() {
        // All 14 indicators of the report, grouped by its six theories. / Все 14 индикаторов отчёта по шести теориям.
        precondition(Model.indicators.count == 14 && Set(Model.indicators).count == 14)
        precondition(Set(Model.indicators.map(Model.theory)) == ["rpt", "gwt", "hot", "ast", "pp", "ae"])

        // The task is to judge every indicator, in either direction. / Задание: оценить каждый индикатор в любую сторону.
        var model = Model()
        precondition(!model.solvesChallenge && model.answeredCount == 0)
        for indicator in Model.indicators.dropLast() { model.answer(indicator, has: true) }
        precondition(!model.solvesChallenge, "one left unanswered")
        model.answer(Model.indicators.last!, has: false)
        precondition(model.solvesChallenge && model.matching == 1, "only the honest answer matches")

        // A changed answer counts once. / Изменённый ответ считается один раз.
        model.answer(Model.indicators.last!, has: true)
        precondition(model.answeredCount == 14 && model.matching == 0)
        model.reset()
        precondition(model.answeredCount == 0)

        print("Consciousness indicator verification passed.")
    }
}
