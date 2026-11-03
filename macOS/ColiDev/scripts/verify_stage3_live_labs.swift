import Foundation

/// The labs agree with the lessons' programs and recordings. / Тренажёры согласованы с программами и записями уроков.
@main
enum Stage3LiveLabsVerification {
    static func main() {
        precondition(abs((ReasoningChoice.train(price: 0.0).last ?? 0) - 0.9634721722762017) < 1e-6, "price 0.0")
        precondition(abs((ReasoningChoice.train(price: 0.2).last ?? 0) - 0.760600992567112) < 1e-6, "price 0.2")
        precondition(abs((ReasoningChoice.train(price: 0.25).last ?? 0) - 0.3229798148810515) < 1e-6, "price 0.25")
        precondition(abs((ReasoningChoice.train(price: 0.5).last ?? 0) - 0.03265506250117243) < 1e-6, "price 0.5")
        precondition(ReasoningChoice.solved(limit: 3000) == 10 && ReasoningChoice.solved(limit: 2199) == 8 && ReasoningChoice.solved(limit: 1999) == 7, "Solved by limit. / Решено при лимите.")
        let boat1 = BoatRace(coin: 0.01, once: false, episodes: 400, seed: 41).play()
        precondition(boat1.finished == true && abs(boat1.score - 1.02) < 0.01, "\(boat1)")
        let boat2 = BoatRace(coin: 0.02, once: false, episodes: 400, seed: 41).play()
        precondition(boat2.finished == false && abs(boat2.score - 1.18) < 0.01, "\(boat2)")
        let boat10 = BoatRace(coin: 0.1, once: false, episodes: 400, seed: 41).play()
        precondition(boat10.finished == false && abs(boat10.score - 5.9) < 0.01, "\(boat10)")
        let fixed = BoatRace(coin: 0.5, once: true, episodes: 800, seed: 41).play()
        precondition(fixed.finished && abs(fixed.score - 2.0) < 0.01, "\(fixed)")
        let vector = SearchRecording.places["vector"] ?? []
        precondition(SearchScore.foundShare(places: vector, within: 5) == 1 && SearchScore.foundShare(places: vector, within: 4) < 1, "\(vector)")
        precondition(abs(SearchScore.meanReciprocalRank(places: vector) - 0.83) < 0.006, "MRR")
        precondition(SearchRecording.similarity.count == SearchRecording.questions.count && SearchRecording.similarity[0].count == SearchRecording.chunks.count, "Sizes. / Размеры.")
        precondition(AgentRecording.tasks.filter(\.solved).count == 3 && !AgentRecording.tasks[1].solved && !AgentRecording.tasks[3].solved && !AgentRecording.tasks[5].solved, "Agent results. / Итоги агента.")
        print("Stage 3 live labs verified. / Тренажёры этапа 3 с моделью проверены.")
    }
}
