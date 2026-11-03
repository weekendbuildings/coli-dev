import Foundation

/// The patients are real curves, and each has its own diagnosis. / Пациенты это настоящие кривые, и у каждого свой диагноз.
@main
enum TrainingDoctorVerification {
    static func main() {
        precondition(Set(TrainingDoctorState.order) == Set(TrainingDoctorState.diagnoses) && TrainingDoctorState.order.count == 6)
        for name in TrainingDoctorState.order {
            precondition(TrainingDoctorRecording.curves[name]?.count == 31, name)
        }
        let healthy = TrainingDoctorRecording.curves["healthy"]!
        precondition(healthy[30].0 < healthy[0].0 && healthy[30].1 < healthy[0].1, "Both curves fall when healthy. / У здоровой сети падают обе кривые.")
        let few = TrainingDoctorRecording.curves["too_little_data"]!
        precondition(few[30].0 < 0.01 && few[30].1 > few[0].1, "Too little data: train falls, check grows. / Мало данных: обучение падает, проверка растёт.")
        let sign = TrainingDoctorRecording.curves["wrong_sign"]!
        precondition(sign[30].0 > sign[0].0, "A wrong sign climbs. / Неверный знак ведёт вверх.")

        var state = TrainingDoctorState()
        let answer = state.currentCase
        let wrong = TrainingDoctorState.diagnoses.first { $0 != answer }!
        state.guess(wrong)
        precondition(!state.isCurrentSolved && state.wrongGuesses == [wrong] && state.firstTry == 0)
        state.guess(answer)
        precondition(state.isCurrentSolved && state.firstTry == 0, "A second try does not count as the first. / Вторая попытка не считается первой.")
        for _ in 1..<TrainingDoctorState.order.count {
            state.next()
            state.guess(state.currentCase)
        }
        precondition(state.solved && state.solvedCount == 6 && state.firstTry == 5)
        state.next()
        precondition(state.current == 5, "No patient after the last. / После последнего пациента нет.")
        print("Training doctor verified. / Доктор обучения проверен.")
    }
}
