import Foundation

/// Byte pair encoding on one text, one merge at a time. / Байтовое слияние пар на одном тексте, по одному слиянию.
struct BPEMergeState {
    struct Pair: Hashable {
        let first: Int
        let second: Int
    }

    struct Merge: Identifiable {
        let id: Int
        let pair: Pair
        let count: Int
    }

    private(set) var byteCount = 0
    private(set) var ids: [Int] = []
    private(set) var vocabulary: [Int: [UInt8]] = [:]
    private(set) var merges: [Merge] = []
    private(set) var history: [Int] = []
    private(set) var original = ""

    init(text: String) {
        restart(text: text)
    }

    mutating func restart(text: String) {
        original = text
        ids = Array(text.utf8).map(Int.init)
        byteCount = ids.count
        vocabulary = [:]
        for byte in 0..<256 { vocabulary[byte] = [UInt8(byte)] }
        merges = []
        history = [ids.count]
    }

    /// The most frequent neighbouring pair; among equals, the one met first. / Самая частая соседняя пара; среди равных та, что встретилась первой.
    var nextPair: (pair: Pair, count: Int)? {
        guard ids.count > 1 else { return nil }
        var counts: [Pair: Int] = [:]
        var order: [Pair] = []
        for index in 0..<(ids.count - 1) {
            let pair = Pair(first: ids[index], second: ids[index + 1])
            if counts[pair] == nil { order.append(pair) }
            counts[pair, default: 0] += 1
        }
        var best: (pair: Pair, count: Int)?
        for pair in order {
            let count = counts[pair] ?? 0
            if count > (best?.count ?? 0) { best = (pair, count) }
        }
        return best.flatMap { $0.count >= 2 ? $0 : nil }
    }

    @discardableResult
    mutating func mergeNext() -> Bool {
        guard let next = nextPair else { return false }
        let newID = 256 + merges.count
        var result: [Int] = []
        result.reserveCapacity(ids.count)
        var index = 0
        while index < ids.count {
            if index + 1 < ids.count, ids[index] == next.pair.first, ids[index + 1] == next.pair.second {
                result.append(newID)
                index += 2
            } else {
                result.append(ids[index])
                index += 1
            }
        }
        ids = result
        vocabulary[newID] = (vocabulary[next.pair.first] ?? []) + (vocabulary[next.pair.second] ?? [])
        merges.append(Merge(id: newID, pair: next.pair, count: next.count))
        history.append(ids.count)
        return true
    }

    /// Readable text of a token; half a letter shows as its byte in hex. / Текст токена; половина буквы показана байтом в шестнадцатеричной записи.
    func label(_ id: Int) -> String {
        let bytes = vocabulary[id] ?? []
        if let text = String(bytes: bytes, encoding: .utf8) {
            return text.replacingOccurrences(of: " ", with: "␣").replacingOccurrences(of: "\n", with: "⏎")
        }
        return bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Whether the tokens glue back into exactly the same text. / Склеиваются ли токены обратно в точно тот же текст.
    var roundTrips: Bool {
        String(bytes: ids.flatMap { vocabulary[$0] ?? [] }, encoding: .utf8) == original
    }

    /// Whether a token is part of the pair about to merge. / Входит ли токен в пару, которая сольётся следующей.
    func marksNextPair(at index: Int) -> Bool {
        guard let pair = nextPair?.pair else { return false }
        if index + 1 < ids.count, ids[index] == pair.first, ids[index + 1] == pair.second { return true }
        return index > 0 && ids[index - 1] == pair.first && ids[index] == pair.second
    }

    var solved: Bool { byteCount > 0 && ids.count * 2 <= byteCount && roundTrips }
}
