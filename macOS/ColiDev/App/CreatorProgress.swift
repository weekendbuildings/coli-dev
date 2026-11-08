import Foundation

// Plain logic of the "Creator progress" screen, kept free of SwiftUI so `scripts/verify_creator_progress.swift` can check it.
// Простая логика экрана «Прогресс Творца» без SwiftUI, чтобы её проверял `scripts/verify_creator_progress.swift`.

enum CreatorDates {
    /// Backend and lab timestamps: `2026-11-08T10:00:00Z`, sometimes with fractions of a second.
    /// Метки времени backend и проверок, иногда с долями секунды.
    static func parse(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }
}

// MARK: - "Build and check it yourself" / «Собери и проверь сам»

/// One run of a lab check, as `01_Projects/creator_labs/_checklib.py` appends it to `.results.json`.
/// Один прогон проверки, как его дописывает `_checklib.py`.
struct CreatorLabRun: Decodable, Equatable {
    let check: String
    let lesson: String
    let passed: Int
    let total: Int
    let at: String

    var isPassed: Bool { total > 0 && passed >= total }
    var date: Date? { CreatorDates.parse(at) }
}

/// What the screen shows for one lab: the latest run and whether any run passed every check.
/// Что экран показывает по заданию: последний прогон и был ли прогон, где пройдены все проверки.
struct CreatorLabSummary: Equatable {
    let latest: CreatorLabRun
    let everPassed: Bool
    let runs: Int
}

enum CreatorLabResults {
    static let fileName = ".results.json"
    /// Another folder for the results, for checks of the app itself. / Другая папка для проверки самого приложения.
    static let directoryEnvironmentKey = "COLIDEV_CREATOR_LABS_DIR"
    /// Lessons with a lab in `01_Projects/creator_labs`; `test_creator_labs.py` keeps this list equal to the checks.
    /// Уроки с заданием «Собери и проверь сам»; список сверяет `test_creator_labs.py`.
    static let lessons: [String] = [
        "attention_mechanism", "autograd_engine", "tokenizer_bpe", "rl_policy_gradient",
        "finetuning_and_lora", "interp_probes", "consciousness_integrated_information"
    ]

