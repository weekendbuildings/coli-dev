import Foundation

/// Generated from the lessons' programs and recordings; tests keep them equal. / Создано из программ и записей уроков; тесты следят за равенством.
enum ArcRecording {
    struct Task {
        let name: String
        let pairs: [(String, String)]
        let testIn: String
        let testOut: String
        let search: Bool
        let coderRight: Bool
        let qwenRight: Bool
    }

    static let tasks: [Task] = [
        Task(name: "flip", pairs: [("12/34", "21/43"), ("105/020", "501/020")], testIn: "340/007", testOut: "043/700", search: true, coderRight: false, qwenRight: false),
        Task(name: "turn", pairs: [("12/34", "31/42"), ("10/00", "01/00")], testIn: "56/70", testOut: "75/06", search: true, coderRight: false, qwenRight: false),
        Task(name: "recolor", pairs: [("121/010", "323/030"), ("11/00", "33/00")], testIn: "0110/2112", testOut: "0330/2332", search: true, coderRight: false, qwenRight: false),
        Task(name: "fill row", pairs: [("000/050/000", "000/555/000"), ("70/00", "77/00")], testIn: "000/000/400", testOut: "000/000/444", search: true, coderRight: true, qwenRight: true),
        Task(name: "double", pairs: [("12", "1122"), ("3/4", "33/44")], testIn: "56/70", testOut: "5566/7700", search: true, coderRight: true, qwenRight: true),
        Task(name: "mirror", pairs: [("12", "1221"), ("34/50", "3443/5005")], testIn: "601", testOut: "601106", search: true, coderRight: false, qwenRight: true),
        Task(name: "gravity", pairs: [("100/000/020", "000/000/120"), ("03/00", "00/03")], testIn: "500/070/000", testOut: "000/000/570", search: true, coderRight: false, qwenRight: false),
        Task(name: "largest", pairs: [("11/20", "1"), ("33/32", "3")], testIn: "4554/5555", testOut: "5", search: true, coderRight: true, qwenRight: false),
        Task(name: "border", pairs: [("000/000/000", "111/101/111"), ("0000/0000/0000", "1111/1001/1111")], testIn: "00000/00000/00000", testOut: "11111/10001/11111", search: true, coderRight: true, qwenRight: true),
        Task(name: "count", pairs: [("10/01", "2"), ("111/010", "4")], testIn: "11/11/10", testOut: "5", search: false, coderRight: false, qwenRight: false)
    ]
}

enum ScalingRecording {
    static let sizes: [Double] = [100.0, 300.0, 1000.0, 3000.0, 10000.0, 30000.0, 100000.0]
    static let errors: [Double] = [2.1439, 1.593, 1.0876, 0.7637, 0.6307, 0.5993, 0.5873]
}
