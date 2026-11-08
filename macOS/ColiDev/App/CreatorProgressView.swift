import AppKit
import SwiftUI

/// Data the progress screen reads once from the app bundle. / Данные, которые экран читает из пакета приложения один раз.
@MainActor
enum CreatorProgressData {
    static let program: SkillboxProgram? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent(SkillboxProgress.resourcePath),
              let data = try? Data(contentsOf: url) else { return nil }
        return SkillboxProgress.load(data)
    }()

    private static var minutesCache: [String: Int] = [:]

    /// Study minutes of one written lesson; see `CreatorTimeEstimate`. / Минуты на один готовый урок.
    static func minutes(for lesson: AIPathLesson, russian: Bool) -> Int {
        let key = "\(lesson.lessonID).\(russian)"
        if let cached = minutesCache[key] { return cached }
        let words = CurriculumCatalog.lessonMarkdown(for: lesson.subject, resource: lesson.resource)
            .map { CreatorTimeEstimate.words(inLesson: $0, russian: russian) } ?? 0
        let minutes = CreatorTimeEstimate.minutes(words: words, hasLab: CreatorLabResults.lessons.contains(lesson.resource))
        minutesCache[key] = minutes
        return minutes
    }

    static var labsFileURL: URL {
        CreatorLabResults.fileURL(environment: ProcessInfo.processInfo.environment,
                                  home: FileManager.default.homeDirectoryForCurrentUser)
    }
}

