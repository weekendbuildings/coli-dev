import Foundation

/// One exam question with the real recorded answers. / Один вопрос экзамена с настоящими записанными ответами.
struct ScoreboardItem: Equatable {
    enum Kind: String {
        case fact, math, letters, logic, invented, date
    }

    let kind: Kind
    let question: String
    let answer: String
    let right: Bool
    let confidence: Double
    let bigger: String
    let biggerRight: Bool
    let tries: [String]
    let triesRight: Int
}

/// The lab's state: the learner's bets and the trust threshold. / Состояние тренажёра: ставки ученика и порог доверия.
struct ModelScoreboardState: Equatable {
    static let items = ScoreboardRecording.items
    /// Enough bets to have felt the problem before the task opens. / Сколько ставок нужно, чтобы почувствовать задачу.
    static let betsForTask = 5

    var selected = 0
    var threshold = 0.8
    private(set) var bets: [Int: Bool] = [:]

    var item: ScoreboardItem { Self.items[selected] }
    var isRevealed: Bool { bets[selected] != nil }

    mutating func bet(trust: Bool) {
        guard bets[selected] == nil else { return }
        bets[selected] = trust
    }

    /// A bet is right when you trust a right answer or doubt a wrong one. / Ставка верна, если веришь верному или не веришь неверному.
    var guessedRight: Int {
        bets.filter { Self.items[$0.key].right == $0.value }.count
    }

    /// What the rule "trust above this confidence" lets through. / Что пропускает правило «верь выше этой уверенности».
    static func rule(above limit: Double) -> (trusted: Int, right: Int) {
        let trusted = items.filter { $0.confidence > limit }
        return (trusted.count, trusted.filter(\.right).count)
    }

    var currentRule: (trusted: Int, right: Int) { Self.rule(above: threshold) }

    /// The lowest honest threshold: all that passes is right, and something passes. / Самый честный порог: всё пропущенное верно, и что-то пропущено.
    var solved: Bool {
        let rule = currentRule
        return bets.count >= Self.betsForTask && rule.trusted > 0 && rule.right == rule.trusted
    }
}

