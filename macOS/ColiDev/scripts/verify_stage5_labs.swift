import Foundation

/// The labs compute the same numbers as the lessons' programs. / Тренажёры считают те же числа, что программы уроков.
@main
enum Stage5LabsVerification {
    static func main() {
        var agent = PainAgent()
        precondition(!agent.hurts, "No damage yet. / Повреждений пока нет.")
        for place in ["floor", "stove", "floor", "stove"] { agent.touch(place) }
        precondition(agent.hurts && agent.avoid["stove"] == 0.75 && agent.avoid["floor"] == 0 && agent.choice == "floor", "\(agent)")

        var rand = RLRand(77)
        let trace = WorkspaceModel.trial(strength: 0.6, rand: &rand)
        precondition(abs(trace[11] - 0.9958596380106832) < 1e-9 && abs(trace[0] - 0.4139029902380987) < 1e-9, "\(trace)")
        var low = RLRand(4)
        precondition(WorkspaceModel.ignitionShare(strength: 0.2, rand: &low) < 0.05, "A weak push fades. / Слабый толчок гаснет.")
        var high = RLRand(5)
        precondition(WorkspaceModel.ignitionShare(strength: 1, rand: &high) > 0.95, "A strong push ignites. / Сильный толчок зажигает.")

        let keep: [IntegrationModel.Gate] = [.keep, .keep, .keep]
        precondition(IntegrationModel.weakestCut(keep) == 0, "Separate nodes. / Отдельные узлы.")
        precondition(IntegrationModel.weakestCut([.previous, .previous, .previous]) == 2, "The chain. / Цепочка.")
        precondition(IntegrationModel.weakestCut([.xor, .xor, .xor]) == 2, "The XOR ring. / Кольцо XOR.")
        precondition(abs(IntegrationModel.weakestCut([.and, .and, .and]) - 1.561) < 0.001, "The AND ring. / Кольцо AND.")
        precondition(abs(IntegrationModel.weakestCut([.majority, .majority, .majority]) - 1.311) < 0.001, "Majority. / Большинство.")
        precondition(IntegrationModel.weakestCut([.keep, .previous, .next]) == 1, "All copy node 0. / Все копируют узел 0.")
        precondition(IntegrationModel.weakestCut([.keep, .previous, .keep]) == 0, "A zero with a link exists. / Есть ноль при связи.")

        let confidence = ConfidenceModel()
        precondition(abs(confidence.accuracy - 0.717) < 1e-9, "\(confidence.accuracy)")
        precondition(abs(confidence.reliability(temperature: 1.0).gap - 0.099) < 0.0006, "gap 1.0")
        precondition(abs(confidence.reliability(temperature: 2.0).gap - 0.031) < 0.0006, "gap 2.0")
        precondition(abs(confidence.reliability(temperature: 16.0).gap - 0.185) < 0.0006, "gap 16.0")
        precondition(abs(TwoErrors.threshold(falseAlarm: 1, miss: 100) - 0.0099) < 0.0001 && TwoErrors.threshold(falseAlarm: 100, miss: 1) > 0.99, "Thresholds. / Пороги.")
        let rare = TwoErrors.costs(probability: 0.01, falseAlarm: 1, miss: 100)
        precondition(rare.protect < rare.ignore, "One per cent is enough here. / Здесь хватает одного процента.")
        let fitted = MaskingFit.fit([(17, 0.2), (33, 0.45), (50, 0.6), (67, 0.825), (100, 1), (150, 1)])
        precondition(fitted.threshold == 51 && fitted.slope == 12, "\(fitted)")
        precondition(IndicatorJudgement.sum == 5 && IndicatorJudgement.lenient == 10 && IndicatorJudgement.strict == 0, "Ratings. / Оценки.")
        precondition(IndicatorJudgement.large.count == 14, "Fourteen. / Четырнадцать.")
        precondition(SelfReportRecording.rows.count == 12 && SelfReportRecording.rows.filter { $0.verdict == "claims" }.count == 2, "Reports. / Отчёты.")
        print("Stage 5 labs verified. / Тренажёры этапа 5 проверены.")
    }
}