    /// `~/ai-path/creator_labs/.results.json`: the README copies the labs there. / Туда labs копирует README.
    static func fileURL(environment: [String: String], home: URL) -> URL {
        if let folder = environment[directoryEnvironmentKey], !folder.isEmpty {
            return URL(fileURLWithPath: (folder as NSString).expandingTildeInPath, isDirectory: true)
                .appendingPathComponent(fileName)
        }
        return home.appendingPathComponent("ai-path", isDirectory: true)
            .appendingPathComponent("creator_labs", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private struct Lenient: Decodable {
        let run: CreatorLabRun?
        init(from decoder: Decoder) throws { run = try? CreatorLabRun(from: decoder) }
    }

    private struct File: Decodable {
        let format: String
        let runs: [Lenient]
    }

    /// A broken or foreign file gives no runs; a broken entry is skipped. / Битый файл даёт пустой список, битая запись пропускается.
    static func parse(_ data: Data) -> [CreatorLabRun] {
        guard let file = try? JSONDecoder().decode(File.self, from: data), file.format == "creator-labs-results" else { return [] }
        return file.runs.compactMap(\.run)
    }

    /// Runs are appended in time order, so the last run of a lesson is its latest. / Последний прогон урока в файле — самый свежий.
    static func summaries(_ runs: [CreatorLabRun]) -> [String: CreatorLabSummary] {
        var result: [String: CreatorLabSummary] = [:]
        for run in runs where !run.lesson.isEmpty {
            let earlier = result[run.lesson]
            result[run.lesson] = CreatorLabSummary(
                latest: run,
                everPassed: (earlier?.everPassed ?? false) || run.isPassed,
                runs: (earlier?.runs ?? 0) + 1
            )
        }
        return result
    }
}

// MARK: - Bars / Столбики

/// Everything the screen knows about one path lesson. / Всё, что экран знает об одном уроке пути.
struct CreatorLessonFacts: Equatable {
    let resource: String
    let written: Bool
    let completed: Bool
    /// Knowledge checks from `/learning/progress`: `passed_task_type_counts` and `task_type_counts`.
    let checksPassed: Int
    let checksTotal: Int
    let hasLab: Bool
    let lab: CreatorLabSummary?

    var labDone: Bool { lab?.everPassed ?? false }
}

/// One bar: height is the share done, colour is the quality. / Столбик: высота — доля пройденного, цвет — качество.
struct CreatorBar: Identifiable, Equatable {
    let id: String
    let done: Int
    let total: Int
    /// Correct checks plus finished labs. / Верные проверки плюс выполненные задания.
    let good: Int
    /// All checks plus labs tried at least once. / Все проверки плюс задания, которые хоть раз запускались.
    let graded: Int

    var fraction: Double { total > 0 ? min(1, Double(done) / Double(total)) : 0 }
    /// No checks and no labs yet: no colour. / Нет ни проверок, ни заданий: цвета нет.
    var quality: Double? { graded > 0 ? Double(good) / Double(graded) : nil }
}

enum CreatorProgressMath {
    static func bar(id: String, lessons: [CreatorLessonFacts]) -> CreatorBar {
        bar(id: id, done: lessons.filter(\.completed).count, total: lessons.count, gradedBy: lessons)
    }

    /// A bar whose height comes from elsewhere (Skillbox ticks) and whose colour comes from its linked lessons.
    /// Столбик, высота которого берётся из другого места (галочки Skillbox), а цвет — из связанных уроков.
    static func bar(id: String, done: Int, total: Int, gradedBy lessons: [CreatorLessonFacts]) -> CreatorBar {
        CreatorBar(
            id: id,
            done: done,
            total: total,
            good: lessons.reduce(0) { $0 + $1.checksPassed + ($1.labDone ? 1 : 0) },
            graded: lessons.reduce(0) { $0 + $1.checksTotal + ($1.lab == nil ? 0 : 1) }
        )
    }

    /// Hue from red (0) through amber to green (1/3). / Оттенок от красного через жёлтый к зелёному.
    static func hue(forQuality quality: Double) -> Double { max(0, min(1, quality)) / 3 }
}

// MARK: - Day strip / Лента дней

/// One step recorded by the backend: a knowledge check or a trainer task in a lesson.
/// Один шаг, записанный backend: проверка знаний или задание тренажёра в уроке.
struct CreatorStepEvent: Equatable {
    let lessonID: String
    let isCheck: Bool
    let passed: Bool?
    let date: Date
}

enum CreatorBackendEvents {
    private struct Backup: Decodable {
        let assessmentEvents: [Event]
        enum CodingKeys: String, CodingKey { case assessmentEvents = "assessment_events" }
    }

    private struct Event: Decodable {
        let lessonID: String
        let createdAt: String
        let assessment: Assessment
        enum CodingKeys: String, CodingKey {
            case lessonID = "lesson_id"
            case createdAt = "created_at"
            case assessment
        }
    }

    private struct Assessment: Decodable {
        let taskType: String
        let passed: Bool?
        enum CodingKeys: String, CodingKey {
            case taskType = "task_type"
            case passed
        }
    }

    /// Every assessment event of `/learning/progress/backup` with its time; nil when the answer is not a backup.
    /// Все события проверок из `/learning/progress/backup` со временем; nil, если ответ не копия прогресса.
    static func parse(_ data: Data) -> [CreatorStepEvent]? {
        guard let backup = try? JSONDecoder().decode(Backup.self, from: data) else { return nil }
        return backup.assessmentEvents.compactMap { event in
            CreatorDates.parse(event.createdAt).map {
                CreatorStepEvent(lessonID: event.lessonID, isCheck: event.assessment.taskType == "knowledge_check",
                                 passed: event.assessment.passed, date: $0)
            }
        }
    }
}


enum CreatorActivity {
    /// A calendar whose weeks start on Monday. / Календарь, где неделя начинается с понедельника.
    static func mondayCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = timeZone
        return calendar
    }

    /// Steps per day: the start of the day → how many. / Шагов за день: начало дня → сколько.
    static func dayCounts(_ dates: [Date], calendar: Calendar) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for date in dates { counts[calendar.startOfDay(for: date), default: 0] += 1 }
        return counts
    }