/// Generated from `02_Areas/Programming/resources/model_mistakes_recording.json`; a test keeps the two equal.
/// Создано из записи настоящих ответов; тест следит, чтобы они совпадали.
enum ScoreboardRecording {
    static let items: [ScoreboardItem] = [
        ScoreboardItem(kind: .fact, question: "Столица Австралии?", answer: "Канберра", right: true, confidence: 0.869, bigger: "Столицей Австралии является город Канберра.", biggerRight: true, tries: ["Канберра", "Канберра", "Канberra", "Канберра", "Канберра"], triesRight: 4),
        ScoreboardItem(kind: .fact, question: "Столица Узбекистана?", answer: "Ташкент", right: true, confidence: 0.945, bigger: "Столицей Узбекистана является город Ташкент.", biggerRight: true, tries: ["Деликкабул.", "Ташкент", "Ташкент", "Ташкент", "Ташкент"], triesRight: 4),
        ScoreboardItem(kind: .fact, question: "Химический символ золота?", answer: "Au", right: true, confidence: 0.936, bigger: "Au", biggerRight: true, tries: ["Au", "Au", "Au", "Au", "Au"], triesRight: 5),
        ScoreboardItem(kind: .fact, question: "Кто написал роман «Война и мир»?", answer: "Роман \"Война и мир\" написал Львов Николаевич Лермонтов.", right: false, confidence: 0.795, bigger: "Роман «Война и мир» написал Лев Николаевич Толстой.", biggerRight: true, tries: ["Антон Чехов написал роман \"Война и мир\".", "Роман \"Война и мир\" написал Львов Пьер Борисович Достоевский.", "Роман \"Война и мир\" написал Александр Пушкин.", "Роман \"Война и мир\" написал Льва Толстого.", "Роман «Война и мир» написал Лев Толстой."], triesRight: 2),
        ScoreboardItem(kind: .fact, question: "Сколько планет в Солнечной системе?", answer: "8 планет в Солнечной системе.", right: true, confidence: 0.898, bigger: "В Солнечной системе 8 планет.", biggerRight: true, tries: ["9 планет в Солнечной системе.", "8", "8 планет в Солнечной системе.", "8 планет в Солнечной системе.", "8 планет в Солнечной системе."], triesRight: 4),
        ScoreboardItem(kind: .math, question: "Сколько будет 17 умножить на 24?", answer: "408", right: true, confidence: 0.988, bigger: "17 умножить на 24 равно 408.", biggerRight: true, tries: ["408", "408", "408", "408", "408"], triesRight: 5),
        ScoreboardItem(kind: .math, question: "Сколько будет 2 в степени 16?", answer: "65536", right: true, confidence: 0.998, bigger: "2 в степени 16 равно 65536.", biggerRight: true, tries: ["65536", "65536", "65536", "65536", "65536"], triesRight: 5),
        ScoreboardItem(kind: .math, question: "Сколько будет 7 в степени 5?", answer: "16807", right: true, confidence: 0.991, bigger: "16807", biggerRight: true, tries: ["16807", "16807", "16807", "16807", "16807"], triesRight: 5),
        ScoreboardItem(kind: .math, question: "Сколько будет 48271 умножить на 9173?", answer: "442,000,011", right: false, confidence: 0.344, bigger: "48271 × 9173 = 442799883", biggerRight: false, tries: ["439427627", "439835993", "440203213", "441376991", "441843313"], triesRight: 0),
        ScoreboardItem(kind: .math, question: "Сколько будет 123456 умножить на 654321?", answer: "8077985276", right: false, confidence: 0.631, bigger: "80281279956", biggerRight: false, tries: ["7992285510", "8076985281", "79,589,035,014", "80779852816", "80701212111."], triesRight: 0),
        ScoreboardItem(kind: .letters, question: "Сколько букв «р» в слове «программирование»?", answer: "2", right: false, confidence: 0.36, bigger: "В слове «программирование» одна буква «р».", biggerRight: false, tries: ["5", "3", "3", "2", "2"], triesRight: 2),
        ScoreboardItem(kind: .letters, question: "Сколько букв «r» в слове strawberry?", answer: "2", right: false, confidence: 0.559, bigger: "В слове strawberry 3 буквы «r».", biggerRight: true, tries: ["1", "2", "3", "2", "2"], triesRight: 1),
        ScoreboardItem(kind: .letters, question: "Напиши слово «модель» задом наперёд.", answer: "льдом", right: false, confidence: 0.602, bigger: "ледоМ", biggerRight: false, tries: ["йлоемдм", "льодм", "ельмод", "льдом", "льдом"], triesRight: 0),
        ScoreboardItem(kind: .logic, question: "Что тяжелее: килограмм железа или килограмм ваты?", answer: "Оба тяжелее, так как оба равны одному килограмму.", right: true, confidence: 0.737, bigger: "Они весят одинаково — по одному килограмму.", biggerRight: true, tries: ["Вес одинаковый, по 1 килограмм.", "Оба тяжелее, чем килограмм.", "Они равны.", "Оба тяжелее, по definition 1 килограмм.", "Оба тяжелее, так как по определению килограмм - это единица измерения массы, равная 1 килограмму, независимо от материала."], triesRight: 3),
        ScoreboardItem(kind: .logic, question: "У Маши три брата, и у каждого брата две сестры. Сколько сестёр у Маши?", answer: "У Маши две сестры.", right: false, confidence: 0.771, bigger: "У Маши одна сестра — это она сама.", biggerRight: true, tries: ["Маши сестер нет.", "У Маши три сестры.", "2", "У Маши три сестры.", "У Маши одна сестра."], triesRight: 1),
        ScoreboardItem(kind: .invented, question: "В каком году физик Иван Петрович Карасёв получил Нобелевскую премию?", answer: "Иван Петрович Карасёв получил Нобелевскую премию в 1930 году.", right: false, confidence: 0.877, bigger: "Иван Петрович Карасёв не получал Нобелевской премии, так как это вымышленный персонаж из советского фильма «Операция «Ы» и другие приключения Шурика».", biggerRight: true, tries: ["Физик Иван Петрович Карасёв получил Нобелевскую премию в 1971 году.", "Иван Петрович Карасёв получил Нобелевскую премию в 1911 году.", "Иван Петрович Карасёв получил Нобелевскую премию в 1971 году.", "Иван Петрович Карасёв получил Нобелевскую премию в 1962 году.", "Иван Петрович Карасёв получил Нобелевскую премию в 1930 году."], triesRight: 0),
        ScoreboardItem(kind: .invented, question: "Кто написал роман «Тихий берег Альдебарана»?", answer: "Роман \"Тихий берег Альдебарана\" написал Александр Пушкин.", right: false, confidence: 0.89, bigger: "Роман «Тихий берег Альдебарана» написал американский писатель-фантаст Рэй Брэдбери.", biggerRight: false, tries: ["Френк Зимбеков.", "Роман «Тихий берег Альдебарана» написал Александр Дюма.", "Роман \"Тихий берег Альдебарана\" написал Александр Пушкин.", "Роман \"Тихий берег Альдебарана\" написал Александр Пушкин.", "Роман «Тихий берег Альдебарана» написал Александр Пушкин."], triesRight: 0),
        ScoreboardItem(kind: .invented, question: "Что делает функция numpy.quantum_sort?", answer: "Функция numpy.quantum_sort не существует в библиотеке numpy. Возможно, вы имели в виду numpy.sort, которая сортирует массивы.", right: true, confidence: 0.896, bigger: "Такой функции не существует в библиотеке NumPy.", biggerRight: true, tries: ["Функция numpy.quantum_sort не существует в библиотеке numpy. Возможно, вы имели в виду функцию numpy.sort, которая сортирует массивы.", "Функция numpy.quantum_sort не существует в библиотеке Numpy. Возможно, вы имели в виду функцию numpy.sort для сортировки массивов.", "Функция numpy.quantum_sort не существует в библиотеке NumPy. Возможно, вы имели в виду numpy.sort, которая сортирует элементы массива по возрастанию.", "Функция numpy.quantum_sort не существует в библиотеке NumPy. Возможно, вы имели в виду numpy.sort, которая сортирует массив NumPy в порядке возрастания по умолчанию.", "Функция numpy.quantum_sort не существует в библиотеке numpy. Возможно, вы имели в виду функцию numpy.sort, которая используется для сортировки массивов."], triesRight: 5),
        ScoreboardItem(kind: .date, question: "Какой сегодня год? Ответь только числом.", answer: "2023", right: false, confidence: 0.994, bigger: "2024", biggerRight: false, tries: ["2023", "2023", "2023", "2023", "2023"], triesRight: 0),
        ScoreboardItem(kind: .date, question: "Кто сейчас президент США? Ответь только именем.", answer: "Джо Байден", right: false, confidence: 0.964, bigger: "Дональд Трамп", biggerRight: true, tries: ["Байден", "Джо Байден", "Джо Байден", "Джо Байден", "Джо Байден"], triesRight: 0)
    ]
}
