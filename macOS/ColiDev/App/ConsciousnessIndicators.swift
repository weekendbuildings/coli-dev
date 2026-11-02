import Foundation

/// The 14 indicator properties of Butlin et al. (2023), checked against the small language model of the final project.
/// The checks were written for this course and are not an expert assessment.
/// 14 индикаторов из отчёта Butlin и др. (2023), проверенные на маленькой языковой модели финального проекта.
/// Разбор написан для этого курса и не является оценкой экспертов.
struct ConsciousnessIndicatorModel: Equatable {
    /// The indicators in the report's order, by theory. / Индикаторы в порядке отчёта, по теориям.
    static let indicators = [
        "rpt1", "rpt2",
        "gwt1", "gwt2", "gwt3", "gwt4",
        "hot1", "hot2", "hot3", "hot4",
        "ast1",
        "pp1",
        "ae1", "ae2"
    ]

    static func theory(of indicator: String) -> String { String(indicator.prefix(while: { $0.isLetter })) }

    /// Does the course's small transformer have this property? It reads text in one forward pass, has no modules or
    /// workspace, does not monitor itself, and has no goals or body, so by this check it has none of them.
    /// Есть ли это свойство у маленького трансформера курса? По этому разбору нет ни одного.
    static func modelHasIt(_ indicator: String) -> Bool { false }

    private(set) var answers: [String: Bool] = [:]

    mutating func answer(_ indicator: String, has: Bool) { answers[indicator] = has }

    mutating func reset() { answers = [:] }

    var answeredCount: Int { answers.count }
    var matching: Int { answers.filter { Self.modelHasIt($0.key) == $0.value }.count }
    var solvesChallenge: Bool { answers.count == Self.indicators.count }
}
