import Foundation

/// One order of the lesson with its right answer. / Один заказ урока с верным ответом.
struct PromptLabOrder: Equatable {
    let text: String
    let name: String
    let count: Int
    let price: Int
}

enum PromptLabMark: String, Equatable {
    case right, wrong, broken
}

/// One combination of techniques with the real answers to all orders. / Одно сочетание приёмов с настоящими ответами на все заказы.
struct PromptLabCombo: Equatable {
    let rule: Bool
    let examples: Bool
    let shape: Bool
    let tokens: Int
    let answers: [String]
    let marks: [PromptLabMark]

    var rightCount: Int { marks.filter { $0 == .right }.count }
    var brokenCount: Int { marks.filter { $0 == .broken }.count }
}

/// The lab's state with no drawing, so a script can check it. / Состояние тренажёра без рисования.
struct PromptLabState: Equatable {
    var rule = false
    var examples = false
    var shape = false
    var selectedOrder = 0

    var combo: PromptLabCombo {
        PromptLabRecording.combos.first { $0.rule == rule && $0.examples == examples && $0.shape == shape }!
    }

    mutating func select(_ combo: PromptLabCombo) {
        rule = combo.rule
        examples = combo.examples
        shape = combo.shape
    }

    /// The cheapest combination with every order right. / Самое дешёвое сочетание, где верны все заказы.
    static var cheapestFull: PromptLabCombo {
        PromptLabRecording.combos.filter { $0.rightCount == PromptLabRecording.orders.count }.min { $0.tokens < $1.tokens }!
    }

    var solved: Bool { combo == Self.cheapestFull }
}

/// Generated from `02_Areas/Programming/resources/asking_well_recording.json`; a test keeps the two equal.
/// Создано из записи настоящих ответов; тест следит, чтобы они совпадали.
enum PromptLabRecording {
    static let orders: [PromptLabOrder] = [PromptLabOrder(text: "Анна заказала 3 книги по 250 рублей.", name: "Анна", count: 3, price: 250), PromptLabOrder(text: "Тимур купил 12 ручек, каждая стоит 40 рублей.", name: "Тимур", count: 12, price: 40), PromptLabOrder(text: "Мне нужно пять тетрадей по 60 рублей, пишет Мария.", name: "Мария", count: 5, price: 60), PromptLabOrder(text: "Цена 1500 за штуку, брать будет Олег, две штуки.", name: "Олег", count: 2, price: 1500), PromptLabOrder(text: "Заказ от Лейлы: 7 карандашей, 15 рублей за один.", name: "Лейла", count: 7, price: 15), PromptLabOrder(text: "Сергей берёт десяток яблок по 30 рублей.", name: "Сергей", count: 10, price: 30), PromptLabOrder(text: "От Дилшода: 4 кружки, по 350 рублей каждая.", name: "Дилшод", count: 4, price: 350), PromptLabOrder(text: "Ирина, 2 рюкзака, 2300 рублей штука.", name: "Ирина", count: 2, price: 2300), PromptLabOrder(text: "Купить 6 лампочек по 120 рублей просил Азиз.", name: "Азиз", count: 6, price: 120), PromptLabOrder(text: "Вера заказала 3 кг муки, за килограмм 90 рублей.", name: "Вера", count: 3, price: 90), PromptLabOrder(text: "Пётр хочет 20 конвертов по 5 рублей.", name: "Пётр", count: 20, price: 5), PromptLabOrder(text: "Для Камиллы 1 ноутбук за 54000 рублей.", name: "Камилла", count: 1, price: 54000)]