    /// Days in a row with at least one step that end today. A day without steps yet today does not break it.
    /// Дни подряд хотя бы с одним шагом до сегодня. Пока сегодня шагов нет, серия ещё не прервана.
    static func streak(_ counts: [Date: Int], today: Date, calendar: Calendar) -> Int {
        var day = calendar.startOfDay(for: today)
        if (counts[day] ?? 0) == 0, let yesterday = calendar.date(byAdding: .day, value: -1, to: day) { day = yesterday }
        var length = 0
        while (counts[day] ?? 0) > 0 {
            length += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return length
    }

    /// `weeks` columns of seven days from Monday; the last column holds today and days after it are nil.
    /// Столбцы по семь дней с понедельника; в последнем сегодня, дни после него — nil.
    static func weeks(_ weeks: Int, today: Date, calendar: Calendar) -> [[Date?]] {
        let start = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: start)
        let sinceMonday = (weekday + 5) % 7
        guard weeks > 0, let thisMonday = calendar.date(byAdding: .day, value: -sinceMonday, to: start),
              let first = calendar.date(byAdding: .day, value: -7 * (weeks - 1), to: thisMonday) else { return [] }
        return (0..<weeks).map { column in
            (0..<7).map { row -> Date? in
                guard let day = calendar.date(byAdding: .day, value: column * 7 + row, to: first), day <= start else { return nil }
                return day
            }
        }
    }

    /// Colour level 0–4, as on GitHub. / Уровень цвета 0–4, как на GitHub.
    static func level(_ steps: Int) -> Int {
        switch steps {
        case ..<1: return 0
        case 1: return 1
        case 2...3: return 2
        case 4...6: return 3
        default: return 4
        }
    }
}

// MARK: - Time left / Сколько осталось

/// A rough honest estimate from the length of each lesson; the screen explains it in a caption.
/// Грубая честная оценка по длине каждого урока; экран объясняет её подписью.
enum CreatorTimeEstimate {
    /// Careful study reading, about half of ordinary reading speed. / Вдумчивое чтение, примерно вдвое медленнее обычного.
    static let wordsPerMinute = 100
    /// The trainer and the question at the end. / Тренажёр и вопрос в конце.
    static let practiceMinutes = 15
    /// One "build and check it yourself" lab. / Одно задание «Собери и проверь сам».
    static let labMinutes = 60

    /// Words of one language part: `## Русский` up to `## English`, or `## English` up to `## Sources`.
    /// Слова одной языковой части урока.
    static func words(inLesson markdown: String, russian: Bool) -> Int {
        let text = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let start = russian ? "\n## Русский" : "\n## English"
        let ends = russian ? ["\n## English"] : ["\n## Sources", "\n## Источники"]
        guard let from = text.range(of: start) else { return 0 }
        let rest = text[from.upperBound...]
        let to = ends.compactMap { rest.range(of: $0)?.lowerBound }.min() ?? rest.endIndex
        return rest[..<to].split(whereSeparator: { $0.isWhitespace })
            .filter { !$0.hasPrefix("```") && $0.contains { $0.isLetter || $0.isNumber } }
            .count
    }

    static func minutes(words: Int, hasLab: Bool) -> Int {
        (words + wordsPerMinute - 1) / wordsPerMinute + practiceMinutes + (hasLab ? labMinutes : 0)
    }

    /// Whole hours, at least one while anything is left. / Целые часы, не меньше одного, пока что-то осталось.
    static func hours(minutes: Int) -> Int {
        minutes <= 0 ? 0 : max(1, Int((Double(minutes) / 60).rounded()))
    }
}

// MARK: - Skillbox

/// `02_Areas/Programming/resources/skillbox_python_program.json`: topic titles and links only, no lesson content.
/// Только названия тем и ссылки, содержимое уроков Skillbox не копируется.
struct SkillboxProgram: Decodable, Equatable {
    let readOn: String
    let courses: [SkillboxCourse]

    enum CodingKeys: String, CodingKey {
        case readOn = "read_on"
        case courses
    }
}

struct SkillboxCourse: Decodable, Identifiable, Equatable {
    let id: String
    let title: String
    let url: String
    let role: String
    let progressOnRead: [String: String]?
    let modules: [SkillboxTopic]
    let path: [String]?
    let whyRu: String?
    let whyEn: String?

    enum CodingKeys: String, CodingKey {
        case id, title, url, role, modules, path
        case progressOnRead = "progress_on_read"
        case whyRu = "why_ru"
        case whyEn = "why_en"
    }
}

struct SkillboxTopic: Decodable, Equatable {
    let n: Int
    let title: String
    let done: Bool?
    let current: Bool?
    let path: [String]?
}

