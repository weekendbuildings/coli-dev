import Foundation

// Проверяет основу «Творца»: какие предметы спрятаны, метку свежести урока и подсказку для Claude.
// Verifies the Creator basics: hidden subjects, the lesson freshness label and the Claude prompt.

func require(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

@main
struct VerifyCreatorBasics {
    static func main() {
        // Subjects / Предметы
        for hidden in ["zoology", "chemistry", "physics", "biology"] {
            require(!SubjectVisibility.isVisible(hidden, showAll: false), "\(hidden) is hidden by default")
            require(SubjectVisibility.isVisible(hidden, showAll: true), "\(hidden) returns with the tick")
        }
        for shown in ["mathematics", "programming", "english"] {
            require(SubjectVisibility.isVisible(shown, showAll: false), "\(shown) is always visible")
        }

        // Freshness / Свежесть
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tashkent")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 23, minute: 30))!
        let fresh = LessonFreshness.make(checkedOn: "2026-11-07", intervalDays: 365, today: today, calendar: calendar)
        require(fresh == LessonFreshness(daysAgo: 1, intervalDays: 365), "checked yesterday is one day ago")
        require(fresh?.isOverdue == false, "one day of 365 is not overdue")
        require(fresh?.labelKey(russian: true) == "lesson.freshness.days.one", "1 день")
        require(fresh?.labelKey(russian: false) == "lesson.freshness.days.one", "1 day")

        let old = LessonFreshness.make(checkedOn: "2025-11-01", intervalDays: 365, today: today, calendar: calendar)
        require(old?.daysAgo == 372 && old?.isOverdue == true, "372 days of 365 is overdue")
        require(old?.labelKey(russian: true) == "lesson.freshness.days.few", "372 дня")
        require(old?.labelKey(russian: false) == "lesson.freshness.days.many", "372 days")

        let edge = LessonFreshness.make(checkedOn: "2025-11-08", intervalDays: 365, today: today, calendar: calendar)
        require(edge?.daysAgo == 365 && edge?.isOverdue == false, "the last day of the interval is still fresh")

        require(LessonFreshness.make(checkedOn: "2026-11-08", intervalDays: 30, today: today, calendar: calendar)?.labelKey(russian: true)
                == "lesson.freshness.today", "checked today")
        require(LessonFreshness.make(checkedOn: "2026-12-01", intervalDays: 30, today: today, calendar: calendar)?.daysAgo == 0,
                "a future date counts as today")
        require(LessonFreshness.make(checkedOn: "2026-10-27", intervalDays: nil, today: today, calendar: calendar)?.isOverdue == false,
                "without an interval nothing is overdue")
        require(LessonFreshness.make(checkedOn: "2026-10-27", intervalDays: 0, today: today, calendar: calendar)?.intervalDays == nil,
                "a zero interval is ignored")
        for bad in [nil, "", "2026-11", "вчера", "2026-02-30"] as [String?] {
            require(LessonFreshness.make(checkedOn: bad, intervalDays: 30, today: today, calendar: calendar) == nil, "bad date \(bad ?? "nil")")
        }
        let forms = [1: "one", 2: "few", 4: "few", 5: "many", 11: "many", 12: "many", 14: "many", 21: "one", 22: "few", 111: "many", 101: "one"]
        for (count, form) in forms {
            require(RussianPlural.form(count) == form, "plural of \(count)")
        }

        // Claude prompt / Подсказка для Claude
        let template = "Урок «%@» (%@).\nЦель: %@\nОбъясни простым русским языком."
        let prompt = AssistantExplainPrompt.make(template: template, title: "Автоматы", subject: "Программирование",
                                          goal: "Понять **жадный** выбор\nи 100% исследование.")
        require(prompt == "Урок «Автоматы» (Программирование).\nЦель: Понять жадный выбор и 100％ исследование.\nОбъясни простым русским языком.",
                "the prompt fills title, subject and a cleaned goal: \(prompt)")
        let long = String(repeating: "слово ", count: 300)
        let short = AssistantExplainPrompt.shortGoal(long)
        require(short.count <= AssistantExplainPrompt.goalLimit + 1 && short.hasSuffix("…") && !short.contains("  "), "a long goal is cut at a word")

        print("Creator basics verified / Основа «Творца» проверена")
    }
}