    static let combos: [PromptLabCombo] = [
        PromptLabCombo(rule: false, examples: false, shape: false, tokens: 50, answers: ["Анна заплатила 750 рублей за книги.", "Тимур заплатил 480 рублей за ручки.", "Конечно, я могу помочь с этим. Вот ответ на сообщение Марии:\n\n\"Здравствуйте, Мария! \n\nВот ваш заказ:\n\n5 тетрад", "Цена 3000 за две штуки.", "Заказ от Лейлы: 7 карандашей, 15 рублей за один. Общая стоимость заказа: 7 * 15 = 105 рублей.", "Сергей заплатит 300 рублей за десяток яблок.", "Ответ: 1400 рублей", "Ирина, 2 рюкзака, 2300 рублей штука.", "Азиз просил купить 6 лампочек по 120 рублей.", "Вера заплатила 3 * 90 = 270 рублей за муку.", "Ответ: 100 рублей.", "Для Камиллы 1 ноутбук за 54000 рублей."], marks: [.broken, .broken, .broken, .broken, .broken, .broken, .broken, .broken, .broken, .broken, .broken, .broken]),
        PromptLabCombo(rule: true, examples: false, shape: false, tokens: 101, answers: ["```json\n{\"name\": \"Анна\", \"count\": 3, \"price\": 250}\n```", "```json\n{\"name\": \"Тимур\", \"count\": 12, \"price\": 40}\n```", "```json\n{\"name\": \"Мария\", \"count\": 5, \"price\": 60}\n```", "```json\n{\"name\": \"Олег\", \"count\": 2, \"price\": 1500}\n```", "```json\n{\"name\": \"Лейла\", \"count\": 7, \"price\": 15}\n```", "```json\n{\"name\": \"Сергей\", \"count\": 10, \"price\": 30}\n```", "```json\n{\"name\": \"Дилшод\", \"count\": 4, \"price\": 350}\n```", "```json\n{\"name\": \"Ирина\", \"count\": 2, \"price\": 2300}\n```", "```json\n{\"name\": \"Азиз\", \"count\": 6, \"price\": 120}\n```", "```json\n{\"name\": \"Вера\", \"count\": 3, \"price\": 90}\n```", "```json\n{\"name\": \"Пётр\", \"count\": 20, \"price\": 5}\n```", "```json\n{\"name\": \"Камилла\", \"count\": 1, \"price\": 54000}\n```"], marks: [.broken, .broken, .broken, .broken, .broken, .broken, .broken, .broken, .broken, .broken, .broken, .broken]),
        PromptLabCombo(rule: false, examples: true, shape: false, tokens: 143, answers: ["{\"name\": \"Анна\", \"count\": 3, \"price\": 250}", "{\"name\": \"Тимур\", \"count\": 12, \"price\": 40}", "{\"name\": \"Мария\", \"count\": 5, \"price\": 60}", "{\"name\": \"Олег\", \"count\": 2, \"price\": 1500}", "{\"name\": \"Лейла\", \"count\": 7, \"price\": 15}", "{\"name\": \"Сергей\", \"count\": 10, \"price\": 30}", "{\"name\": \"Дилшод\", \"count\": 4, \"price\": 350}", "{\"name\": \"Ирина\", \"count\": 2, \"price\": 2300}", "{\"name\": \"Азиз\", \"count\": 6, \"price\": 120}", "{\"name\": \"Вера\", \"count\": 3, \"price\": 90}", "{\"name\": \"Пётр\", \"count\": 20, \"price\": 5}", "{\"name\": \"Камилла\", \"count\": 1, \"price\": 54000}"], marks: [.right, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right]),
        PromptLabCombo(rule: true, examples: true, shape: false, tokens: 194, answers: ["{\"name\": \"Анна\", \"count\": 3, \"price\": 250}", "{\"name\": \"Тимур\", \"count\": 12, \"price\": 40}", "{\"name\": \"Мария\", \"count\": 5, \"price\": 60}", "{\"name\": \"Олег\", \"count\": 2, \"price\": 1500}", "{\"name\": \"Лейла\", \"count\": 7, \"price\": 15}", "{\"name\": \"Сергей\", \"count\": 10, \"price\": 30}", "{\"name\": \"Дилшод\", \"count\": 4, \"price\": 350}", "{\"name\": \"Ирина\", \"count\": 2, \"price\": 2300}", "{\"name\": \"Азиз\", \"count\": 6, \"price\": 120}", "{\"name\": \"Вера\", \"count\": 3, \"price\": 90}", "{\"name\": \"Пётр\", \"count\": 20, \"price\": 5}", "{\"name\": \"Камилла\", \"count\": 1, \"price\": 54000}"], marks: [.right, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right]),
        PromptLabCombo(rule: false, examples: false, shape: true, tokens: 50, answers: ["{ \"name\": \"Анна\", \"count\": 3, \"price\": 250 }", "{ \"name\": \"Тимур купил 12 ручек, каждая стоит 40 рублей.\", \"count\": 12, \"price\": 40 }", "{ \"name\": \"Мария\", \"count\": 5, \"price\": 60 }", "{ \"name\": \"Олег\", \"count\": 2, \"price\": 1500 }", "{ \"name\": \"Лейла\", \"count\": 7, \"price\": 15 }", "{ \"name\": \"Сергей берёт десяток яблок по 30 рублей.\", \"count\": 10, \"price\": 30 }", "{ \"name\": \"Дилшод\", \"count\": 4, \"price\": 350 }", "{ \"name\": \"Ирина\", \"count\": 2, \"price\": 2300 }", "{ \"name\": \"Азиз\", \"count\": 6, \"price\": 120 }", "{ \"name\": \"Вера\", \"count\": 3, \"price\": 90 }", "{ \"name\": \"Пётр\", \"count\": 20, \"price\": 5 }", "{ \"name\": \"Камилла\", \"count\": 1, \"price\": 54000 }"], marks: [.right, .wrong, .right, .right, .right, .wrong, .right, .right, .right, .right, .right, .right]),
        PromptLabCombo(rule: true, examples: false, shape: true, tokens: 101, answers: ["{\"name\": \"Анна\", \"count\": 3, \"price\": 250}", "{\"name\": \"Тимур\", \"count\": 12, \"price\": 40}", "{\"name\": \"Мария\", \"count\": 5, \"price\": 60}", "{\"name\": \"Олег\", \"count\": 2, \"price\": 1500}", "{\"name\": \"Лейла\", \"count\": 7, \"price\": 15}", "{\"name\": \"Сергей\", \"count\": 10, \"price\": 30}", "{\"name\": \"Дилшод\", \"count\": 4, \"price\": 350}", "{\"name\": \"Ирина\", \"count\": 2, \"price\": 2300}", "{\"name\": \"Азиз\", \"count\": 6, \"price\": 120}", "{\"name\": \"Вера\", \"count\": 3, \"price\": 90}", "{\"name\": \"Пётр\", \"count\": 20, \"price\": 5}", "{\"name\": \"Камилла\", \"count\": 1, \"price\": 54000}"], marks: [.right, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right]),
        PromptLabCombo(rule: false, examples: true, shape: true, tokens: 143, answers: ["{\"name\": \"Анна\", \"count\": 3, \"price\": 250}", "{\"name\": \"Тимур\", \"count\": 12, \"price\": 40}", "{\"name\": \"Мария\", \"count\": 5, \"price\": 60}", "{\"name\": \"Олег\", \"count\": 2, \"price\": 1500}", "{\"name\": \"Лейла\", \"count\": 7, \"price\": 15}", "{\"name\": \"Сергей\", \"count\": 10, \"price\": 30}", "{\"name\": \"Дилшод\", \"count\": 4, \"price\": 350}", "{\"name\": \"Ирина\", \"count\": 2, \"price\": 2300}", "{\"name\": \"Азиз\", \"count\": 6, \"price\": 120}", "{\"name\": \"Вера\", \"count\": 3, \"price\": 90}", "{\"name\": \"Пётр\", \"count\": 20, \"price\": 5}", "{\"name\": \"Камилла\", \"count\": 1, \"price\": 54000}"], marks: [.right, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right]),
        PromptLabCombo(rule: true, examples: true, shape: true, tokens: 194, answers: ["{\"name\": \"Анна\", \"count\": 3, \"price\": 250}", "{\"name\": \"Тимур\", \"count\": 12, \"price\": 40}", "{\"name\": \"Мария\", \"count\": 5, \"price\": 60}", "{\"name\": \"Олег\", \"count\": 2, \"price\": 1500}", "{\"name\": \"Лейла\", \"count\": 7, \"price\": 15}", "{\"name\": \"Сергей\", \"count\": 10, \"price\": 30}", "{\"name\": \"Дилшод\", \"count\": 4, \"price\": 350}", "{\"name\": \"Ирина\", \"count\": 2, \"price\": 2300}", "{\"name\": \"Азиз\", \"count\": 6, \"price\": 120}", "{\"name\": \"Вера\", \"count\": 3, \"price\": 90}", "{\"name\": \"Пётр\", \"count\": 20, \"price\": 5}", "{\"name\": \"Камилла\", \"count\": 1, \"price\": 54000}"], marks: [.right, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right, .right])
    ]
}