/// One row with a tick: a topic, or the whole course while its topics are not listed.
/// Строка с галочкой: тема или весь курс, пока его темы не выписаны.
struct SkillboxItem: Identifiable, Equatable {
    let key: String
    let courseID: String
    let number: Int?
    let title: String
    let initiallyDone: Bool
    let isCurrent: Bool
    let lessons: [String]

    var id: String { key }
}

enum SkillboxTrack: String, CaseIterable {
    case main
    case engineering
    case stage1
}

enum SkillboxProgress {
    static let defaultsKey = "creator.skillbox.checks"
    static let resourcePath = "02_Areas/Programming/resources/skillbox_python_program.json"
    /// The owner's order of the engineering track. / Порядок инженерной дорожки, как решил владелец.
    static let order = ["python-basic-plus", "python-basic", "python-advanced", "sql-basics", "django", "practice-python"]

    static func load(_ data: Data) -> SkillboxProgram? { try? JSONDecoder().decode(SkillboxProgram.self, from: data) }

    static func courses(of program: SkillboxProgram, track: SkillboxTrack) -> [SkillboxCourse] {
        let rank = { (course: SkillboxCourse) in order.firstIndex(of: course.id) ?? order.count }
        return program.courses.enumerated()
            .filter { $0.element.role == track.rawValue }
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }

    static func items(of course: SkillboxCourse) -> [SkillboxItem] {
        guard !course.modules.isEmpty else {
            return [SkillboxItem(key: course.id, courseID: course.id, number: nil, title: course.title,
                                 initiallyDone: false, isCurrent: false, lessons: course.path ?? [])]
        }
        return course.modules.map {
            SkillboxItem(key: "\(course.id)#\($0.n)", courseID: course.id, number: $0.n, title: $0.title,
                         initiallyDone: $0.done ?? false, isCurrent: $0.current ?? false, lessons: $0.path ?? [])
        }
    }

    static func items(of program: SkillboxProgram, track: SkillboxTrack) -> [SkillboxItem] {
        courses(of: program, track: track).flatMap(items(of:))
    }

    /// A tick the learner set wins over the state read from Skillbox. / Галочка ученика важнее состояния из Skillbox.
    static func isDone(_ item: SkillboxItem, ticks: [String: Bool]) -> Bool { ticks[item.key] ?? item.initiallyDone }

    static func loadTicks(_ defaults: UserDefaults) -> [String: Bool] {
        (defaults.dictionary(forKey: defaultsKey) as? [String: Bool]) ?? [:]
    }

    static func saveTick(_ done: Bool, for item: SkillboxItem, in defaults: UserDefaults) -> [String: Bool] {
        var ticks = loadTicks(defaults)
        ticks[item.key] = done
        defaults.set(ticks, forKey: defaultsKey)
        return ticks
    }
}

/// "Written this way now": only where the change is certain, with a link to the official documentation.
/// «Сейчас пишут так»: только там, где изменение известно надёжно, со ссылкой на официальную документацию.
struct SkillboxModernNote: Equatable {
    let textKey: String
    let url: String
}

enum SkillboxModernNotes {
    static let notes: [String: SkillboxModernNote] = [
        "python-basic-plus#4": SkillboxModernNote(
            textKey: "skillbox.modern.match", url: "https://docs.python.org/3/tutorial/controlflow.html#match-statements"),
        "python-advanced#4": SkillboxModernNote(
            textKey: "skillbox.modern.flask", url: "https://flask.palletsprojects.com/en/stable/quickstart/"),
        "python-advanced#9": SkillboxModernNote(
            textKey: "skillbox.modern.compose", url: "https://docs.docker.com/compose/releases/migrate/"),
        "python-advanced#20": SkillboxModernNote(
            textKey: "skillbox.modern.sqlalchemy", url: "https://docs.sqlalchemy.org/en/20/changelog/migration_20.html"),
        "python-advanced#21": SkillboxModernNote(
            textKey: "skillbox.modern.sqlalchemy", url: "https://docs.sqlalchemy.org/en/20/changelog/migration_20.html"),
        "python-advanced#25": SkillboxModernNote(
            textKey: "skillbox.modern.asyncio", url: "https://docs.python.org/3/library/asyncio-task.html#task-groups"),
        "python-advanced#26": SkillboxModernNote(
            textKey: "skillbox.modern.pydantic", url: "https://docs.pydantic.dev/latest/migration/"),
        "django": SkillboxModernNote(
            textKey: "skillbox.modern.django", url: "https://docs.djangoproject.com/en/stable/ref/urls/")
    ]
}