/// "Creator progress": bars by module, the day strip, what is left, every lesson and the Skillbox topics.
/// «Прогресс Творца»: столбики по модулям, лента дней, что осталось, каждый урок и темы Skillbox.
struct CreatorProgressView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var backendSupervisor: LocalBackendSupervisor
    let openLesson: (AIPathLesson) -> Void
    /// The future "Explain" right inside the app (`claude -p` by subscription, a local model as the fallback).
    /// While it is nil the button is hidden: the old "Ask Claude" opened a website and did not suit the owner.
    /// Будущая кнопка «Объяснить» прямо в приложении (`claude -p` по подписке, запасной вариант — локальная модель).
    /// Пока nil, кнопки нет: прежняя «Спросить Claude» открывала сайт и владельцу не подошла.
    var explain: ((SkillboxItem, SkillboxCourse, SkillboxTrack) -> Void)? = nil

    @State private var labRuns: [CreatorLabRun] = []
    @State private var labFileDate: Date?
    @State private var events: [CreatorStepEvent] = []
    @State private var eventsLoaded = false
    @State private var ticks: [String: Bool] = SkillboxProgress.loadTicks(.standard)
    @State private var selectedBar: String?

    private let weeks = 20
    private let labPoll = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    private let calendar = CreatorActivity.mondayCalendar()

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func format(_ key: String, _ values: String...) -> String { String(format: text(key), arguments: values.map { $0 as CVarArg }) }
    private func percent(_ value: Double) -> String { L10n.number(value * 100, fractionDigits: 0, store.language) + " %" }

    // MARK: Facts

    private var labSummaries: [String: CreatorLabSummary] { CreatorLabResults.summaries(labRuns) }

    private func facts(_ lesson: AIPathLesson, labs: [String: CreatorLabSummary]) -> CreatorLessonFacts {
        let evidence = store.studyAssessmentEvidence[lesson.lessonID]
        return CreatorLessonFacts(
            resource: lesson.resource,
            written: AIPathCatalog.topics[lesson.resource] != nil,
            completed: store.isComplete(lessonID: lesson.lessonID),
            checksPassed: evidence?.passedTaskTypeCounts?["knowledge_check"] ?? 0,
            checksTotal: evidence?.taskTypeCounts["knowledge_check"] ?? 0,
            hasLab: CreatorLabResults.lessons.contains(lesson.resource),
            lab: labs[lesson.resource]
        )
    }

    private func skillboxBar(_ track: SkillboxTrack, labs: [String: CreatorLabSummary]) -> CreatorBar? {
        guard let program = CreatorProgressData.program else { return nil }
        let items = SkillboxProgress.items(of: program, track: track)
        let linked = Array(Set(items.flatMap(\.lessons))).sorted()
            .map { facts(AIPathLesson(subject: .programming, resource: $0), labs: labs) }
        return CreatorProgressMath.bar(
            id: "skillbox.\(track.rawValue)",
            done: items.filter { SkillboxProgress.isDone($0, ticks: ticks) }.count,
            total: items.count,
            gradedBy: linked
        )
    }

    private struct BarRow: Identifiable {
        let scene: CreatorSceneBar
        let title: String
        var id: String { scene.bar.id }
    }

    private func barRows(labs: [String: CreatorLabSummary]) -> [BarRow] {
        var rows = AIPathCatalog.modules.map { module -> BarRow in
            let bar = CreatorProgressMath.bar(id: "module\(module.number)", lessons: module.lessons.map { facts($0, labs: labs) })
            return BarRow(scene: sceneBar(bar, short: String(module.number), skillbox: false),
                          title: format("progress.bar.module", String(module.number), text(module.titleKey)))
        }
        for track in [SkillboxTrack.main, .engineering] {
            if let bar = skillboxBar(track, labs: labs) {
                rows.append(BarRow(scene: sceneBar(bar, short: text("progress.bar.short.\(track.rawValue)"), skillbox: true),
                                   title: text("progress.bar.\(track.rawValue)")))
            }
        }
        return rows
    }

    private func sceneBar(_ bar: CreatorBar, short: String, skillbox: Bool) -> CreatorSceneBar {
        let quality = bar.quality.map(percent) ?? text("progress.bar.noQuality")
        return CreatorSceneBar(bar: bar, shortLabel: short, numbers: "\(bar.done)/\(bar.total) · \(quality)", isSkillbox: skillbox)
    }

    private func barDetail(_ row: BarRow) -> String {
        let bar = row.scene.bar
        return format("progress.bar.detail", row.title, String(bar.done), String(bar.total),
                      bar.quality.map(percent) ?? text("progress.bar.noQuality"))
    }

    /// Every step with a time: backend events, the latest review of each lesson, lab runs.
    /// Каждый шаг со временем: события backend, последняя отметка урока, прогоны проверок.
    private var reviewDates: [(lessonID: String, date: Date)] {
        store.studyProgress.values.compactMap { record in
            record.lastReviewedAt.flatMap(CreatorDates.parse).map { (record.lessonID, $0) }
        }
    }

    private var stepDates: [Date] {
        events.map(\.date) + reviewDates.map(\.date) + labRuns.compactMap(\.date)
    }

    // MARK: Body

    var body: some View {
        let labs = labSummaries
        let rows = barRows(labs: labs)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                HStack(alignment: .top, spacing: 14) {
                    todayCard(labs: labs)
                    nextCard
                    leftCard(labs: labs)
                }
                barsCard(rows)
                daysCard
                lessonsCard(labs: labs)
                skillboxSection(labs: labs)
            }
            .padding(24)
            .frame(maxWidth: 1040, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("creatorProgress.screen")
        .task { await reload() }
        .onReceive(labPoll) { _ in reloadLabsIfChanged() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await reload() }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(text("nav.creatorProgress")).font(.largeTitle.bold())
                Text(text("progress.motto"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppPalette.accent.color)
                    .accessibilityIdentifier("creatorProgress.motto")
            }
            Spacer()
            Button { Task { await reload() } } label: { Label(text("progress.refresh"), systemImage: "arrow.clockwise") }
                .accessibilityIdentifier("creatorProgress.refresh")
        }
    }

    // MARK: Today, next, left

    private func card<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .coliContentCard(tint: AppPalette.accent.color)
    }

    private func todayCard(labs: [String: CreatorLabSummary]) -> some View {
        let today = calendar.startOfDay(for: Date())
        let isToday = { (date: Date) in calendar.isDate(date, inSameDayAs: today) }
        let checks = events.filter { $0.isCheck && isToday($0.date) }
        let practice = events.filter { !$0.isCheck && isToday($0.date) }.count
        let lessons = reviewDates.filter { isToday($0.date) }.count
        let runs = labRuns.filter { $0.date.map(isToday) ?? false }
        let steps = checks.count + practice + lessons + runs.count
        return card(text("progress.today.title"), symbol: "checkmark.seal") {
            if steps == 0 {
                Text(text("progress.today.none")).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(format("progress.today.steps", String(steps))).font(.title2.bold()).monospacedDigit()
                    .accessibilityIdentifier("creatorProgress.today.steps")
                if !checks.isEmpty {
                    Text(format("progress.today.checks", String(checks.count), String(checks.filter { $0.passed == true }.count)))
                }
                if practice > 0 { Text(format("progress.today.practice", String(practice))) }
                if lessons > 0 { Text(format("progress.today.lessons", String(lessons))) }
                if !runs.isEmpty {
                    Text(format("progress.today.labs", String(runs.count), String(runs.filter(\.isPassed).count)))
                }
            }
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("creatorProgress.today")
    }

    private var nextCard: some View {
        let available = Set(AIPathCatalog.available.map(\.resource))
        let next = AIPathCatalog.next(completed: store.completedLessonIDs, available: available)
        return card(text("progress.next.title"), symbol: "arrow.forward.circle") {
            if let next {
                if let module = AIPathCatalog.module(of: next) {
                    Text(format("progress.bar.module", String(module.number), text(module.titleKey)))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(AIPathCatalog.topics[next.resource]?.name.value(in: store.language) ?? next.resource)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Button { openLesson(next) } label: { Label(text("progress.next.open"), systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("creatorProgress.next.open")
            } else {
                Text(text("progress.next.done")).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("creatorProgress.next")
    }

    private func leftCard(labs: [String: CreatorLabSummary]) -> some View {
        let russian = store.language == .ru
        let open = AIPathCatalog.lessons.filter { !store.isComplete(lessonID: $0.lessonID) }
        let written = open.filter { AIPathCatalog.topics[$0.resource] != nil }
        let minutes = written.reduce(0) { $0 + CreatorProgressData.minutes(for: $1, russian: russian) }
        let planned = open.count - written.count
        return card(text("progress.left.title"), symbol: "hourglass") {
            Text(format("progress.left.value", String(written.count), String(CreatorTimeEstimate.hours(minutes: minutes))))
                .font(.title2.bold()).monospacedDigit()
                .accessibilityIdentifier("creatorProgress.left.value")
            if planned > 0 {
                Text(format("progress.left.planned", String(planned))).font(.callout).foregroundStyle(.secondary)
            }
            Text(format("progress.left.method", String(CreatorTimeEstimate.wordsPerMinute),
                        String(CreatorTimeEstimate.practiceMinutes), String(CreatorTimeEstimate.labMinutes)))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("creatorProgress.left")
    }

    // MARK: Bars

    private func barsCard(_ rows: [BarRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text("progress.bars.title")).font(.title2.bold())
            CreatorBars3DView(
                bars: rows.map(\.scene),
                selected: selectedBar,
                skillboxLabel: "Skillbox",
                onSelect: { selectedBar = $0 }
            )
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
            .accessibilityIdentifier("creatorProgress.scene")
            Text(rows.first { $0.id == selectedBar }.map(barDetail) ?? text("progress.bars.hint"))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier("creatorProgress.selectedBar")
            flatBars(rows)
            Text(text("progress.bars.legend"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .coliContentCard(tint: AppPalette.accent.color)
    }

    /// The same bars as plain rows: for VoiceOver and for a quick look. / Те же столбики строками: для VoiceOver.
    private func flatBars(_ rows: [BarRow]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], alignment: .leading, spacing: 5) {
            ForEach(rows) { row in
                Button { selectedBar = row.id } label: {
                    HStack(spacing: 8) {
                        Text(row.scene.shortLabel).font(.caption.bold()).monospacedDigit().frame(width: 30, alignment: .trailing)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.15))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(nsColor: CreatorBars3DView.color(forQuality: row.scene.bar.quality)))
                                    .frame(width: max(3, proxy.size.width * row.scene.bar.fraction))
                            }
                        }
                        .frame(height: 12)
                        Text(row.scene.numbers).font(.caption).monospacedDigit().frame(width: 104, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(barDetail(row))
                .accessibilityAddTraits(row.id == selectedBar ? .isSelected : [])
                .accessibilityIdentifier("creatorProgress.bar.\(row.id)")
            }
        }
    }

    // MARK: Day strip

    private var daysCard: some View {
        let today = Date()
        let counts = CreatorActivity.dayCounts(stepDates, calendar: calendar)
        let grid = CreatorActivity.weeks(weeks, today: today, calendar: calendar)
        let total = grid.joined().compactMap { $0 }.reduce(0) { $0 + (counts[$1] ?? 0) }
        let streak = CreatorActivity.streak(counts, today: today, calendar: calendar)
        let dayFormat = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Locale(identifier: store.language == .ru ? "ru_RU" : "en_US"))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(text("progress.days.title")).font(.title2.bold())
                Spacer()
                Text(format("progress.days.streak", String(streak))).font(.headline).monospacedDigit()
                    .accessibilityIdentifier("creatorProgress.streak")
            }
            HStack(alignment: .top, spacing: 3) {
                ForEach(Array(grid.enumerated()), id: \.offset) { _, column in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { row in
                            let day = column[row]
                            let steps = day.map { counts[$0] ?? 0 } ?? 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(day == nil ? Color.clear : dayColor(CreatorActivity.level(steps)))
                                .frame(width: 14, height: 14)
                                .help(day.map { format("progress.days.cell", $0.formatted(dayFormat), String(steps)) } ?? "")
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(format("progress.days.total", String(weeks), String(total)) + ". " + format("progress.days.streak", String(streak)))
            .accessibilityIdentifier("creatorProgress.days")
            Text(format("progress.days.total", String(weeks), String(total))).font(.callout).monospacedDigit()
            Text(text("progress.days.caption")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !eventsLoaded {
                Text(text("progress.days.partial")).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(16)
        .coliContentCard(tint: .green)
    }

    private func dayColor(_ level: Int) -> Color {
        level == 0 ? Color.secondary.opacity(0.15) : Color.green.opacity([0, 0.35, 0.55, 0.78, 1][level])
    }

    // MARK: Lessons

    private func lessonsCard(labs: [String: CreatorLabSummary]) -> some View {
        let nextModule = AIPathCatalog.next(completed: store.completedLessonIDs, available: Set(AIPathCatalog.available.map(\.resource)))
            .flatMap(AIPathCatalog.module(of:))?.number
        return VStack(alignment: .leading, spacing: 10) {
            Text(text("progress.lessons.title")).font(.title2.bold())
            ForEach(AIPathCatalog.modules.filter { !$0.lessons.isEmpty }) { module in
                CreatorModuleDisclosure(
                    title: format("progress.bar.module", String(module.number), text(module.titleKey)),
                    startsExpanded: module.number == nextModule
                ) {
                    ForEach(module.lessons.filter { AIPathCatalog.topics[$0.resource] != nil }) { lesson in
                        lessonRow(lesson, facts: facts(lesson, labs: labs))
                    }
                }
            }
            Text(format("progress.lessons.labsFile", CreatorProgressData.labsFileURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")))
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }
        .padding(16)
        .coliContentCard(tint: AppPalette.accent.color)
    }

    private func lessonRow(_ lesson: AIPathLesson, facts: CreatorLessonFacts) -> some View {
        HStack(spacing: 10) {
            Image(systemName: facts.completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(facts.completed ? Color.green : Color.secondary)
                .accessibilityLabel(text(facts.completed ? "progress.lesson.done" : "progress.lesson.notDone"))
            Button { openLesson(lesson) } label: {
                Text(AIPathCatalog.topics[lesson.resource]?.name.value(in: store.language) ?? lesson.resource)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 8)
            Text(facts.checksTotal > 0
                 ? format("progress.lesson.checks", String(facts.checksPassed), String(facts.checksTotal))
                 : text("progress.lesson.noChecks"))
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            if facts.hasLab {
                labBadge(facts.lab)
            }
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("creatorProgress.lesson.\(lesson.resource)")
    }

    @ViewBuilder
    private func labBadge(_ lab: CreatorLabSummary?) -> some View {
        if let lab, lab.everPassed {
            Text(text("progress.lesson.labDone")).font(.caption.bold()).foregroundStyle(.green)
                .accessibilityIdentifier("creatorProgress.lab.done")
        } else if let lab {
            Text(format("progress.lesson.labLatest", String(lab.latest.passed), String(lab.latest.total)))
                .font(.caption).foregroundStyle(.orange).monospacedDigit()
        } else {
            Text(text("progress.lesson.labNotRun")).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Skillbox

    @ViewBuilder
    private func skillboxSection(labs: [String: CreatorLabSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text("skillbox.title")).font(.title2.bold())
            if let program = CreatorProgressData.program {
                Text(format("skillbox.note", program.readOn)).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(SkillboxTrack.allCases, id: \.self) { track in
                    Text(text("skillbox.track.\(track.rawValue)")).font(.headline).padding(.top, 6)
                    ForEach(SkillboxProgress.courses(of: program, track: track)) { course in
                        courseCard(course, track: track, readOn: program.readOn)
                    }
                }
            } else {
                Text(text("skillbox.unavailable")).foregroundStyle(.orange)
            }
        }
        .accessibilityIdentifier("creatorProgress.skillbox")
    }

    private func courseCard(_ course: SkillboxCourse, track: SkillboxTrack, readOn: String) -> some View {
        let items = SkillboxProgress.items(of: course)
        let done = items.filter { SkillboxProgress.isDone($0, ticks: ticks) }.count
        let onRead = ["videos", "practical", "tests"].compactMap { key in
            course.progressOnRead?[key].map { format("skillbox.\(key)", $0) }
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(course.title).font(.title3.weight(.semibold))
                Spacer()
                if items.count > 1 {
                    Text(format("skillbox.course.done", String(done), String(items.count))).font(.callout).monospacedDigit()
                }
            }
            if !onRead.isEmpty {
                Text(format("skillbox.onRead", readOn, onRead.joined(separator: " · "))).font(.caption).foregroundStyle(.secondary)
            }
            if let why = store.language == .ru ? course.whyRu : course.whyEn {
                Text(why).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(items) { item in
                skillboxRow(item, course: course, track: track)
            }
        }
        .padding(14)
        .coliContentCard(tint: track == .main ? AppPalette.accent.color : .secondary)
        .accessibilityIdentifier("skillbox.course.\(course.id)")
    }

    private func tickBinding(_ item: SkillboxItem) -> Binding<Bool> {
        Binding(
            get: { SkillboxProgress.isDone(item, ticks: ticks) },
            set: { ticks = SkillboxProgress.saveTick($0, for: item, in: .standard) }
        )
    }

    private func skillboxRow(_ item: SkillboxItem, course: SkillboxCourse, track: SkillboxTrack) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Toggle(isOn: tickBinding(item)) {
                    Text(item.number.map { "\($0). \(item.title)" } ?? item.title).multilineTextAlignment(.leading)
                }
                .toggleStyle(.checkbox)
                .help(text("skillbox.tick.help"))
                .accessibilityIdentifier("skillbox.tick.\(item.key)")
                if item.isCurrent {
                    Text(text("skillbox.current"))
                        .font(.caption.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(AppPalette.accent.color.opacity(0.2)))
                }
                Spacer(minLength: 8)
                if let url = URL(string: course.url) {
                    Link(destination: url) { Image(systemName: "arrow.up.right.square") }
                        .help(text("skillbox.open"))
                        .accessibilityLabel(text("skillbox.open"))
                }
                pathLessonButton(item)
                if let explain {
                    Button { explain(item, course, track) } label: { Image(systemName: "text.bubble") }
                        .buttonStyle(.borderless)
                        .help(text("skillbox.explain.help"))
                        .accessibilityLabel(text("skillbox.explain"))
                        .accessibilityIdentifier("skillbox.explain.\(item.key)")
                }
            }
            if let note = SkillboxModernNotes.notes[item.key] {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "sparkles").foregroundStyle(.orange)
                    (Text(text("skillbox.modern.title") + ": ").bold() + Text(text(note.textKey)))
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = URL(string: note.url) {
                        Link(text("skillbox.modern.docs"), destination: url)
                    }
                }
                .font(.caption)
                .padding(.leading, 22)
                .accessibilityIdentifier("skillbox.modern.\(item.key)")
            }
        }
    }

    @ViewBuilder
    private func pathLessonButton(_ item: SkillboxItem) -> some View {
        let lessons = item.lessons.map { AIPathLesson(subject: .programming, resource: $0) }
            .filter { AIPathCatalog.topics[$0.resource] != nil }
        let name = { (lesson: AIPathLesson) in AIPathCatalog.topics[lesson.resource]?.name.value(in: store.language) ?? lesson.resource }
        if lessons.count == 1, let lesson = lessons.first {
            Button { openLesson(lesson) } label: { Image(systemName: "book") }
                .buttonStyle(.borderless)
                .help(text("skillbox.pathLesson") + ": " + name(lesson))
                .accessibilityLabel(text("skillbox.pathLesson") + ": " + name(lesson))
        } else if lessons.count > 1 {
            Menu {
                ForEach(lessons) { lesson in
                    Button(name(lesson)) { openLesson(lesson) }
                }
            } label: { Image(systemName: "book") }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(text("skillbox.pathLesson"))
                .accessibilityLabel(text("skillbox.pathLesson"))
        }
    }

    // MARK: Loading

    private func reload() async {
        reloadLabs()
        guard backendSupervisor.isReady else {
            eventsLoaded = false
            return
        }
        await store.syncStudyProgress()
        if let data = try? await OrchestratorClient.learningProgressBackup(), let parsed = CreatorBackendEvents.parse(data) {
            events = parsed
            eventsLoaded = true
        } else {
            eventsLoaded = false
        }
    }

    private func reloadLabs() {
        let url = CreatorProgressData.labsFileURL
        labFileDate = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        labRuns = (try? Data(contentsOf: url)).map(CreatorLabResults.parse) ?? []
    }

    /// The owner runs a check in Terminal: a new ✓ appears within seconds. / Владелец запускает проверку в Терминале: ✓ появляется за секунды.
    private func reloadLabsIfChanged() {
        let url = CreatorProgressData.labsFileURL
        let date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        if date != labFileDate { reloadLabs() }
    }
}

/// A module of the lesson list that opens and closes. / Модуль списка уроков, который раскрывается и сворачивается.
private struct CreatorModuleDisclosure<Content: View>: View {
    let title: String
    let content: Content
    @State private var expanded: Bool

    init(title: String, startsExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        _expanded = State(initialValue: startsExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) { content }.padding(.top, 6)
        } label: {
            // The whole title opens the module, not only the arrow. / Модуль раскрывает всё название, а не только стрелка.
            Button { expanded.toggle() } label: {
                Text(title).font(.headline).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
