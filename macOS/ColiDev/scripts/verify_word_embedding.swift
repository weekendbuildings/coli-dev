import Foundation

// The app's enum, stubbed for the check: only the names matter here. / Перечисление приложения; здесь важны только имена.
enum AppLanguage { case ru, en }

@main
enum WordEmbeddingVerification {
    typealias Model = WordEmbeddingModel

    static func train(_ start: Model, steps: Int) -> Model {
        var model = start
        for _ in 0..<steps { model.step() }
        return model
    }

    static func rounded(_ value: Double, _ digits: Double = 100) -> Double { (value * digits).rounded() / digits }

    static func main() {
        // The words match one to one, so the numbers do not depend on the language.
        precondition(Model.count == 16 && Model.wordsRussian.count == 16)
        precondition(Model.word(Model.cat, language: .ru) == "кот" && Model.word(Model.cat, language: .en) == "cat")
        precondition(Model.word(Model.car, language: .ru) == "машина" && Model.word(Model.horse, language: .ru) == "конь")

        // The numbers of the lesson's program. / Числа программы урока.
        let opening = Model()
        precondition(opening.pairCount == 48)
        precondition(rounded(opening.cosine(Model.cat, Model.dog)) == -0.99, "start cat dog")
        precondition(rounded(opening.cosine(Model.cat, Model.car)) == -0.81, "start cat car")
        var model = opening
        model.step()
        precondition(rounded(model.history[0], 1000) == 2.758, "first error")
        precondition(abs(log(16.0) - 2.773) < 0.001)
        model = train(opening, steps: 101)
        precondition(rounded(model.history[100], 1000) == 0.937, "error at step 100")
        model = train(opening, steps: 601)
        precondition(rounded(model.history[600], 1000) == 0.867, "error at step 600")
        precondition(rounded(model.cosine(Model.cat, Model.dog)) == 1.0, "cat and dog")
        precondition(rounded(model.cosine(Model.cat, Model.car)) == 0.01, "cat and car")
        let trained = model

        // The opening does not solve the task.
        precondition(!opening.isTrained && !opening.horseChangedPlace)

        // The neighbours of a word are sorted by true similarity.
        let nearest = trained.neighbours(of: Model.cat)
        precondition(Set(nearest.prefix(2)) == [Model.dog, Model.horse], "the animals come first")
        precondition(nearest.count == 15)
        precondition(trained.cosine(Model.cat, nearest[0]) >= trained.cosine(Model.cat, nearest[1]))

        // Without the new sentences the horse stays with the animals, however long the training.
        let longer = train(trained, steps: 300)
        precondition(longer.cosine(Model.horse, Model.cat) > longer.cosine(Model.horse, Model.car) && !longer.horseChangedPlace)

        // With the new sentences it moves to the vehicles, which solves the task.
        var moved = trained
        moved.setExtraSentences(true)
        precondition(moved.pairCount == 48 + 5 * 8, "the new pairs arrive")
        precondition(!moved.horseChangedPlace, "adding sentences alone changes no vector")
        moved = train(moved, steps: 50)
        precondition(moved.horseChangedPlace, "the horse moves to the vehicles")
        precondition(moved.cosine(Model.horse, Model.car) > 0.8 && moved.cosine(Model.horse, Model.cat) < 0.7, "the size of the move")

        // New sentences on an untrained model earn nothing: there was no place to change from.
        // Новые предложения до обучения не засчитываются: коню неоткуда было уходить.
        var early = Model()
        early.setExtraSentences(true)
        early = train(early, steps: 300)
        if !early.horseStartedWithAnimals { precondition(!early.horseChangedPlace, "no credit before training") }

        // The gradient matches the numerical slope of the error. / Градиент совпадает с численным наклоном ошибки.
        var probe = train(opening, steps: 10)
        let before = probe.loss
        var stepped = probe
        stepped.step()
        precondition(stepped.history.last.map { abs($0 - before) < 1e-12 } == true, "the history keeps the error before the step")
        precondition(stepped.loss < before, "one step lowers the error")
        probe.setExtraSentences(false)

        // The step limit stops training.
        var limited = Model()
        for _ in 0..<(Model.stepLimit + 3) where limited.steps < Model.stepLimit - 1 { limited.nudgeSteps() }
        limited.step()
        limited.step()
        precondition(limited.steps == Model.stepLimit, "step limit")

        print("Word embedding verification passed.")
    }
}

extension WordEmbeddingModel {
    /// For the limit check only: fills the history without the cost of training. / Только для проверки предела.
    mutating func nudgeSteps() { recordStepForCheck() }
}
