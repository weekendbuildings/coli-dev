import Foundation

// Plain logic of the Creator app shell, kept free of SwiftUI so `scripts/verify_creator_basics.swift` can check it.
// Простая логика оболочки «Творца» без SwiftUI, чтобы её проверял `scripts/verify_creator_basics.swift`.

/// Which built-in subjects the sidebar and the catalogue show. / Какие встроенные предметы видны в боковой панели и каталоге.
enum SubjectVisibility {
    static let showAllDefaultsKey = "creator.showAllSubjects"
    /// Hidden until the learner ticks "Show all subjects". English stays: AI papers are in English.
    /// Tools, management and local models are not subjects and are never hidden.
    /// Спрятаны, пока не стоит галочка «Показывать все предметы». Английский остаётся: статьи по ИИ на английском.
    /// Инструменты, управление и локальные модели не предметы и не прячутся никогда.
    static let hiddenByDefault: Set<String> = ["zoology", "chemistry", "physics", "biology"]

    static func isVisible(_ subjectID: String, showAll: Bool) -> Bool {
        showAll || !hiddenByDefault.contains(subjectID)
    }
}

/// How long ago the lesson author checked the sources, from the lesson frontmatter.
/// Сколько дней назад автор урока сверял источники, по frontmatter урока.
struct LessonFreshness: Equatable {
    let daysAgo: Int
    let intervalDays: Int?

    /// The review interval has passed. / Срок перепроверки прошёл.
    var isOverdue: Bool {
        guard let intervalDays else { return false }
        return daysAgo > intervalDays
    }

    /// `checkedOn` is `YYYY-MM-DD`. A date in the future counts as today. / Дата в будущем считается сегодняшней.
    static func make(checkedOn: String?, intervalDays: Int?, today: Date, calendar: Calendar = .current) -> LessonFreshness? {
        guard let checkedOn else { return nil }
        let parts = checkedOn.trimmingCharacters(in: .whitespaces).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let checked = calendar.date(from: components),
              calendar.component(.day, from: checked) == parts[2] else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: checked), to: calendar.startOfDay(for: today)).day ?? 0
        return LessonFreshness(daysAgo: max(days, 0), intervalDays: intervalDays.flatMap { $0 > 0 ? $0 : nil })
    }

    /// The `L10n` key of the "checked N days ago" line. / Ключ `L10n` для строки «сверены N дней назад».
    func labelKey(russian: Bool) -> String {
        if daysAgo == 0 { return "lesson.freshness.today" }
        if russian { return "lesson.freshness.days." + RussianPlural.form(daysAgo) }
        return daysAgo == 1 ? "lesson.freshness.days.one" : "lesson.freshness.days.many"
    }
}

/// Russian plural form of a count: 1 день, 2 дня, 5 дней, 21 день, 11 дней.
/// Русская форма множественного числа.
enum RussianPlural {
    static func form(_ count: Int) -> String {
        let value = abs(count)
        let lastTwo = value % 100
        let last = value % 10
        if (11...14).contains(lastTwo) { return "many" }
        if last == 1 { return "one" }
        if (2...4).contains(last) { return "few" }
        return "many"
    }
}

/// The prompt that "Ask Claude" copies. It only opens claude.ai in the browser: no API call, nothing is sent by itself.
/// Подсказка, которую копирует «Спросить Claude». Кнопка только открывает claude.ai в браузере: без API, сама ничего не отправляет.
enum AskClaudePrompt {
    static let newChatURL = URL(string: "https://claude.ai/new")!
    /// Long goals are cut so the prompt stays readable. / Длинная цель обрезается, чтобы подсказка оставалась читаемой.
    static let goalLimit = 600

    /// `template` comes from `L10n` (`lesson.askClaude.prompt`) and has three `%@`: title, subject, goal.
    /// `template` берётся из `L10n` и содержит три `%@`: название, предмет, цель.
    static func make(template: String, title: String, subject: String, goal: String) -> String {
        String(format: template, clean(title), clean(subject), shortGoal(goal))
    }

    static func shortGoal(_ goal: String) -> String {
        let text = clean(goal)
        guard text.count > goalLimit else { return text }
        let cut = text.prefix(goalLimit)
        let end = cut.lastIndex(of: " ") ?? cut.endIndex
        return String(cut[..<end]) + "…"
    }

    /// One line, no Markdown emphasis, no stray `%` that `String(format:)` could read. / Одна строка без Markdown и без `%`.
    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "%", with: "％")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
