import Foundation

/// The lab's merges match the lesson's program, step by step. / Слияния тренажёра совпадают с программой урока шаг за шагом.
@main
enum BPEMergeVerification {
    static let text = "Модель читает текст кусочками. Кусочки называют токенами. "
        + "Модель учится на текстах, и текст становится токенами, а токены становятся числами. "
        + "The model reads text in pieces, and the pieces of text are called tokens. "

    static func main() {
        var small = BPEMergeState(text: "hug hug pug")
        precondition(small.ids.count == 11)
        small.mergeNext()
        precondition(small.ids.count == 8 && small.label(256) == "ug", "The lesson's hand example. / Ручной пример урока.")
        small.mergeNext()
        precondition(small.ids.count == 6 && small.label(257) == "hug" && small.roundTrips)

        var state = BPEMergeState(text: text)
        precondition(state.byteCount == 334)
        precondition(state.label(208).contains("D0"), "Half a letter shows as a byte. / Половина буквы показана байтом.")
        var counts: [Int] = []
        for _ in 0..<40 {
            state.mergeNext()
            counts.append(state.ids.count)
            precondition(state.roundTrips, "No merge may lose text. / Ни одно слияние не теряет текст.")
        }
        precondition(Array(counts.prefix(5)) == [317, 305, 294, 284, 275], "Same as the program. / Как в программе: \(counts.prefix(5))")
        precondition(counts[9] == 239 && counts[19] == 199 && counts[29] == 169 && counts[39] == 147)
        precondition(state.label(256) == "т" && state.label(295).hasPrefix("Модель"))
        while !state.solved, state.mergeNext() {}
        precondition(state.solved, "Half the bytes is reachable. / Половина байтов достижима.")
        var two = BPEMergeState(text: "ab")
        precondition(two.nextPair == nil && !two.mergeNext(), "A pair met once is not worth merging. / Пару, встреченную один раз, сливать незачем.")
        print("BPE merges verified. / Слияния BPE проверены.")
    }
}
