import SwiftUI
import AppKit
import UniformTypeIdentifiers

private struct LearningProgressBackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct IntroLessonUnavailableView: View {
    @EnvironmentObject private var store: LearningStore

    let subject: Subject
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(subject.tint)
                .accessibilityHidden(true)
            Text(L10n.text("lesson.intro.unavailable.title", store.language))
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier("lesson.intro.unavailable.title")
            Text(L10n.text("lesson.intro.unavailable.message", store.language))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onBack) {
                Label(
                    L10n.text("lesson.intro.unavailable.back", store.language),
                    systemImage: "arrow.left"
                )
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("lesson.intro.unavailable.back")
        }
        .frame(maxWidth: 520)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var backendSupervisor: LocalBackendSupervisor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: AppSection? = .today
    @State private var practiceFocusRoute: StudyLessonRoute?
    @State private var didOpenCell3DUITestRoute = false
    @State private var didOpenFrictionUITestRoute = false
    @AppStorage(StudyProgressionPolicy.previewLockedLessonsDefaultsKey) private var previewLockedLessons = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Label { Text(L10n.text("nav.today", store.language)) } icon: { Image(systemName: "sparkles") }
                        .tag(AppSection.today)
                    Label { Text(L10n.text("nav.subjects", store.language)) } icon: { Image(systemName: "square.grid.2x2") }
                        .tag(AppSection.subjects)
                } header: {
                    Text(L10n.text("nav.yourLearning", store.language))
                }

                Section {
                    ForEach(Subject.allCases) { subject in
                        Label { Text(subject.title(in: store.language)) } icon: {
                            Image(systemName: subject.symbol)
                                .foregroundStyle(Color.accentColor)
                        }
                            .tag(AppSection.subject(subject))
                    }
                    ForEach(store.customCurriculum.subjects) { subject in
                        Label {
                            Text(subject.name.value(in: store.language.rawValue))
                        } icon: {
                            Image(systemName: "books.vertical.fill")
                        }
                        .tag(AppSection.customSubject(subject.id))
                    }
                } header: {
                    Text(L10n.text("nav.subjects", store.language))
                }

                Section {
                    Label { Text(L10n.text("nav.management", store.language)) } icon: {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                    .tag(AppSection.management)
                    .accessibilityIdentifier("sidebar.management")
                    Label { Text(L10n.text("management.models", store.language)) } icon: {
                        Image(systemName: "cpu")
                    }
                    .tag(AppSection.localModels)
                    .accessibilityIdentifier("sidebar.local-models")
                    Label { Text(L10n.text("nav.settings", store.language)) } icon: { Image(systemName: "gearshape") }
                        .tag(AppSection.settings)
                        .accessibilityIdentifier("sidebar.settings")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("ColiDev")
            // The default column cut “Программирование”, “Локальные модели” and “Направления” on every CI runner.
            .navigationSplitViewColumnWidth(min: 210, ideal: 230)
        } detail: {
            Group {
                switch selection ?? .today {
                case .today:
                    TodayView(
                        open: open,
                        openCustom: openCustom,
                        openCourseLesson: { route, focusPractice in
                            openRecommendedLesson(route, focusPractice: focusPractice)
                        },
                        openDueReview: openDueReview
                    )
                    .onAppear(perform: openCell3DUITestRouteIfNeeded)
                case .subjects:
                    SubjectCatalogView(open: open, openCustom: openCustom)
                case .subject(let subject):
                    SubjectOverviewView(
                        subject: subject,
                        openCourseLesson: { resource in
                            openCourseLesson(subject: subject, resource: resource)
                        },
                        openCustomTopic: { selection = .builtInCustomTopic(subject, $0) }
                    ) {
                        selection = .lesson(subject)
                    }
                case .lesson(let subject):
                    if !shouldSimulateMissingIntroRoute,
                       let route = CurriculumCatalog.introLessonRoute(for: subject) {
                        CurriculumModuleView(
                            subject: subject,
                            resource: route.resource,
                            progressLessonID: route.progressLessonID,
                            focusPracticeOnOpen: practiceFocusRoute == StudyLessonRoute(
                                subjectID: "intro",
                                resource: subject.rawValue
                            ),
                            onPracticeFocusCompleted: { practiceFocusRoute = nil }
                        )
                    } else {
                        IntroLessonUnavailableView(subject: subject) {
                            selection = .subject(subject)
                        }
                    }
                case .courseLesson(let subject, let resource):
                    CurriculumModuleView(
                        subject: subject,
                        resource: resource,
                        focusPracticeOnOpen: practiceFocusRoute == StudyLessonRoute(
                            subjectID: subject.rawValue,
                            resource: resource
                        ),
                        onPracticeFocusCompleted: { practiceFocusRoute = nil }
                    )
                case .customSubject(let subjectID):
                    CustomSubjectDetailView(
                        subjectID: subjectID,
                        openTopic: { selection = .customTopic(subjectID, $0) },
                        onDelete: { selection = .subjects }
                    )
                case .customTopic(let subjectID, let topicID):
                    CustomTopicStudyView(subjectID: subjectID, topicID: topicID) {
                        selection = .customSubject(subjectID)
                    }
                case .builtInCustomTopic(let subject, let topicID):
                    BuiltInCustomTopicStudyView(subject: subject, topicID: topicID) {
                        selection = .subject(subject)
                    }
                case .management:
                    ManagementView(openSettings: { selection = .settings })
                        .id(AppSection.management)
                case .localModels:
                    ManagementView(openSettings: { selection = .settings }, initialPane: .models)
                        .id(AppSection.localModels)
                case .settings:
                    SettingsView()
                }
            }
            .id(selection)
            .transition(.opacity)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: ColiDevVisualSystem.routineTransitionDuration),
                value: selection
            )
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Picker(selection: $store.language, label: Text(L10n.text("settings.language", store.language))) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.shortLabel).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 112)
                    .accessibilityLabel(Text(L10n.text("settings.language", store.language)))
                }
            }
        }
        .task {
            guard await backendSupervisor.ensureRunning() else { return }
            await store.refreshAutoCostPolicy()
            await store.syncStudyProgress()
        }
    }

    private func open(_ subject: Subject) {
        practiceFocusRoute = nil
        selection = .subject(subject)
    }

    private var shouldSimulateMissingIntroRoute: Bool {
        ProcessInfo.processInfo.environment["COLIDEV_UI_TEST_MISSING_INTRO_ROUTE"] == "1"
    }

    /// The lesson a UI test opens directly: the friction video lesson, or any lesson given as "subject/resource".
    private var uiTestLessonRoute: (subject: Subject, resource: String)? {
        let environment = ProcessInfo.processInfo.environment
        if environment["COLIDEV_UI_TEST_FRICTION_LESSON"] == "1" { return (.physics, "static_and_kinetic_friction") }
        let parts = (environment["COLIDEV_UI_TEST_LESSON"] ?? "").split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2, let subject = Subject(rawValue: parts[0]), !parts[1].isEmpty else { return nil }
        return (subject, parts[1])
    }

    private func openCell3DUITestRouteIfNeeded() {
        if !didOpenFrictionUITestRoute, let target = uiTestLessonRoute {
            didOpenFrictionUITestRoute = true
            // The lesson tests cover the lesson itself, not its earlier prerequisites.
            // Keep this route override limited to the dedicated UI-test launch environment.
            DispatchQueue.main.async {
                let route = StudyLessonRoute(subjectID: target.subject.rawValue, resource: target.resource)
                practiceFocusRoute = route
                store.rememberCourseLesson(subject: target.subject, resource: route.resource)
                selection = .courseLesson(target.subject, route.resource)
            }
            return
        }

        guard !didOpenCell3DUITestRoute,
              UserDefaults.standard.bool(forKey: "colidev.uiTestCell3D") else { return }

        didOpenCell3DUITestRoute = true
        // Let SwiftUI present its first valid sidebar selection before navigating to a lesson.
        // Даём SwiftUI сначала показать валидный пункт боковой панели, а затем открываем урок.
        let route = StudyLessonRoute(subjectID: "biology", resource: "eukaryotic_cell_organelles")
        practiceFocusRoute = route
        DispatchQueue.main.async {
            selection = .courseLesson(.biology, "eukaryotic_cell_organelles")
        }
    }

    private func openCustom(_ subjectID: UUID) {
        practiceFocusRoute = nil
        selection = .customSubject(subjectID)
    }

    private func openCourseLesson(subject: Subject, resource: String) {
        openCourseLesson(subject: subject, resource: resource, focusPractice: false)
    }

    private func openCourseLesson(subject: Subject, resource: String, focusPractice: Bool) {
        let route = StudyLessonRoute(subjectID: subject.rawValue, resource: resource)
        if !previewLockedLessons, !StudyProgressionPolicy.previewLockedLessonsForUITest,
           let roadmap = CurriculumCatalog.studyRoadmaps().first(where: { $0.subjectID == subject.rawValue }),
           !StudyProgressionPolicy.isAvailable(route, in: roadmap, evidence: store.studyProgressionEvidence) {
            practiceFocusRoute = nil
            selection = .subject(subject)
            return
        }
        practiceFocusRoute = focusPractice ? route : nil
        store.rememberCourseLesson(subject: subject, resource: resource)
        selection = .courseLesson(subject, resource)
    }

    private func openRecommendedLesson(_ route: StudyLessonRoute, focusPractice: Bool) {
        openStudyRoute(route, focusPractice: focusPractice)
    }

    private func openDueReview(_ route: StudyLessonRoute) {
        openStudyRoute(route, focusPractice: true)
    }

    private func openStudyRoute(_ route: StudyLessonRoute, focusPractice: Bool = false) {
        if let address = CustomTopicStudyRoute.address(for: route, in: store.customCurriculum) {
            practiceFocusRoute = nil
            store.rememberStudyRoute(route)
            switch address {
            case .learnerSubject(let subjectID, let topicID):
                selection = .customTopic(subjectID, topicID)
            case .builtInSubject(let subjectID, let topicID):
                guard let subject = Subject(rawValue: subjectID) else { return }
                selection = .builtInCustomTopic(subject, topicID)
            }
            return
        }
        if route.subjectID == "intro", let subject = Subject(rawValue: route.resource) {
            practiceFocusRoute = focusPractice ? route : nil
            store.rememberStudyRoute(route)
            selection = .lesson(subject)
            return
        }
        guard let subject = Subject(rawValue: route.subjectID) else {
            practiceFocusRoute = nil
            return
        }
        openCourseLesson(subject: subject, resource: route.resource, focusPractice: focusPractice)
    }
}

private struct StudyGoalOption: Identifiable {
    let route: StudyLessonRoute
    let subjectID: String
    let subjectTitle: String
    let levelTitle: String
    let topicTitle: String
    let learningOutcome: String

    var id: String { route.lessonID }
}

private struct JourneyCopy {
    let ru: String
    let en: String

    func value(in language: AppLanguage) -> String {
        language == .ru ? ru : en
    }
}

private struct CauseAndCorseJourneySource: Identifiable {
    let id: String
    let title: JourneyCopy
    let url: String
}

private struct CauseAndCorseJourneyStep: Identifiable {
    let id: String
    let title: JourneyCopy
    let description: JourneyCopy
    let projectOutput: JourneyCopy
    let subjects: [Subject]
    let sources: [CauseAndCorseJourneySource]
}

private enum CauseAndCorseLearningJourney {
    static let steps: [CauseAndCorseJourneyStep] = [
        .init(
            id: "mathematics",
            title: .init(ru: "Математика: фундамент", en: "Mathematics: foundations"),
            description: .init(ru: "Числа, алгебра, функции, геометрия и постепенный переход к анализу.", en: "Numbers, algebra, functions, geometry, and a gradual path into calculus."),
            projectOutput: .init(ru: "Построй график функции и письменно объясни, как меняется результат при изменении входных значений.", en: "Plot a function and explain in writing how the output changes when its input changes."),
            subjects: [.mathematics],
            sources: [
                .init(id: "math.stepik", title: .init(ru: "Stepik · математика 227868", en: "Stepik · mathematics 227868"), url: "https://stepik.org/course/227868/promo"),
                .init(id: "math.calculus", title: .init(ru: "Stepik · матанализ 229762", en: "Stepik · calculus 229762"), url: "https://stepik.org/course/229762/promo")
            ]
        ),
        .init(
            id: "scientific_method",
            title: .init(ru: "Научное мышление: вопрос → проверка → вывод", en: "Scientific thinking: question → test → conclusion"),
            description: .init(ru: "Сначала сформулируй проверяемую гипотезу, измени один фактор, запиши наблюдения и ограничения вывода. В приложении — уроки «Научный вопрос и план эксперимента» в биологии и «Измерения, единицы и неопределённость» в физике.", en: "State a testable hypothesis, change one factor, record observations, and describe the limits of the conclusion. In the app, see “Scientific questions and experimental design” in Biology and “Measurement, units, and uncertainty” in Physics."),
            projectOutput: .init(ru: "Проведи три измерения одного простого явления и запиши гипотезу, данные и возможную погрешность.", en: "Take three measurements of a simple phenomenon and record the hypothesis, data, and possible measurement error."),
            subjects: [.biology, .physics],
            sources: [.init(id: "science.stepik", title: .init(ru: "Stepik · «Научное мышление» · бесплатно", en: "Stepik · Scientific Thinking · free, Russian"), url: "https://stepik.org/course/578/promo")]
        ),
        .init(
            id: "python",
            title: .init(ru: "Python: алгоритмы и практика", en: "Python: algorithms and practice"),
            description: .init(ru: "Переменные, функции, коллекции, алгоритмы, отладка и небольшие программы.", en: "Variables, functions, collections, algorithms, debugging, and small programs."),
            projectOutput: .init(ru: "Собери функцию учёта минут практики, запусти её в безопасном локальном тренажёре и получи верную сумму. Позже добавь проверку ввода после изучения условий.", en: "Build a practice-minute function, run it in the safe local trainer, and get the correct total. Add input validation later, after learning conditionals."),
            subjects: [.programming],
            sources: [.init(id: "python.stepik", title: .init(ru: "Stepik · Python 67 · обновлён 16.05.2025", en: "Stepik · Python 67 · page updated 2025-05-16"), url: "https://stepik.org/course/67/promo")]
        ),
        .init(
            id: "cs50x",
            title: .init(ru: "CS50x: основы информатики", en: "CS50x: computer science foundations"),
            description: .init(ru: "Связывай программирование с памятью, алгоритмами, структурами данных и системами; курс Harvard идёт на английском.", en: "Connect programming to memory, algorithms, data structures, and systems; Harvard’s course is in English."),
            projectOutput: .init(ru: "Собери небольшую программу поиска или сортировки, добавь тесты и объясни, почему выбрал этот алгоритм.", en: "Build a small search or sorting program, add tests, and explain why you chose that algorithm."),
            subjects: [.programming],
            sources: [.init(id: "cs50x.official", title: .init(ru: "Harvard · CS50x 2026", en: "Harvard · CS50x 2026"), url: "https://cs50.harvard.edu/x/")]
        ),
        .init(
            id: "physics",
            title: .init(ru: "Физика: проверить модель руками", en: "Physics: test models hands-on"),
            description: .init(ru: "Предскажи результат, меняй параметры в симуляции, сравнивай с графиком и отмечай ограничения модели.", en: "Predict an outcome, change simulation parameters, compare the graph, and note the model’s limits."),
            projectOutput: .init(ru: "Сравни прогноз силы трения с моделью урока, сохрани график или таблицу и назови одно ограничение модели.", en: "Compare a friction prediction with the lesson model, save a graph or table, and name one model limitation."),
            subjects: [.physics],
            sources: [
                .init(id: "physics.stepik.foundation", title: .init(ru: "Stepik · физика 7–9 класс 62700", en: "Stepik · physics grades 7–9 #62700"), url: "https://stepik.org/course/62700/promo"),
                .init(id: "physics.stepik.advanced", title: .init(ru: "Stepik · физика для студентов 287410", en: "Stepik · student physics #287410"), url: "https://stepik.org/course/287410/promo"),
                .init(id: "physics.phet", title: .init(ru: "PhET · симуляции", en: "PhET · simulations"), url: "https://phet.colorado.edu/ru/"),
                .init(id: "physics.geogebra", title: .init(ru: "GeoGebra · 3D", en: "GeoGebra · 3D"), url: "https://www.geogebra.org/3d")
            ]
        ),
        .init(
            id: "biology",
            title: .init(ru: "Биология и зоология: системы жизни", en: "Biology and zoology: living systems"),
            description: .init(ru: "Клетки, наследственность, эволюция и функции животных; в приложении урок «Что такое жизнь и как она могла возникнуть» связывает их с вопросом о происхождении и создании жизни. Старые материалы сверяй с современными источниками.", en: "Cells, heredity, evolution, and animal function; in the app, “What life is and how it might have begun” connects them to the question of how life began and could be built. Compare older course material with current sources."),
            projectOutput: .init(ru: "Сделай схему одной биологической системы и подпиши, какие источники подтверждают связи между её частями.", en: "Diagram one biological system and cite sources that support the links between its parts."),
            subjects: [.chemistry, .biology, .zoology],
            sources: [
                .init(id: "biology.stepik", title: .init(ru: "Stepik · молекулярная биология 70 · обновлён 19.12.2023", en: "Stepik · molecular biology 70 · page updated 2023-12-19"), url: "https://stepik.org/course/70/promo"),
                .init(id: "biology.zoology", title: .init(ru: "Stepik · молекулярная филогенетика 2054", en: "Stepik · molecular phylogenetics #2054"), url: "https://stepik.org/course/2054/promo")
            ]
        ),
        .init(
            id: "machine_learning",
            title: .init(ru: "Машинное обучение: алгоритмы и эксперименты", en: "Machine learning: algorithms and experiments"),
            description: .init(ru: "После Python и математики: собери baseline, проверь модель на новых данных, изучи ошибки и ограничения. В приложении — уроки «Машинное обучение: baseline и отложенная проверка» и «Градиентный спуск и шаг обучения» в программировании.", en: "After Python and mathematics: build a baseline, evaluate on held-out data, and inspect errors and limits. In the app, see “Machine learning: baselines and held-out evaluation” and “Gradient descent and the learning rate” in Programming."),
            projectOutput: .init(ru: "Обучи один простой baseline, оцени его на отложенных данных и запиши ошибки, а не только точность.", en: "Train one simple baseline, evaluate it on held-out data, and record its errors as well as its score."),
            subjects: [.programming],
            sources: [
                .init(id: "machine_learning.stepik", title: .init(ru: "Stepik · ИИ в задачах 300891", en: "Stepik · AI through problems 300891"), url: "https://stepik.org/course/300891/promo"),
                .init(id: "machine_learning.advanced", title: .init(ru: "Stepik · углублённый ML 209247", en: "Stepik · advanced ML #209247"), url: "https://stepik.org/course/209247/promo")
            ]
        ),
        .init(
            id: "brain_science",
            title: .init(ru: "Нейронаука, когнитивистика и сознание", en: "Neuroscience, cognitive science, and consciousness"),
            description: .init(ru: "Переходи к исследованиям после биологии и ML; в приложении — уроки «Нейрон и потенциал действия» и «Синапс и суммация сигналов» в биологии. Сознание и возможность создания жизни — дальние научные вопросы, не обещанный результат.", en: "Move into research after biology and ML; in the app, see “Neurons and the action potential” and “Synapses and signal summation” in Biology. Consciousness and creating life are long-term scientific questions, not promised outcomes."),
            projectOutput: .init(ru: "Подготовь карточку одного научного утверждения: источник, метод, результат и что пока неизвестно.", en: "Create an evidence card for one scientific claim: source, method, result, and what remains unknown."),
            subjects: [.biology],
            sources: [.init(id: "brain.hse", title: .init(ru: "ВШЭ · «Мозг и психика» · 13 недель, русский", en: "HSE · Brain and Psyche · 13 weeks, Russian"), url: "https://openedu.ru/course/hse/BRAPS/?session=2022")]
        ),
        .init(
            id: "own_projects",
            title: .init(ru: "Собственные проекты: создать и проверить", en: "Your own projects: build and test"),
            description: .init(ru: "Выбери реальную задачу, собери прототип, проверь его на данных и объясни источники, выводы и ограничения.", en: "Choose a real problem, build a prototype, test it with data, and explain sources, findings, and limitations."),
            projectOutput: .init(ru: "Собери небольшой работающий прототип, приложи проверку и кратко запиши следующий шаг.", en: "Build a small working prototype, include a check, and note the next step."),
            subjects: [.programming],
            sources: [.init(id: "projects.turing_way", title: .init(ru: "The Turing Way · воспроизводимые исследования · англ., CC BY 4.0", en: "The Turing Way · reproducible research · CC BY 4.0"), url: "https://book.the-turing-way.org/reproducible-research/reproducible-research")]
        )
    ]
}

private struct CauseAndCorseJourneyCard: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    let language: AppLanguage
    let open: (Subject) -> Void
    let startMathematics: () -> Void

    private var completedJourneyProjectCount: Int {
        CauseAndCorseLearningJourney.steps.filter {
            store.completedJourneyProjectIDs.contains($0.id)
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 42)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 4) {
                    Text(language == .ru ? "Cause & Corse · путь к своим технологиям" : "Cause & Corse · a path to building new technology")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("journey.title")
                    Text(language == .ru
                         ? "9 этапов по очереди: сначала математика, затем научное мышление и Python. Не нужно хвататься за все предметы сразу; английский добавляем постепенно."
                         : "Nine stages in sequence: mathematics first, then scientific thinking and Python. No need to study everything at once; add English gradually.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button(action: toggleExpansion) {
                    Label(
                        isExpanded
                            ? (language == .ru ? "Скрыть" : "Collapse")
                            : (language == .ru ? "Все этапы" : "All stages"),
                        systemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("journey.expand")
            }

            VStack(alignment: .leading, spacing: 7) {
                let progressSummary = language == .ru
                    ? "Мини-проекты по твоей отметке: \(completedJourneyProjectCount) из \(CauseAndCorseLearningJourney.steps.count) — шаги к своим технологиям."
                    : "Mini-projects marked complete: \(completedJourneyProjectCount) of \(CauseAndCorseLearningJourney.steps.count) — steps toward building your own technology."
                Text(progressSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(progressSummary))
                .accessibilityIdentifier("journey.project-progress")
                ProgressView(
                    value: Double(completedJourneyProjectCount),
                    total: Double(CauseAndCorseLearningJourney.steps.count)
                )
                .tint(Color.accentColor)
                .accessibilityLabel(
                    Text(language == .ru ? "Прогресс мини-проектов" : "Mini-project progress")
                )
            }

            Button(action: startMathematics) {
                Label(
                    language == .ru ? "Начать урок математики → затем Python" : "Start a mathematics lesson → then Python",
                    systemImage: "arrow.right.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("journey.primary-action")
            .accessibilityHint(Text(language == .ru
                ? "Открывает следующий доступный урок математики."
                : "Opens the next available mathematics lesson."))

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(CauseAndCorseLearningJourney.steps.enumerated()), id: \.element.id) { index, step in
                        if index > 0 {
                            Divider().padding(.leading, 42)
                        }
                        journeyStep(step, index: index)
                    }
                }
                .padding(.top, 2)
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(language == .ru
                         ? "Ссылки маршрута перепроверены 19.10.2026. По страницам Stepik, Python 67 обновлялся 16.05.2025, биология 70 — 19.12.2023; проверь наличие более новых материалов. PhET и GeoGebra открываются отдельно; права на встраивание не подтверждены. Твои проектные заметки сохраняются локально на этом Mac."
                         : "The route links were rechecked on 2026-10-19. Stepik's pages list Python 67 as updated 2025-05-16 and biology 70 as updated 2023-12-19; check for newer materials. PhET and GeoGebra open separately; embedding rights are unconfirmed. Your project notes are saved locally on this Mac.")
                        .accessibilityIdentifier("journey.source-notice")
                    Text(language == .ru
                         ? "Страница ВШЭ проверена 21.10.2026: курс на русском на 13 недель; открыты лекции только первых двух недель, остальные материалы платные. Проверь актуальную запись и условия доступа."
                         : "HSE page checked on 2026-10-21: a 13-week course in Russian; only the first two weeks' lectures are open, remaining material is paid. Check current enrollment and access terms.")
                        .accessibilityIdentifier("journey.hse-access-note")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .coliContentCard(tint: Color.accentColor, cornerRadius: 18)
    }

    @ViewBuilder
    private func journeyStep(_ step: CauseAndCorseJourneyStep, index: Int) -> some View {
        let projectDraftKey = journeyProjectDraftKey(for: step)
        let hasProjectResult = !(store.studyReflectionDrafts[projectDraftKey] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let isProjectComplete = store.completedJourneyProjectIDs.contains(step.id)

        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.12), in: Circle())
                .accessibilityLabel(Text("\(index + 1)"))
                .accessibilityIdentifier("journey.step.\(step.id).number")

            VStack(alignment: .leading, spacing: 7) {
                Text(step.title.value(in: language))
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("journey.step.\(step.id).title")
                Text(step.description.value(in: language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(language == .ru ? "Мини-проект · маленький проверяемый результат" : "Mini-project · a small verifiable result")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(step.projectOutput.value(in: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("journey.step.\(step.id).project-output")
                TextField(
                    language == .ru ? "Запиши результат или что уже сделал" : "Record your result or what you have done",
                    text: journeyProjectBinding(for: step),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .accessibilityIdentifier("journey.step.\(step.id).project-result")

                Button {
                    store.setJourneyProjectCompleted(!isProjectComplete, stepID: step.id)
                } label: {
                    Label(
                        isProjectComplete
                            ? (language == .ru ? "Мини-проект выполнен" : "Mini-project completed")
                            : (language == .ru ? "Отметить результат выполненным" : "Mark project result complete"),
                        systemImage: isProjectComplete ? "checkmark.circle.fill" : "circle"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!isProjectComplete && !hasProjectResult)
                .accessibilityIdentifier("journey.step.\(step.id).complete")
                .accessibilityValue(
                    Text(isProjectComplete
                        ? (language == .ru ? "Выполнен" : "Completed")
                        : (language == .ru ? "Не отмечен" : "Not completed"))
                )

                if !step.subjects.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(step.subjects, id: \.self) { subject in
                            Button { open(subject) } label: {
                                Label(subject.title(in: language), systemImage: "arrow.up.right")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityIdentifier("journey.step.\(step.id).subject.\(subject.rawValue)")
                        }
                    }
                }

                if !step.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(step.sources) { source in
                            if let url = URL(string: source.url) {
                                Link(destination: url) {
                                    Label(source.title.value(in: language), systemImage: "arrow.up.right.square")
                                        .font(.caption)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("journey.source.\(source.id)")
                                .accessibilityValue(source.url)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 7)
    }

    private func toggleExpansion() {
        if reduceMotion {
            isExpanded.toggle()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    private func journeyProjectBinding(for step: CauseAndCorseJourneyStep) -> Binding<String> {
        let key = journeyProjectDraftKey(for: step)
        return Binding(
            get: { store.studyReflectionDrafts[key] ?? "" },
            set: {
                store.saveReflectionDraft($0, lessonID: key)
                if $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    store.setJourneyProjectCompleted(false, stepID: step.id)
                }
            }
        )
    }

    private func journeyProjectDraftKey(for step: CauseAndCorseJourneyStep) -> String {
        "cause_and_corse.journey.\(step.id)"
    }
}

private struct TodayView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let open: (Subject) -> Void
    let openCustom: (UUID) -> Void
    let openCourseLesson: (StudyLessonRoute, Bool) -> Void
    let openDueReview: (StudyLessonRoute) -> Void

    @State private var builtInStudyRoadmaps = CurriculumCatalog.studyRoadmaps()
    @State private var showingGoalPicker = false
    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 16)]

    private var recommendationRoadmaps: [StudyRoadmap] {
        builtInStudyRoadmaps + CustomTopicStudyRoute.roadmaps(from: store.customCurriculum)
    }

    private var studyGoalOptions: [StudyGoalOption] {
        var options: [StudyGoalOption] = []
        for subject in Subject.allCases {
            for level in CurriculumCatalog.roadmap(for: subject) {
                for topic in level.topics {
                    guard let resource = topic.lessonResource else { continue }
                    options.append(StudyGoalOption(
                        route: StudyLessonRoute(subjectID: subject.rawValue, resource: resource),
                        subjectID: subject.rawValue,
                        subjectTitle: subject.title(in: store.language),
                        levelTitle: level.title.value(in: store.language),
                        topicTitle: topic.name.value(in: store.language),
                        learningOutcome: topic.learningOutcome.value(in: store.language)
                    ))
                }
            }
        }

        func appendCustomTopics(
            _ topics: [CustomLearningTopic],
            subjectID: String,
            subjectTitle: String,
            routeForTopic: (UUID) -> StudyLessonRoute
        ) {
            for topic in topics {
                options.append(StudyGoalOption(
                    route: routeForTopic(topic.id),
                    subjectID: subjectID,
                    subjectTitle: subjectTitle,
                    levelTitle: L10n.text("home.goal.customLevel", store.language),
                    topicTitle: topic.name.value(in: store.language.rawValue),
                    learningOutcome: topic.learningOutcome.value(in: store.language.rawValue)
                ))
                appendCustomTopics(
                    topic.subtopics,
                    subjectID: subjectID,
                    subjectTitle: subjectTitle,
                    routeForTopic: routeForTopic
                )
            }
        }

        for subject in store.customCurriculum.subjects {
            appendCustomTopics(
                subject.topics,
                subjectID: "custom-user:\(subject.id.uuidString.lowercased())",
                subjectTitle: subject.name.value(in: store.language.rawValue),
                routeForTopic: { CustomTopicStudyRoute.userTopic(subjectID: subject.id, topicID: $0) }
            )
        }
        for subject in Subject.allCases {
            let topics = store.customCurriculum.topics(builtInSubjectID: subject.rawValue)
            appendCustomTopics(
                topics,
                subjectID: "custom-builtin:\(subject.rawValue)",
                subjectTitle: subject.title(in: store.language),
                routeForTopic: { CustomTopicStudyRoute.builtInTopic(subjectID: subject.rawValue, topicID: $0) }
            )
        }
        return options
    }

    private var activeGoalOption: StudyGoalOption? {
        guard let goal = store.activeStudyGoal else { return nil }
        return studyGoalOptions.first { $0.id == goal.target.lessonID }
    }

    private var goalProgress: StudyGoalProgress? {
        guard let goal = store.activeStudyGoal else { return nil }
        return StudyGoalPlanner.progress(
            for: goal,
            in: recommendationRoadmaps,
            completedLessonIDs: store.completedLessonIDs,
            successfulKnowledgeCheckLessonIDs: store.studyProgressionEvidence.successfulKnowledgeCheckLessonIDs
        )
    }

    private var addressableRoutesByLessonID: [String: StudyLessonRoute] {
        var routes = builtInStudyRoadmaps.flatMap { roadmap in
            roadmap.lessonResources.map { StudyLessonRoute(subjectID: roadmap.subjectID, resource: $0) }
        }
        routes += CustomTopicStudyRoute.roadmaps(from: store.customCurriculum).flatMap { roadmap in
            roadmap.lessonResources.map { StudyLessonRoute(subjectID: roadmap.subjectID, resource: $0) }
        }
        routes += Subject.allCases.map { StudyLessonRoute(subjectID: "intro", resource: $0.rawValue) }
        return routes.reduce(into: [:]) { result, route in
            result[route.lessonID] = route
        }
    }

    private var addressableDueReviewRoutes: [StudyLessonRoute] {
        store.studyProgress.values
            .filter { ($0.dueDate ?? .distantFuture) <= Date() }
            .sorted {
                let leftDate = $0.dueDate ?? .distantFuture
                let rightDate = $1.dueDate ?? .distantFuture
                return leftDate == rightDate ? $0.lessonID < $1.lessonID : leftDate < rightDate
            }
            .compactMap { addressableRoutesByLessonID[$0.lessonID] }
            .filter { route in
                guard let roadmap = recommendationRoadmaps.first(where: { $0.subjectID == route.subjectID }) else {
                    return true
                }
                return StudyProgressionPolicy.isAvailable(
                    route,
                    in: roadmap,
                    evidence: store.studyProgressionEvidence
                )
            }
    }

    private var courseProgress: StudyCourseProgress {
        StudyCourseProgress(
            roadmaps: builtInStudyRoadmaps,
            completedLessonIDs: store.completedLessonIDs
        )
    }

    private var recallEvidence: [String: StudyRecallEvidence] {
        store.studyRecallEvidence
    }

    private var knowledgeEvidenceCoverage: StudyKnowledgeEvidenceCoverage {
        StudyKnowledgeEvidenceCoverage(
            roadmaps: recommendationRoadmaps,
            records: store.studyProgress.values.map { record in
                StudyAssessmentProgressRecord(
                    lessonID: record.lessonID,
                    assessmentCount: record.assessmentCount,
                    latestAssessment: record.assessment,
                    latestAssessmentAt: record.assessment == nil ? nil : record.lastReviewedAt
                )
            },
            additionalEvidence: Array(store.studyAssessmentEvidence.values)
        )
    }

    private var studyRecommendation: StudyRecommendation? {
        if let goal = store.activeStudyGoal {
            return StudyGoalPlanner.recommendation(
                for: goal,
                in: recommendationRoadmaps,
                completedLessonIDs: store.completedLessonIDs,
                resume: store.lastOpenedCourseRoute,
                recallEvidence: recallEvidence,
                assessmentEvidence: store.studyAssessmentEvidence
            )
        }
        return StudyRecommendationSelector.recommendation(
            roadmaps: recommendationRoadmaps,
            completedLessonIDs: store.completedLessonIDs,
            resume: store.lastOpenedCourseRoute,
            recallEvidence: recallEvidence,
            assessmentEvidence: store.studyAssessmentEvidence
        )
    }

    private var studyReturnSnapshot: StudyReturnSnapshot? {
        StudyReturnSnapshot.make(
            lastActivityAt: store.lastLearningActivityAt,
            now: Date(),
            lastOpenedRoute: store.lastOpenedCourseRoute,
            completedLessonCount: store.completedLessonIDs.count,
            passedKnowledgeCheckCount: store.studyProgressionEvidence.successfulKnowledgeCheckLessonIDs.count,
            nextRoute: nextDueReviewRoute ?? studyRecommendation?.route
        )
    }

    private var nextLessonRoute: StudyLessonRoute? { studyRecommendation?.route }

    private var nextDueReviewRoute: StudyLessonRoute? { addressableDueReviewRoutes.first }

    private var hasAddressableDueReview: Bool { nextDueReviewRoute != nil }

    private var nextMathematicsRoute: StudyLessonRoute? {
        guard let mathematicsRoadmap = builtInStudyRoadmaps.first(where: {
            $0.subjectID == Subject.mathematics.rawValue
        }) else { return nil }
        let resume = store.lastOpenedCourseRoute?.subjectID == mathematicsRoadmap.subjectID
            ? store.lastOpenedCourseRoute
            : nil
        return StudyRecommendationSelector.recommendation(
            roadmaps: [mathematicsRoadmap],
            completedLessonIDs: store.completedLessonIDs,
            resume: resume,
            recallEvidence: recallEvidence,
            assessmentEvidence: store.studyAssessmentEvidence
        )?.route
    }

    private var featuredStudyAccent: Color {
        studyAccent(for: nextDueReviewRoute ?? studyRecommendation?.route)
    }

    private func studyAccent(for route: StudyLessonRoute?) -> Color {
        guard let route else { return Color.accentColor }
        return ColiDevVisualSystem.studyAccentToken(subjectID: route.subjectID, resource: route.resource).color
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("home.eyebrow", store.language))
                        .font(.caption.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    Text(L10n.text("home.title", store.language))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("home.title")
                    Text(L10n.text("home.subtitle", store.language))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 28)

                progressCard
                if let studyReturnSnapshot {
                    studyReturnCard(studyReturnSnapshot)
                }
                studyGoalCard
                CauseAndCorseJourneyCard(
                    language: store.language,
                    open: open,
                    startMathematics: {
                        if let route = nextMathematicsRoute {
                            openCourseLesson(route, false)
                        } else {
                            open(.mathematics)
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("home.catalog", store.language))
                            .font(.title2.weight(.semibold))
                        Text(L10n.text("home.catalogHint", store.language))
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(Subject.allCases) { subject in
                            SubjectCard(subject: subject, complete: store.isComplete(subject)) {
                                open(subject)
                            }
                        }
                        ForEach(store.customCurriculum.subjects) { subject in
                            CustomSubjectCard(subject: subject, language: store.language) {
                                openCustom(subject.id)
                            }
                        }
                    }
                }

                Label { Text(L10n.text("home.offline", store.language)) } icon: { Image(systemName: "wifi.slash") }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingGoalPicker) {
            StudyGoalPickerView(
                options: studyGoalOptions,
                currentGoal: store.activeStudyGoal
            ) { goal in
                store.setActiveStudyGoal(goal)
            }
            .environmentObject(store)
        }
    }

    private var studyGoalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(L10n.text("home.goal.title", store.language), systemImage: "scope")
                    .font(.headline)
                Spacer()
                Button(L10n.text(
                    store.activeStudyGoal == nil ? "home.goal.choose" : "home.goal.change",
                    store.language
                )) {
                    showingGoalPicker = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("study-goal-picker-button")
            }

            if store.activeStudyGoal != nil,
               let option = activeGoalOption,
               let progress = goalProgress {
                Text(option.topicTitle)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("study-goal-selected-title")
                if !option.learningOutcome.isEmpty {
                    Text(option.learningOutcome)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(L10n.text("home.goal.pathExplanation", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ProgressView(value: progress.fractionVerified)
                        .tint(studyAccent(for: activeGoalOption?.route ?? studyRecommendation?.route))
                    Text(String(
                        format: L10n.text("home.goal.verifiedProgress", store.language),
                        progress.verifiedCount,
                        progress.totalCount
                    ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("study-goal-progress")
                }
                if let lastVerified = progress.lastVerifiedMilestone {
                    Text(L10n.text("home.goal.lastVerified", store.language)
                        .replacingOccurrences(of: "%@", with: goalStepTitle(lastVerified.route)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let lastOpened = progress.milestone(for: store.lastOpenedCourseRoute),
                   lastOpened.id != progress.lastVerifiedMilestone?.id,
                   lastOpened.id != progress.nextMilestone?.id {
                    Text(L10n.text("home.goal.lastOpened", store.language)
                        .replacingOccurrences(of: "%@", with: goalStepTitle(lastOpened.route)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let next = progress.nextMilestone {
                    Text(L10n.text("home.goal.nextStep", store.language)
                        .replacingOccurrences(of: "%@", with: goalStepTitle(next.route)))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(studyAccent(for: next.route))
                        .accessibilityIdentifier("study-goal-next-step")
                    if !hasAddressableDueReview, let recommendation = studyRecommendation {
                        Text(L10n.text("home.goal.microstart", store.language)
                            .replacingOccurrences(of: "%@", with: goalStepTitle(recommendation.route)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if progress.isComplete {
                    Text(L10n.text("home.goal.completed", store.language))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(studyAccent(for: activeGoalOption?.route))
                }

                DisclosureGroup(L10n.text("home.goal.showPath", store.language)) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(progress.milestones.enumerated()), id: \.element.id) { index, milestone in
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: milestone.isVerified
                                    ? "checkmark.circle.fill"
                                    : milestone.lessonCompleted ? "checkmark.circle" : "circle")
                                    .foregroundStyle(milestone.isVerified ? Color.green : Color.secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(index + 1). \(goalStepTitle(milestone.route))")
                                        .font(.callout)
                                    if milestone.lessonCompleted && !milestone.knowledgeCheckPassed {
                                        Text(L10n.text("home.goal.checkNeeded", store.language))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.callout)
                Text(L10n.text("home.goal.noPressure", store.language))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if store.activeStudyGoal != nil {
                Text(L10n.text("home.goal.unavailable", store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(L10n.text("home.goal.progressPreserved", store.language))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(L10n.text("home.goal.empty", store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .coliContentCard(tint: studyAccent(for: activeGoalOption?.route ?? studyRecommendation?.route), cornerRadius: 18)
    }

    private func goalStepTitle(_ route: StudyLessonRoute) -> String {
        studyGoalOptions.first { $0.id == route.lessonID }?.topicTitle
            ?? route.resource.replacingOccurrences(of: "_", with: " ")
    }

    private func studyReturnCard(_ snapshot: StudyReturnSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text("home.return.title", store.language), systemImage: "arrow.uturn.forward")
                .font(.headline)
            if let lastRoute = snapshot.lastOpenedRoute {
                Text(L10n.text("home.return.lastStop", store.language)
                    .replacingOccurrences(of: "%@", with: goalStepTitle(lastRoute)))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(String(
                format: L10n.text("home.return.completed", store.language),
                snapshot.completedLessonCount
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(String(
                format: L10n.text("home.return.checks", store.language),
                snapshot.passedKnowledgeCheckCount
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            if let nextRoute = snapshot.nextRoute {
                Text(L10n.text("home.return.next", store.language)
                    .replacingOccurrences(of: "%@", with: goalStepTitle(nextRoute)))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(studyAccent(for: nextRoute))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(L10n.text("home.return.noNext", store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.text("home.return.noDebt", store.language))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .coliContentCard(tint: studyAccent(for: snapshot.nextRoute), cornerRadius: 16)
    }

    private var progressCard: some View {
        HStack(spacing: 22) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(courseProgress.fractionCompleted))
                    .stroke(featuredStudyAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.28),
                        value: courseProgress.fractionCompleted
                    )
                Text(courseProgress.totalCount > 0
                    ? "\(courseProgress.completedCount)/\(courseProgress.totalCount)"
                    : "—")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("home.progress", store.language))
                    .font(.caption.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("home.progress-title")
                if courseProgress.totalCount > 0 {
                    Text(String(
                        format: L10n.text("home.lessonCompletion", store.language),
                        courseProgress.completedCount,
                        courseProgress.totalCount
                    ))
                        .font(.headline)
                } else {
                    Text(L10n.text("home.roadmapUnavailable", store.language))
                        .font(.headline)
                }
                if knowledgeEvidenceCoverage.totalTopicCount > 0 {
                    Text(String(
                        format: L10n.text("home.knowledgeChecks", store.language),
                        knowledgeEvidenceCoverage.topicsWithChecks,
                        knowledgeEvidenceCoverage.totalTopicCount
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(
                        format: L10n.text("home.knowledgeEvidenceVariety", store.language),
                        knowledgeEvidenceCoverage.topicsWithMultipleTaskTypes,
                        knowledgeEvidenceCoverage.totalTopicCount
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if knowledgeEvidenceCoverage.topicsNeedingPractice > 0 {
                        Text(String(
                            format: L10n.text("home.knowledgeNeedPractice", store.language),
                            knowledgeEvidenceCoverage.topicsNeedingPractice
                        ))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(featuredStudyAccent)
                    }
                    let reportedDifficulties = StudyErrorCategory.allCases.filter {
                        (knowledgeEvidenceCoverage.reportedErrorTopicCounts[$0] ?? 0) > 0
                    }
                    if !reportedDifficulties.isEmpty {
                        Text(L10n.text("home.reportedDifficulties", store.language))
                            .font(.caption.weight(.medium))
                        ForEach(reportedDifficulties) { category in
                            Text("\(L10n.text(category.titleKey, store.language)) · \(knowledgeEvidenceCoverage.reportedErrorTopicCounts[category] ?? 0)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(L10n.text("home.reportedDifficultiesCaveat", store.language))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(L10n.text("home.knowledgeChecksUnavailable", store.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(L10n.text("home.knowledgeEvidenceLimit", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !hasAddressableDueReview, studyRecommendation?.reason == .prerequisiteCheck {
                    Text(L10n.text("home.prerequisiteCheck", store.language))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(featuredStudyAccent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !hasAddressableDueReview, studyRecommendation?.reason == .practiceReview {
                    Text(L10n.text("home.quizNeedsPractice", store.language))
                        .font(.caption)
                        .foregroundStyle(featuredStudyAccent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !hasAddressableDueReview,
                   studyRecommendation?.reason == .reportedFoundationPrerequisite {
                    Text(L10n.text("home.reportedFoundationPrerequisite", store.language))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(featuredStudyAccent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !hasAddressableDueReview,
                   case let .reportedDifficulty(category)? = studyRecommendation?.reason {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("home.reportedDifficultyRecommendation", store.language)
                            .replacingOccurrences(of: "%@", with: L10n.text(category.titleKey, store.language)))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(featuredStudyAccent)
                        Text(L10n.text(category.guidanceKey, store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                if !hasAddressableDueReview, studyRecommendation?.reason == .recallReview {
                    Text(L10n.text("home.recallNeedsPractice", store.language))
                        .font(.caption)
                        .foregroundStyle(featuredStudyAccent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !addressableDueReviewRoutes.isEmpty {
                    Text(L10n.text("home.dueReviews", store.language)
                        .replacingOccurrences(of: "%@", with: "\(addressableDueReviewRoutes.count)"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(featuredStudyAccent)
                }
            }
            Spacer(minLength: 0)
            Button {
                if let nextDueReviewRoute {
                    openDueReview(nextDueReviewRoute)
                } else if let recommendation = studyRecommendation {
                    openCourseLesson(
                        recommendation.route,
                        recommendation.reason.opensInteractivePractice
                    )
                } else if store.activeStudyGoal != nil {
                    showingGoalPicker = true
                } else {
                    let next = Subject.allCases.first(where: { !store.isComplete($0) }) ?? .mathematics
                    open(next)
                }
            } label: {
                let actionTitle = hasAddressableDueReview
                    ? "home.reviewNow"
                    : store.activeStudyGoal == nil
                        ? "home.continue"
                        : goalProgress?.isComplete == true || goalProgress == nil
                            ? "home.goal.chooseNext"
                            : "home.goal.startSmall"
                Label {
                    Text(L10n.text(actionTitle, store.language))
                } icon: {
                    Image(systemName: hasAddressableDueReview ? "arrow.counterclockwise" : "arrow.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("home.primary-action")
        }
        .padding(20)
        .coliContentCard(tint: featuredStudyAccent, cornerRadius: 20)
    }
}

private struct StudyGoalPickerView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    let options: [StudyGoalOption]
    let currentGoal: StudyGoal?
    let onSelect: (StudyGoal?) -> Void

    private var filteredOptions: [StudyGoalOption] {
        guard !searchText.isEmpty else { return options }
        return options.filter {
            $0.topicTitle.localizedCaseInsensitiveContains(searchText)
                || $0.subjectTitle.localizedCaseInsensitiveContains(searchText)
                || $0.learningOutcome.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedSubjectIDs: [String] {
        Array(Set(filteredOptions.map(\.subjectID))).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedSubjectIDs, id: \.self) { subjectID in
                    let group = filteredOptions.filter { $0.subjectID == subjectID }
                    Section(header: Text(group.first?.subjectTitle ?? subjectID)) {
                        ForEach(group) { option in
                            Button {
                                onSelect(StudyGoal(target: option.route))
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: option.id == currentGoal?.target.lessonID
                                        ? "scope"
                                        : "circle")
                                        .foregroundStyle(option.id == currentGoal?.target.lessonID
                                            ? Color.accentColor
                                            : Color.secondary)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(option.topicTitle)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(option.levelTitle)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                        if !option.learningOutcome.isEmpty {
                                            Text(option.learningOutcome)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    Spacer(minLength: 8)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("study-goal-option.\(option.id)")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: Text(L10n.text("home.goal.search", store.language)))
            .navigationTitle(L10n.text("home.goal.pickerTitle", store.language))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("home.goal.cancel", store.language)) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if currentGoal != nil {
                    Button(L10n.text("home.goal.remove", store.language)) {
                        onSelect(nil)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 480)
    }
}

private struct SubjectCatalogView: View {
    @EnvironmentObject private var store: LearningStore
    let open: (Subject) -> Void
    let openCustom: (UUID) -> Void
    @State private var showingSubjectEditor = false
    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text(L10n.text("nav.subjects", store.language)).font(.title2.weight(.semibold))
                    Spacer()
                    Button { showingSubjectEditor = true } label: {
                        Label(L10n.text("custom.addSubject", store.language), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(Subject.allCases) { subject in
                        SubjectCard(subject: subject, complete: store.isComplete(subject)) { open(subject) }
                    }
                }
                if !store.customCurriculum.subjects.isEmpty {
                    Text(L10n.text("custom.subjectsCount", store.language)).font(.title3.weight(.semibold))
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(store.customCurriculum.subjects) { subject in
                            CustomSubjectCard(subject: subject, language: store.language) { openCustom(subject.id) }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(Text(L10n.text("nav.subjects", store.language)))
        .sheet(isPresented: $showingSubjectEditor) {
            CustomSubjectEditor { openCustom($0) }
                .environmentObject(store)
        }
    }
}

private struct SubjectCard: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    let subject: Subject
    let complete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: subject.symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(subject.tint)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [subject.tint.opacity(0.30), subject.tint.opacity(0.13)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 13)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 13)
                                .strokeBorder(subject.tint.opacity(0.24), lineWidth: 1)
                        }
                    Spacer()
                    if complete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.title(in: store.language))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subject.subtitle(in: store.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text(complete ? L10n.text("home.introDone", store.language) : L10n.text("home.foundation", store.language))
                    Image(systemName: "arrow.right")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(subject.tint)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        subject.tint.opacity(isHovered && !reduceMotion ? 0.22 : 0.15),
                        subject.tint.opacity(0.035),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(subject.tint.opacity(isHovered ? 0.34 : 0.20), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .scaleEffect(isHovered && !reduceMotion ? 1.012 : 1)
            .offset(y: isHovered && !reduceMotion ? -2 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHovered)
            .coliGlassControl(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.subject.\(subject.rawValue)")
        .onHover { isHovered = $0 }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var backendSupervisor: LocalBackendSupervisor
    @AppStorage(ColiDevVisualSystem.soundPreferenceKey) private var soundEffectsEnabled = false
    @AppStorage(StudyProgressionPolicy.previewLockedLessonsDefaultsKey) private var previewLockedLessons = false
    @State private var showingStudyFormatClearConfirmation = false
    @State private var isEffectiveAIRoutesExpanded = false
    @State private var isLoadingEffectiveAIRoutes = false
    @State private var hasLoadedEffectiveAIRoutes = false

    var body: some View {
        Form {
            Section {
                Picker(selection: $store.language, label: Text(L10n.text("settings.languages", store.language))) {
                    Text("Русский").tag(AppLanguage.ru)
                    Text("English").tag(AppLanguage.en)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle(isOn: $soundEffectsEnabled) {
                    Text(L10n.text("settings.soundEffects", store.language))
                }
                Text(L10n.text("settings.soundEffectsHelp", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L10n.text("settings.feedback", store.language))
            }
            Section {
                Toggle(isOn: $previewLockedLessons) {
                    Text(L10n.text("settings.previewLocked", store.language))
                }
                .accessibilityIdentifier("settings.previewLocked")
                Text(L10n.text("settings.previewLockedHelp", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text(L10n.text("settings.learningPath", store.language))
            }
            Section {
                let profile = store.studyFormatPreferenceProfile
                if let preference = profile.mostFrequentlyHelpful {
                    Label {
                        Text(String(
                            format: L10n.text("settings.studyFormat.confirmed", store.language),
                            L10n.text(preference.titleKey, store.language)
                        ))
                    } icon: {
                        Image(systemName: preference.symbol)
                    }
                } else {
                    Text(L10n.text("settings.studyFormat.pending", store.language))
                }
                ForEach(Subject.allCases) { subject in
                    if let preference = profile.mostFrequentlyHelpful(forSubjectID: subject.rawValue) {
                        Label {
                            Text(String(
                                format: L10n.text("settings.studyFormat.subjectConfirmed", store.language),
                                subject.title(in: store.language),
                                L10n.text(preference.titleKey, store.language)
                            ))
                        } icon: {
                            Image(systemName: preference.symbol)
                        }
                    }
                }
                Text(L10n.text("settings.studyFormat.scopeHelp", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.text("settings.studyFormat.privacy", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !store.studyFormatPreferenceProfile.responses.isEmpty {
                    Button(role: .destructive) {
                        showingStudyFormatClearConfirmation = true
                    } label: {
                        Text(L10n.text("settings.studyFormat.clear", store.language))
                    }
                }
            } header: {
                Text(L10n.text("settings.studyFormat.title", store.language))
            }
            Section {
                Picker(selection: $store.aiMode, label: Text(L10n.text("settings.aiRoute", store.language))) {
                    Text(L10n.text("settings.aiAuto", store.language)).tag(AIRoutingMode.automatic)
                    Text(L10n.text("settings.aiLocal", store.language)).tag(AIRoutingMode.localOnly)
                }
                .pickerStyle(.segmented)
                TutorRouteProbeCard()
                effectiveAIRoutePreview
                LabeledContent {
                    Text(LearningStore.orchestratorBaseURL).font(.callout.monospaced())
                } label: {
                    Text(L10n.text("settings.aiAddress", store.language))
                }
                HStack {
                    if store.isCheckingAI && store.aiHealth == nil {
                        ProgressView().controlSize(.small)
                        Text(L10n.text("settings.aiChecking", store.language)).foregroundStyle(.secondary)
                    } else if let health = store.aiHealth {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(L10n.text("settings.aiBackendResponding", store.language), systemImage: "server.rack")
                                .foregroundStyle(.secondary)
                            Text(L10n.text("settings.aiBackendOnlyStatus", store.language))
                                .font(.caption).foregroundStyle(.secondary)
                            if health.providerKind == "orchestrator",
                               health.routeResolution == "per_request" {
                                Text(String(
                                    format: L10n.text("settings.aiOrchestratorStatus", store.language),
                                    health.orchestrator ?? health.provider
                                ))
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: true, vertical: false)
                                .accessibilityIdentifier("settings.ai.orchestrator-status")
                                Text(L10n.text("settings.aiRouteResolution", store.language))
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("settings.ai.route-resolution")
                                if let allowPaidRoutes = health.allowPaidRoutes {
                                    Label(
                                        L10n.text(
                                            allowPaidRoutes
                                                ? "settings.aiPaidRoutesAllowed"
                                                : "settings.aiPaidRoutesBlocked",
                                            store.language
                                        ),
                                        systemImage: allowPaidRoutes
                                            ? "exclamationmark.triangle.fill"
                                            : "lock.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(allowPaidRoutes ? Color.orange : Color.secondary)
                                    .accessibilityIdentifier("settings.ai.paid-routes")
                                }
                            }
                            Text(routeDescription(for: health))
                                .font(.caption).foregroundStyle(.secondary)
                            if health.openRouterKeyConfigured == true {
                                Text(String(
                                    format: L10n.text("settings.aiOpenRouterReady", store.language),
                                    health.openRouterModel ?? "openrouter/free"
                                ))
                                .font(.caption2).foregroundStyle(.secondary)
                            }
                            if !health.isOllamaEndpointLocal {
                                Label(L10n.text("settings.aiOllamaRemote", store.language), systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            if !health.isObsidianEndpointLocal {
                                Label(L10n.text("settings.aiObsidianRemote", store.language), systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            if let documentCount = health.knowledgeDocumentCount {
                                Text(L10n.text("settings.aiKnowledgeCount", store.language) + "\(documentCount)")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let checkedAt = health.displayKnowledgeIndexCheckedAt {
                                    Text(L10n.text("settings.aiKnowledgeChecked", store.language) + checkedAt)
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                                if let dueCount = health.knowledgeReviewDueDocumentCount, dueCount > 0 {
                                    Text(String(
                                        format: L10n.text("settings.aiReviewDue", store.language),
                                        dueCount
                                    ))
                                    .font(.caption2).foregroundStyle(.orange)
                                    Text(L10n.text("settings.aiReviewCaveat", store.language))
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                                if let unscheduledCount = health.knowledgeReviewScheduleMissingDocumentCount,
                                   unscheduledCount > 0 {
                                    Text(String(
                                        format: L10n.text("settings.aiReviewUnscheduled", store.language),
                                        unscheduledCount
                                    ))
                                    .font(.caption2).foregroundStyle(.tertiary)
                                }
                            } else {
                                Text(L10n.text("settings.aiKnowledgeUnknown", store.language))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            if let embeddingModel = health.ollamaEmbeddingModel {
                                Text(String(format: L10n.text("settings.aiSemanticConfigured", store.language), embeddingModel))
                                    .font(.caption2).foregroundStyle(.secondary)
                            } else {
                                Text(L10n.text("settings.aiSemanticKeyword", store.language))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        Label(L10n.text("settings.aiOffline", store.language), systemImage: "wifi.slash")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("settings.aiRefresh", store.language)) {
                        Task {
                            guard await backendSupervisor.ensureRunning() else { return }
                            await store.refreshAIStatus()
                            await store.refreshProviderSecretStatuses()
                            if isEffectiveAIRoutesExpanded {
                                await refreshEffectiveAIRoutes()
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("settings.aiLaunch", store.language)).font(.caption.weight(.semibold))
                    Text(L10n.text(backendSupervisor.status.localizationKey, store.language))
                        .font(.callout)
                    Text(L10n.text("settings.aiPrivacy", store.language)).font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text(L10n.text("settings.aiTitle", store.language))
            }
            Section {
                Label { Text(L10n.text("settings.localBody", store.language)) } icon: { Image(systemName: "internaldrive") }
                    .foregroundStyle(.secondary)
            } header: {
                Text(L10n.text("settings.local", store.language))
            }
            Section {
                LabeledContent { Text(L10n.text("settings.preview", store.language)) } label: { Text(L10n.text("settings.version", store.language)) }
            }
            UpdatesSettingsSection(language: store.language)
        }
        .confirmationDialog(
            L10n.text("settings.studyFormat.clearTitle", store.language),
            isPresented: $showingStudyFormatClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("settings.studyFormat.clear", store.language), role: .destructive) {
                store.clearStudyFormatPreferenceProfile()
            }
            Button(L10n.text("common.cancel", store.language), role: .cancel) { }
        } message: {
            Text(L10n.text("settings.studyFormat.clearMessage", store.language))
        }
        .task {
            guard await backendSupervisor.ensureRunning() else { return }
            await store.refreshAIStatus()
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(maxWidth: 720, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(Text(L10n.text("settings.title", store.language)))
    }

    private var effectiveAIRoutePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                isEffectiveAIRoutesExpanded.toggle()
                if isEffectiveAIRoutesExpanded && !hasLoadedEffectiveAIRoutes {
                    Task { await refreshEffectiveAIRoutes() }
                }
            } label: {
                HStack {
                    Text(L10n.text("settings.ai.routePreview.title", store.language))
                        .font(.callout.weight(.medium))
                    Spacer()
                    Image(systemName: isEffectiveAIRoutesExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.ai.route-preview.toggle")

            if isEffectiveAIRoutesExpanded {
                Text(L10n.text("settings.ai.routePreview.disclaimer", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isLoadingEffectiveAIRoutes {
                    ProgressView(L10n.text("settings.ai.routePreview.loading", store.language))
                        .controlSize(.small)
                } else {
                    if !store.autoAgentModelRoutes.isEmpty {
                        routeGroupTitle("settings.ai.routePreview.agents", symbol: "person.3")
                        ForEach(["local_draft", "gemini_draft", "critic", "verifier"], id: \.self) { role in
                            if let route = store.autoAgentModelRoutes[role] {
                                EffectiveAIRouteRow(
                                    identifier: "settings.ai.route-preview.role.\(role)",
                                    title: L10n.text("management.autoAgentRole.\(role)", store.language),
                                    configuredProvider: route.provider,
                                    effectiveProvider: route.effectiveProvider,
                                    model: route.effectiveModel,
                                    status: route.status,
                                    language: store.language
                                )
                            }
                        }
                    }

                    if let route = store.finalSynthesisModelRoute {
                        routeGroupTitle("settings.ai.routePreview.finalGroup", symbol: "sparkles")
                        EffectiveAIRouteRow(
                            identifier: "settings.ai.route-preview.final",
                            title: L10n.text("settings.ai.routePreview.finalTitle", store.language),
                            configuredProvider: route.provider,
                            effectiveProvider: route.effectiveProvider,
                            model: route.effectiveModel,
                            status: route.status,
                            language: store.language
                        )
                    }

                    if !store.subjectModelRoutes.isEmpty {
                        routeGroupTitle("settings.ai.routePreview.subjects", symbol: "books.vertical")
                        ForEach(Subject.allCases) { subject in
                            if let route = store.subjectModelRoutes[subject.rawValue] {
                                EffectiveAIRouteRow(
                                    identifier: "settings.ai.route-preview.subject.\(subject.rawValue)",
                                    title: subject.title(in: store.language),
                                    configuredProvider: route.provider,
                                    effectiveProvider: route.effectiveProvider,
                                    model: route.effectiveModel,
                                    status: route.status,
                                    language: store.language
                                )
                            }
                        }
                    }

                    if store.autoAgentModelRoutes.isEmpty,
                       store.finalSynthesisModelRoute == nil,
                       store.subjectModelRoutes.isEmpty {
                        Text(L10n.text("settings.ai.routePreview.unavailable", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await refreshEffectiveAIRoutes() }
                    } label: {
                        Label(
                            L10n.text("settings.ai.routePreview.refresh", store.language),
                            systemImage: "arrow.clockwise"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingEffectiveAIRoutes)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func routeGroupTitle(_ key: String, symbol: String) -> some View {
        Label(L10n.text(key, store.language), systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 5)
    }

    @MainActor
    private func refreshEffectiveAIRoutes() async {
        guard !isLoadingEffectiveAIRoutes else { return }
        isLoadingEffectiveAIRoutes = true
        defer { isLoadingEffectiveAIRoutes = false }
        guard await backendSupervisor.ensureRunning() else { return }
        await store.refreshAutoAgentModelRoutes()
        await store.refreshFinalSynthesisModelRoute()
        await store.refreshSubjectModelRoutes()
        hasLoadedEffectiveAIRoutes = true
    }

    private func routeDescription(for health: OrchestratorHealth) -> String {
        if store.aiMode == .localOnly {
            return L10n.text(health.hasLocalModel ? "settings.aiLocalRoute" : "settings.aiNoLocal", store.language)
        }
        if health.hasCloudRoute { return L10n.text("settings.aiOnlineRoute", store.language) }
        if health.hasLocalModel { return L10n.text("settings.aiLocalRoute", store.language) }
        return L10n.text("settings.aiNoRoute", store.language)
    }

}

private struct EffectiveAIRouteRow: View {
    let identifier: String
    let title: String
    let configuredProvider: String
    let effectiveProvider: String
    let model: String?
    let status: String
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.medium))
            Text("\(providerName(configuredProvider)) → \(providerName(effectiveProvider))")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            if let model, !model.isEmpty {
                Text(model)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            Text(L10n.text("management.routeStatus.\(status)", language))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func providerName(_ provider: String) -> String {
        let key = "management.routeProvider.\(provider)"
        let localized = L10n.text(key, language)
        return localized == key ? provider : localized
    }
}

private struct TutorRouteProbeCard: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var backendSupervisor: LocalBackendSupervisor
    @StateObject private var probe = TutorRouteProbeModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("settings.tutorProbe.title", store.language))
                .font(.headline)
            Text(L10n.text("settings.tutorProbe.warning", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: startProbe) {
                if probe.isChecking {
                    Label(L10n.text("settings.tutorProbe.checking", store.language), systemImage: "hourglass")
                } else {
                    Label(L10n.text("settings.tutorProbe.button", store.language), systemImage: "paperplane")
                }
            }
            .disabled(probe.isChecking)

            switch probe.state {
            case .idle:
                Label(L10n.text("settings.tutorProbe.unverified", store.language), systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            case .checking:
                Label(L10n.text("settings.tutorProbe.checking", store.language), systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            case .succeeded(let provider, let model, let answer, let durationMS):
                Label(L10n.text("settings.tutorProbe.success", store.language), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text([provider, model].filter { !$0.isEmpty }.joined(separator: " · ") + " · \(durationMS) ms")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(answer)
                    .font(.callout)
                    .textSelection(.enabled)
            case .failed(let message):
                Label(L10n.text("settings.tutorProbe.failedTitle", store.language), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 6)
        .onChange(of: store.aiMode) { _ in probe.reset() }
        .onChange(of: store.language) { _ in probe.reset() }
    }

    private func startProbe() {
        guard !probe.isChecking else { return }
        let selectedLanguage = store.language
        let selectedMode = store.aiMode
        probe.begin()

        Task {
            guard await backendSupervisor.ensureRunning() else {
                probe.fail(L10n.text("settings.tutorProbe.backendUnavailable", selectedLanguage))
                return
            }
            await store.refreshAIStatus()
            guard selectedLanguage == store.language, selectedMode == store.aiMode else {
                probe.reset()
                return
            }
            guard let health = store.aiHealth else {
                probe.fail(L10n.text("settings.tutorProbe.genericError", selectedLanguage))
                return
            }
            let routeReady = selectedMode == .localOnly ? health.hasLocalModel : health.hasAutomaticRoute
            guard routeReady else {
                probe.fail(L10n.text("settings.tutorProbe.noRoute", selectedLanguage))
                return
            }

            await probe.check(language: selectedLanguage, mode: selectedMode)
            if selectedLanguage != store.language || selectedMode != store.aiMode {
                probe.reset()
            }
        }
    }
}

private struct ProviderKeyEntryView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var backendSupervisor: LocalBackendSupervisor
    let provider: String
    let title: String

    @State private var apiKey = ""
    @State private var isSaving = false
    @State private var feedback: String?
    @State private var feedbackIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            HStack(spacing: 8) {
                SecureField(L10n.text("settings.keyPlaceholder", store.language), text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isSaving || !backendSupervisor.isReady)
                Button {
                    Task { await saveKey() }
                } label: {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(L10n.text("settings.keySave", store.language))
                    }
                }
                .disabled(
                    isSaving
                    || !backendSupervisor.isReady
                    || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            HStack {
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if store.providerSecretStatuses[provider]?.source == "keychain" {
                    Button(L10n.text("settings.keyRemove", store.language), role: .destructive) {
                        Task { await removeKey() }
                    }
                    .disabled(isSaving || !backendSupervisor.isReady)
                }
            }
            if let feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(feedbackIsError ? Color.red : Color.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusLabel: String {
        let key: String
        switch store.providerSecretStatuses[provider]?.source {
        case "keychain": key = "settings.keyStatusKeychain"
        case "environment": key = "settings.keyStatusEnvironment"
        case "missing": key = "settings.keyStatusMissing"
        case "unavailable", .none: key = "settings.keyStatusUnavailable"
        default: key = "settings.keyStatusUnavailable"
        }
        return L10n.text(key, store.language)
    }

    @MainActor
    private func saveKey() async {
        guard await backendSupervisor.ensureRunning() else {
            feedback = L10n.text("settings.backendFailed", store.language)
            feedbackIsError = true
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.saveProviderSecret(apiKey, for: provider)
            apiKey = ""
            feedback = L10n.text("settings.keySaved", store.language)
            feedbackIsError = false
        } catch {
            feedback = L10n.text("settings.keyFailed", store.language)
            feedbackIsError = true
        }
    }

    @MainActor
    private func removeKey() async {
        guard await backendSupervisor.ensureRunning() else {
            feedback = L10n.text("settings.backendFailed", store.language)
            feedbackIsError = true
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.deleteProviderSecret(for: provider)
            feedback = L10n.text("settings.keyRemoved", store.language)
            feedbackIsError = false
        } catch {
            feedback = L10n.text("settings.keyFailed", store.language)
            feedbackIsError = true
        }
    }
}

private enum ManagementPane: String, CaseIterable, Identifiable {
    case overview
    case courses
    case models
    case rag
    case sources
    case integrations

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .overview: return "management.overview"
        case .courses: return "management.courses"
        case .models: return "management.models"
        case .rag: return "management.rag"
        case .sources: return "management.sources"
        case .integrations: return "management.integrations"
        }
    }
}

private enum SourceRegistryFilter: String, CaseIterable, Identifiable {
    case all
    case attention
    case changed
    case review

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .all: return "management.sourceFilterAll"
        case .attention: return "management.sourceFilterAttention"
        case .changed: return "management.sourceFilterChanged"
        case .review: return "management.sourceFilterReview"
        }
    }
}

private struct ManagementView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var backendSupervisor: LocalBackendSupervisor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pane: ManagementPane = .overview
    @State private var hoveredPane: ManagementPane?
    @State private var sourceInventory: TrustedSourceInventory?
    @State private var courseCoverage: [SubjectCurriculumCoverage] = []
    @State private var courseCoverageLoadTask: Task<[SubjectCurriculumCoverage], Never>?
    @State private var isLoadingCourseCoverage = false
    @State private var hasLoadedCourseCoverage = false
    @State private var sourceSearchText = ""
    @State private var sourceFilter = SourceRegistryFilter.all
    @State private var sourcePage = 0
    @State private var ragQuery = ""
    @State private var ragSearchResult: KnowledgeRAGSearchResult?
    @State private var includeObsidianRAG = false
    @State private var isSearchingRAG = false
    @State private var ollamaEmbeddingModelSettings: OllamaEmbeddingModelSettings?
    @State private var ollamaEmbeddingModelDraft = ""
    @State private var isLoadingOllamaEmbeddingSettings = false
    @State private var isSavingOllamaEmbeddingSettings = false
    @State private var hasLoadedOllamaEmbeddingSettings = false
    @State private var isLoading = false
    @State private var isRefreshingIndex = false
    @State private var isCheckingSources = false
    @State private var routeSubject: Subject = .mathematics
    @State private var routeProvider = "auto"
    @State private var routeModel = ""
    @State private var autoAgentRole = "local_draft"
    @State private var autoAgentProvider = "auto"
    @State private var autoAgentModel = ""
    @State private var finalSynthesisProvider = "auto"
    @State private var finalSynthesisModel = ""
    @State private var compatibleBaseURL = ""
    @State private var compatibleModel = ""
    @State private var isSavingCompatibleSettings = false
    @State private var allowsPaidAutoRoutes = false
    @State private var dailyCloudCallLimit = 25
    @State private var isSavingRoute = false
    @State private var isSavingCostPolicy = false
    @State private var isPreparingBackup = false
    @State private var isRestoringBackup = false
    @State private var isExportingBackup = false
    @State private var isExportingDiagnostics = false
    @State private var isImportingBackup = false
    @State private var showingRestoreConfirmation = false
    @State private var progressBackupDocument: LearningProgressBackupFile?
    @State private var diagnosticsDocument: LearningProgressBackupFile?
    @State private var pendingBackupData: Data?
    @State private var statusMessage: String?
    @State private var statusIsError = false

    let openSettings: () -> Void

    init(openSettings: @escaping () -> Void, initialPane: ManagementPane = .overview) {
        self.openSettings = openSettings
        _pane = State(initialValue: initialPane)
    }

    private let metricColumns = [GridItem(.adaptive(minimum: 190), spacing: 12)]
    private let sourcePageSize = 10

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.text("management.title", store.language))
                            .font(.largeTitle.weight(.bold))
                        Text(L10n.text("management.subtitle", store.language))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button {
                        Task { await reload() }
                    } label: {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                    .help(L10n.text("management.reload", store.language))
                    .accessibilityLabel(L10n.text("management.reload", store.language))
                }

                HStack(spacing: 3) {
                    Text(L10n.text("management.title", store.language))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 8)

                    ForEach(ManagementPane.allCases) { section in
                        Button {
                            pane = section
                        } label: {
                            Text(L10n.text(section.titleKey, store.language))
                                .font(.system(size: 12, weight: pane == section ? .semibold : .regular))
                                .foregroundStyle(pane == section ? Color.primary : Color.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 24)
                                .background {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(
                                            pane == section
                                                ? Color.primary.opacity(0.12)
                                                : hoveredPane == section
                                                    ? Color.primary.opacity(0.06)
                                                    : Color.clear
                                        )
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.text(section.titleKey, store.language))
                        .accessibilityIdentifier("control-center.pane.\(section.id)")
                        .accessibilityAddTraits(pane == section ? .isSelected : [])
                        .onHover { isHovering in
                            if isHovering {
                                hoveredPane = section
                            } else if hoveredPane == section {
                                hoveredPane = nil
                            }
                        }
                    }
                }
                .padding(5)
                .frame(maxWidth: 900)
                .coliGlassControl(cornerRadius: 16)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: ColiDevVisualSystem.routineTransitionDuration),
                    value: pane
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("control-center.pane-picker")

                if let statusMessage {
                    Label(statusMessage, systemImage: statusIsError ? "exclamationmark.triangle" : "checkmark.circle")
                        .font(.callout)
                        .foregroundStyle(statusIsError ? Color.orange : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("control-center.status-message")
                }

                Group {
                    switch pane {
                    case .overview:
                        overviewPane
                    case .courses:
                        coursesPane
                    case .models:
                        modelsPane
                    case .rag:
                        ragPane
                    case .sources:
                        sourcesPane
                    case .integrations:
                        integrationsPane
                    }
                }
                .id(pane)
                .transition(.opacity)
                .frame(maxWidth: .infinity, minHeight: 260, maxHeight: .infinity, alignment: .topLeading)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: ColiDevVisualSystem.routineTransitionDuration),
                    value: pane
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("control-center.root")
            .padding(28)
            .frame(maxWidth: 1120, maxHeight: .infinity, alignment: .topLeading)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .navigationTitle(Text(L10n.text("management.title", store.language)))
        .onChange(of: routeSubject) { _ in syncSubjectModelRouteForm() }
        .onChange(of: sourceSearchText) { _ in sourcePage = 0 }
        .onChange(of: sourceFilter) { _ in sourcePage = 0 }
        .onChange(of: sourceInventory?.sources.count) { _ in sourcePage = 0 }
        .onChange(of: autoAgentRole) { _ in syncAutoAgentModelForm() }
        .onChange(of: autoAgentProvider) { provider in
            if provider == "auto" { autoAgentModel = "" }
        }
        .onChange(of: finalSynthesisProvider) { provider in
            if provider == "auto" { finalSynthesisModel = "" }
        }
        .onChange(of: routeProvider) { provider in
            if provider == "auto" { routeModel = "" }
        }
        .task { await reload() }
        .task { _ = await loadCourseCoverageIfNeeded() }
        .task(id: pane) {
            if pane == .rag {
                await loadOllamaEmbeddingSettingsIfNeeded()
            }
            guard pane == .sources else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                guard !Task.isCancelled else { break }
                if let latestInventory = try? await OrchestratorClient.trustedSourceInventory() {
                    sourceInventory = latestInventory
                }
            }
        }
        .fileExporter(
            isPresented: $isExportingBackup,
            document: progressBackupDocument,
            contentType: .json,
            defaultFilename: "ColiDev-Learning-Progress"
        ) { result in
            switch result {
            case .success(let url):
                statusMessage = String(
                    format: L10n.text("management.backupExported", store.language),
                    url.lastPathComponent
                )
                statusIsError = false
            case .failure(let error):
                if (error as? CocoaError)?.code == .userCancelled {
                    statusMessage = nil
                } else {
                    reportError("management.backupFailed")
                }
            }
        }
        .fileExporter(
            isPresented: $isExportingDiagnostics,
            document: diagnosticsDocument,
            contentType: .json,
            defaultFilename: "ColiDev-Diagnostics"
        ) { result in
            switch result {
            case .success(let url):
                statusMessage = String(
                    format: L10n.text("management.diagnosticsExported", store.language),
                    url.lastPathComponent
                )
                statusIsError = false
            case .failure(let error):
                if (error as? CocoaError)?.code == .userCancelled {
                    statusMessage = nil
                } else {
                    reportError("management.diagnosticsFailed")
                }
            }
        }
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                do {
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }
                    let data = try handle.read(upToCount: 1_048_577) ?? Data()
                    guard data.count <= 1_048_576 else {
                        reportError("management.backupTooLarge")
                        return
                    }
                    pendingBackupData = data
                    showingRestoreConfirmation = true
                } catch {
                    reportError("management.backupFailed")
                }
            case .failure(let error):
                if (error as? CocoaError)?.code == .userCancelled {
                    statusMessage = nil
                } else {
                    reportError("management.backupFailed")
                }
            }
        }
        .confirmationDialog(
            L10n.text("management.backupConfirmTitle", store.language),
            isPresented: $showingRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("management.backupConfirmAction", store.language), role: .destructive) {
                Task { await restoreProgressBackup() }
            }
            Button(L10n.text("management.backupCancel", store.language), role: .cancel) {
                pendingBackupData = nil
            }
        } message: {
            Text(L10n.text("management.backupConfirmMessage", store.language))
        }
    }

    private var overviewPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                    metric(
                        title: L10n.text("management.backend", store.language),
                        value: backendSupervisor.isReady
                            ? L10n.text("management.backendReady", store.language)
                            : L10n.text("management.backendUnavailable", store.language),
                        symbol: backendSupervisor.isReady ? "checkmark.circle.fill" : "exclamationmark.circle",
                        tint: backendSupervisor.isReady ? .green : .orange
                    )
                    metric(
                        title: L10n.text("management.indexedDocuments", store.language),
                        value: store.aiHealth?.knowledgeDocumentCount.map { String($0) } ?? "—",
                        symbol: "doc.text.magnifyingglass",
                        tint: ColiDevVisualSystem.managementKnowledge.color
                    )
                    metric(
                        title: L10n.text("management.sourcesTotal", store.language),
                        value: sourceInventory.map { String($0.listedCount) } ?? "—",
                        symbol: "link",
                        tint: ColiDevVisualSystem.managementSources.color
                    )
                    metric(
                        title: L10n.text("management.sourcesAttention", store.language),
                        value: sourceInventory.map { String($0.needsAttentionCount + $0.uncheckedCount) } ?? "—",
                        symbol: "exclamationmark.bubble",
                        tint: .orange
                    )
                    metric(
                        title: L10n.text("management.reviewDue", store.language),
                        value: store.aiHealth?.knowledgeReviewDueDocumentCount.map { String($0) } ?? "—",
                        symbol: "calendar.badge.exclamationmark",
                        tint: ColiDevVisualSystem.managementReviewDue.color
                    )
                    metric(
                        title: L10n.text("management.reviewScheduleMissing", store.language),
                        value: store.aiHealth?.knowledgeReviewScheduleMissingDocumentCount.map { String($0) } ?? "—",
                        symbol: "calendar.badge.questionmark",
                        tint: .secondary
                    )
                }

                GroupBox(label: Text(L10n.text("management.systemStatus", store.language))
                    .accessibilityIdentifier("control-center.overview.system-status")) {
                    VStack(spacing: 10) {
                        statusRow(
                            title: L10n.text("management.network", store.language),
                            value: L10n.text(networkStatus.key, store.language),
                            symbol: networkStatus.symbol
                        )
                        statusRow(
                            title: L10n.text("management.indexChecked", store.language),
                            value: store.aiHealth?.displayKnowledgeIndexCheckedAt ?? "—",
                            symbol: "clock"
                        )
                        statusRow(
                            title: L10n.text("management.embedding", store.language),
                            value: store.aiHealth?.ollamaEmbeddingModel
                                ?? L10n.text("settings.aiSemanticKeyword", store.language),
                            symbol: "point.3.connected.trianglepath.dotted"
                        )
                        statusRow(
                            title: L10n.text("management.dailyOnlineLimit", store.language),
                            value: dailyOnlineLimitSummary,
                            symbol: "chart.bar"
                        )
                        Text(L10n.text("management.dailyOnlineLimitCaveat", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        statusRow(
                            title: L10n.text("management.dailyCloudCalls", store.language),
                            value: dailyCloudCallSummary,
                            symbol: "cloud"
                        )
                        Text(L10n.text("management.dailyCloudCallsCaveat", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 6)
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await refreshIndex() }
                    } label: {
                        if isRefreshingIndex {
                            ProgressView().controlSize(.small)
                            Text(L10n.text("management.refreshIndexRunning", store.language))
                        } else {
                            Label(L10n.text("management.refreshIndex", store.language), systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefreshingIndex || isCheckingSources)

                    Button {
                        Task { await checkSources() }
                    } label: {
                        if isCheckingSources {
                            ProgressView().controlSize(.small)
                            Text(L10n.text("management.checkSourcesRunning", store.language))
                        } else {
                            Label(L10n.text("management.checkSources", store.language), systemImage: "checkmark.icloud")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCheckingSources || isRefreshingIndex)

                    Button {
                        Task { await prepareDiagnosticsExport() }
                    } label: {
                        Label(L10n.text("management.diagnosticsExport", store.language), systemImage: "stethoscope")
                    }
                    .buttonStyle(.bordered)
                }

                Text(L10n.text("management.diagnosticsPrivacy", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let usage = store.providerUsage {
                    GroupBox(label: Text(L10n.text("settings.usageTitle", store.language))) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: L10n.text("management.usageResponses", store.language), usage.totals.successfulResponses))
                            Text(String(format: L10n.text("management.usageTokens", store.language), usage.totals.totalTokens))
                                .foregroundStyle(.secondary)
                            Text(String(
                                format: L10n.text("management.usageCost", store.language),
                                usage.totals.reportedCostUSD.map { "$\($0)" }
                                    ?? L10n.text("management.usageUnknownCost", store.language),
                                usage.totals.responsesWithReportedCost ?? 0,
                                usage.totals.successfulResponses
                            ))
                            .font(.caption)
                            if usage.providers.isEmpty {
                                Text(L10n.text("settings.usageNoCalls", store.language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(usage.providers) { provider in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(provider.provider) · \(provider.model)")
                                            .font(.callout.weight(.medium))
                                            .textSelection(.enabled)
                                        Text(String(format: L10n.text("settings.usageProviderCounts", store.language),
                                                    provider.successfulResponses,
                                                    provider.responsesWithReportedUsage,
                                                    provider.totalTokens,
                                                    provider.inputTokens,
                                                    provider.outputTokens))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(String(
                                            format: L10n.text("management.usageProviderCost", store.language),
                                            provider.reportedCostUSD
                                                ?? L10n.text("management.usageUnknownCost", store.language),
                                            provider.responsesWithReportedCost ?? 0,
                                            provider.successfulResponses
                                        ))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                            Text(usage.note)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    }
                }
            }
            .padding(.bottom, 18)
        }
        .accessibilityIdentifier("control-center.overview")
    }

    private var modelsPane: some View {
        let localRoles = store.autoAgentModelRoutes.values
            .filter { $0.effectiveProvider == "ollama" }
            .sorted { $0.role < $1.role }

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.text("management.modelsSubtitle", store.language))
                    .accessibilityIdentifier("control-center.models.description")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                GroupBox(label: Text(L10n.text("management.ollamaLocalService", store.language))) {
                    VStack(alignment: .leading, spacing: 10) {
                        statusRow(
                            title: "Ollama",
                            value: store.localOllamaModelCatalog.available
                                ? L10n.text("management.ollamaServiceReachable", store.language)
                                : L10n.text("management.serviceUnavailable", store.language),
                            symbol: store.localOllamaModelCatalog.available ? "checkmark.circle.fill" : "wifi.slash"
                        )
                        statusRow(
                            title: L10n.text("management.localTutorRoute", store.language),
                            value: store.aiHealth?.hasLocalModel == true
                                ? L10n.text("settings.aiLocalRoute", store.language)
                                : L10n.text("settings.aiNoLocal", store.language),
                            symbol: store.aiHealth?.hasLocalModel == true ? "checkmark.circle.fill" : "exclamationmark.circle"
                        )
                        Text(L10n.text("management.localModelsDescription", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            Task { await store.refreshLocalOllamaModelCatalog() }
                        } label: {
                            if store.isRefreshingLocalOllamaModelCatalog {
                                ProgressView().controlSize(.small)
                            } else {
                                Label(
                                    L10n.text("management.ollamaModelsRefresh", store.language),
                                    systemImage: "arrow.clockwise"
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.isRefreshingLocalOllamaModelCatalog)

                        if store.localOllamaModelCatalog.available {
                            if store.localOllamaModelCatalog.models.isEmpty {
                                Text(L10n.text("management.ollamaModelsEmpty", store.language))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(store.localOllamaModelCatalog.models, id: \.self) { model in
                                        Label(model, systemImage: "cube")
                                            .font(.callout.monospaced())
                                            .textSelection(.enabled)
                                            .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                }

                GroupBox(label: Text(L10n.text("management.localModelAssignments", store.language))) {
                    VStack(alignment: .leading, spacing: 8) {
                        if localRoles.isEmpty {
                            Text(L10n.text("management.noLocalModelRoles", store.language))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(localRoles) { route in
                                statusRow(
                                    title: L10n.text("management.autoAgentRole.\(route.role)", store.language),
                                    value: route.effectiveModel,
                                    symbol: route.effectiveProviderReady == true
                                        ? "checkmark.circle.fill"
                                        : "exclamationmark.circle"
                                )
                            }
                        }

                        Button(L10n.text("management.configureAIRoutes", store.language)) {
                            pane = .integrations
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                }
            }
            .padding(.bottom, 18)
        }
        .accessibilityIdentifier("control-center.models")
    }

    private var coursesPane: some View {
        let coverage = courseCoverage
        let totalLessons = coverage.reduce(0) { $0 + $1.bundledLessonCount }
        let bilingualLessons = coverage.reduce(0) { $0 + $1.bilingualLessonCount }
        let sourceCitedLessons = coverage.reduce(0) { $0 + $1.sourceCitedLessonCount }
        let structurallyCompleteLessons = coverage.reduce(0) { $0 + $1.structurallyCompleteLessonCount }

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.text("management.coursesDescription", store.language))
                    .accessibilityIdentifier("control-center.courses.description")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if coverage.isEmpty {
                    HStack(spacing: 10) {
                        if isLoadingCourseCoverage {
                            ProgressView().controlSize(.small)
                        }
                        Text(L10n.text(
                            isLoadingCourseCoverage ? "management.courseCoverageLoading" : "management.courseCoverageEmpty",
                            store.language
                        ))
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                } else {
                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                        metric(
                            title: L10n.text("management.courseFiles", store.language),
                            value: String(totalLessons),
                            symbol: "books.vertical",
                            tint: .accentColor
                        )
                        metric(
                            title: L10n.text("management.courseBilingual", store.language),
                            value: "\(bilingualLessons) / \(totalLessons)",
                            symbol: "character.bubble",
                            tint: bilingualLessons == totalLessons ? .green : .orange
                        )
                        metric(
                            title: L10n.text("management.courseWithSources", store.language),
                            value: "\(sourceCitedLessons) / \(totalLessons)",
                            symbol: "link",
                            tint: sourceCitedLessons == totalLessons ? .green : .orange
                        )
                        metric(
                            title: L10n.text("management.courseStructured", store.language),
                            value: "\(structurallyCompleteLessons) / \(totalLessons)",
                            symbol: "checklist",
                            tint: structurallyCompleteLessons == totalLessons ? .green : .orange
                        )
                    }

                    ForEach(coverage) { subjectCoverage in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: subjectCoverage.subject.symbol)
                                        .foregroundStyle(subjectCoverage.subject.tint)
                                        .frame(width: 22)
                                    Text(subjectCoverage.subject.title(in: store.language))
                                        .font(.headline)
                                    Spacer()
                                    Text(String(
                                        format: L10n.text("management.courseSubjectSummary", store.language),
                                        subjectCoverage.bilingualLessonCount,
                                        subjectCoverage.bundledLessonCount,
                                        subjectCoverage.structurallyCompleteLessonCount,
                                        subjectCoverage.topicCount
                                    ))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                }

                                ForEach(subjectCoverage.levels) { level in
                                    HStack {
                                        Text(level.level.value(in: store.language))
                                            .frame(minWidth: 105, alignment: .leading)
                                        Spacer()
                                        Text(String(
                                            format: L10n.text("management.courseLevelSummary", store.language),
                                            level.linkedLessonCount,
                                            level.topicCount
                                        ))
                                        .font(.callout.monospacedDigit())
                                        .foregroundStyle(level.linkedLessonCount == level.topicCount ? Color.green : Color.secondary)
                                    }
                                    .font(.subheadline)
                                }

                                if subjectCoverage.lessonStructureIssues.isEmpty {
                                    Label(
                                        L10n.text("management.courseStructureComplete", store.language),
                                        systemImage: "checkmark.circle.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                } else {
                                    DisclosureGroup {
                                        VStack(alignment: .leading, spacing: 10) {
                                            ForEach(subjectCoverage.lessonStructureIssues) { issue in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(String(
                                                        format: L10n.text("management.courseStructureResource", store.language),
                                                        issue.resource
                                                    ))
                                                    .font(.caption.weight(.semibold))
                                                    Text(String(
                                                        format: L10n.text("management.courseStructureRussian", store.language),
                                                        structureSectionSummary(issue.missingRussianSections)
                                                    ))
                                                    .font(.caption)
                                                    Text(String(
                                                        format: L10n.text("management.courseStructureEnglish", store.language),
                                                        structureSectionSummary(issue.missingEnglishSections)
                                                    ))
                                                    .font(.caption)
                                                    if issue.missingSources {
                                                        Text(L10n.text("management.courseStructureSources", store.language))
                                                            .font(.caption)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 5)
                                            }
                                        }
                                        .padding(.top, 8)
                                    } label: {
                                        Label(
                                            String(
                                                format: L10n.text("management.courseStructureIssues", store.language),
                                                subjectCoverage.lessonStructureIssues.count
                                            ),
                                            systemImage: "exclamationmark.circle"
                                        )
                                        .font(.caption.weight(.medium))
                                    }
                                    .tint(.orange)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 5)
                        }
                    }

                    Label(L10n.text("management.courseCoverageCaveat", store.language), systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 18)
        }
        .accessibilityIdentifier("control-center.courses")
    }

    private func structureSectionSummary(_ sectionKeys: [String]) -> String {
        guard !sectionKeys.isEmpty else {
            return L10n.text("management.courseStructureNone", store.language)
        }
        return sectionKeys
            .map { L10n.text($0, store.language) }
            .joined(separator: ", ")
    }

    private var ragPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("management.ragExplanation", store.language))
                .accessibilityIdentifier("control-center.rag.description")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ollamaEmbeddingSettingsCard

            HStack(spacing: 10) {
                TextField(L10n.text("management.ragQuery", store.language), text: $ragQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await searchRAG() } }

                Button {
                    Task { await searchRAG() }
                } label: {
                    if isSearchingRAG {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(L10n.text("management.ragSearch", store.language), systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSearchingRAG || ragQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Toggle(L10n.text("management.ragIncludeObsidian", store.language), isOn: $includeObsidianRAG)
                .toggleStyle(.checkbox)

            if let ragSearchResult {
                HStack {
                    Label(
                        String(format: L10n.text("management.ragResultCount", store.language), ragSearchResult.sourceCount),
                        systemImage: "doc.text.magnifyingglass"
                    )
                    Spacer()
                    Text(ragSearchResult.generatedAt)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                if ragSearchResult.sources.isEmpty {
                    Label(L10n.text("management.ragNoResults", store.language), systemImage: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(ragSearchResult.sources) { source in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(source.id)
                                    .font(.caption.weight(.bold).monospaced())
                                    .foregroundStyle(Color.accentColor)
                                Text(source.title)
                                    .font(.headline)
                                    .textSelection(.enabled)
                                Spacer(minLength: 8)
                                Text(L10n.text("management.ragType.\(source.sourceType ?? "course")", store.language))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            Text(source.excerpt)
                                .font(.callout)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)

                            if let path = source.path {
                                if source.sourceType == "official_web", let url = URL(string: path) {
                                    Link(path, destination: url)
                                        .font(.caption.monospaced())
                                        .lineLimit(2)
                                        .textSelection(.enabled)
                                } else {
                                    Text(source.location.map { "\(path):\($0)" } ?? path)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.tertiary)
                                        .textSelection(.enabled)
                                }
                            }

                            HStack(spacing: 12) {
                                Text("\(L10n.text("management.ragRetrieved", store.language)): \(source.displayRetrievedAt)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                if let sourceCheckedAt = source.sourceCheckedAt {
                                    Text("\(L10n.text("management.ragFreshness", store.language)): \(sourceCheckedAt)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            if let snapshotFetchedAt = source.sourceSnapshotFetchedAt {
                                Text("\(L10n.text("tutor.sourceSnapshotFetchedAt", store.language)): \(snapshotFetchedAt)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            if source.sourceType == "official_web",
                               source.pagePublishedAt != nil || source.pageUpdatedAt != nil {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let publishedAt = source.pagePublishedAt {
                                        Text("\(L10n.text("tutor.publisherPublishedAt", store.language)): \(publishedAt)")
                                    }
                                    if let updatedAt = source.pageUpdatedAt {
                                        Text("\(L10n.text("tutor.publisherUpdatedAt", store.language)): \(updatedAt)")
                                    }
                                    Text(L10n.text("tutor.publisherDateCaveat", store.language))
                                        .foregroundStyle(.tertiary)
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }

                            if let license = source.license {
                                Text("\(license) · \(source.attribution ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let licenseURL = source.licenseURL, let url = URL(string: licenseURL) {
                                Link(L10n.text("management.ragLicense", store.language), destination: url)
                                    .font(.caption)
                            }

                            if let references = source.officialReferences, !references.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(references) { reference in
                                        if let url = URL(string: reference.url) {
                                            Link(reference.title, destination: url)
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 320)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(L10n.text("management.ragEmptyTitle", store.language))
                        .font(.headline)
                    Text(L10n.text("management.ragEmptyBody", store.language))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("control-center.rag")
    }

    private var sourcesPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("management.sourceExplanation", store.language))
                .accessibilityIdentifier("control-center.sources.description")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let automaticCheckEnabled = sourceInventory?.automaticCheckEnabled {
                Label(
                    automaticCheckEnabled
                        ? String(
                            format: L10n.text("management.autoSourceCheckEnabled", store.language),
                            sourceInventory?.automaticCheckIntervalHours ?? 24
                        )
                        : L10n.text("management.autoSourceCheckDisabled", store.language),
                    systemImage: automaticCheckEnabled ? "clock.arrow.circlepath" : "pause.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if automaticCheckEnabled,
                   let dueAt = sourceInventory?.automaticCheckDueAt {
                    Label(
                        String(
                            format: L10n.text("management.autoSourceCheckDue", store.language),
                            formatManagementDate(dueAt)
                        ),
                        systemImage: "calendar.badge.clock"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("control-center.sources.next-check")
                }
            }

            HStack(spacing: 10) {
                TextField(L10n.text("management.sourceSearch", store.language), text: $sourceSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)

                Picker(selection: $sourceFilter) {
                    ForEach(SourceRegistryFilter.allCases) { filter in
                        Text(L10n.text(filter.titleKey, store.language)).tag(filter)
                    }
                } label: {
                    Label(L10n.text("management.sourceFilter", store.language), systemImage: "line.3.horizontal.decrease")
                }
                .pickerStyle(.menu)

                Spacer(minLength: 8)

                Button {
                    Task { await checkSources() }
                } label: {
                    if isCheckingSources {
                        ProgressView().controlSize(.small)
                        Text(L10n.text("management.checkSourcesRunning", store.language))
                    } else {
                        Label(L10n.text("management.checkSources", store.language), systemImage: "checkmark.icloud")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCheckingSources || isRefreshingIndex)

                if let sourceInventory {
                    Text("\(visibleSourceItems.count) / \(sourceInventory.listedCount)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let sourceInventory {
                let due = sourceInventory.editorialReviewDueCount ?? 0
                let missingDate = sourceInventory.editorialReviewMissingCount ?? 0
                let missingSchedule = sourceInventory.editorialReviewUnscheduledCount ?? 0
                if due + missingDate + missingSchedule > 0 {
                    Label(
                        String(
                            format: L10n.text("management.editorialReviewSummary", store.language),
                            due,
                            missingDate,
                            missingSchedule
                        ),
                        systemImage: due > 0 || missingDate > 0
                            ? "exclamationmark.circle.fill"
                            : "calendar.badge.clock"
                    )
                    .font(.caption)
                    .foregroundStyle(due > 0 || missingDate > 0 ? Color.orange : Color.secondary)
                }
            }

            if let sourceInventory {
                if sourceInventory.sources.isEmpty {
                    Label(L10n.text("management.noSources", store.language), systemImage: "link")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if visibleSourceItems.isEmpty {
                    Label(L10n.text("management.sourceNoMatches", store.language), systemImage: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if sourcePageCount > 1 {
                        HStack(spacing: 12) {
                            Text(
                                String(
                                    format: L10n.text("management.sourcePageStatus", store.language),
                                    min(sourcePage + 1, sourcePageCount),
                                    sourcePageCount
                                )
                            )
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("control-center.sources.page-status")

                            Spacer()

                            Button {
                                sourcePage = max(0, sourcePage - 1)
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(.bordered)
                            .help(L10n.text("management.sourcePagePrevious", store.language))
                            .accessibilityLabel(L10n.text("management.sourcePagePrevious", store.language))
                            .accessibilityIdentifier("control-center.sources.previous-page")
                            .disabled(sourcePage == 0)

                            Button {
                                sourcePage = min(sourcePageCount - 1, sourcePage + 1)
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .buttonStyle(.bordered)
                            .help(L10n.text("management.sourcePageNext", store.language))
                            .accessibilityLabel(L10n.text("management.sourcePageNext", store.language))
                            .accessibilityIdentifier("control-center.sources.next-page")
                            .disabled(sourcePage >= sourcePageCount - 1)
                        }
                    }

                    List(pagedSourceItems) { source in
                        SourceRegistryRow(source: source, language: store.language) {
                            Task { await reloadSourceInventory() }
                        }
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 320)
                }
                if sourceInventory.unsupportedCount > 0 || sourceInventory.omittedCount > 0 {
                    Text(String(format: L10n.text("management.sourceOmissions", store.language), sourceInventory.unsupportedCount, sourceInventory.omittedCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if isLoading {
                ProgressView(L10n.text("management.loading", store.language))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Label(L10n.text("management.loadFailed", store.language), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("control-center.sources")
    }

    private var visibleSourceItems: [TrustedSourceInventoryItem] {
        let sources = sourceInventory?.sources ?? []
        let query = sourceSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sources.filter { source in
            let lessonPaths = source.lessonPaths ?? [source.lessonPath]
            let subjectNames: [(folder: String, ru: String, en: String)] = [
                ("Mathematics", "Математика", "Mathematics"),
                ("English", "Английский", "English"),
                ("Physics", "Физика", "Physics"),
                ("Chemistry", "Химия", "Chemistry"),
                ("Biology", "Биология", "Biology"),
                ("Zoology", "Зоология", "Zoology"),
                ("Programming", "Программирование", "Programming"),
            ]
            let subjectSearchText = subjectNames
                .filter { subject in
                    lessonPaths.contains { $0.localizedCaseInsensitiveContains("/\(subject.folder)/") }
                }
                .map { "\($0.ru) \($0.en)" }
                .joined(separator: " ")
            let searchableText = [
                source.title,
                source.pageTitle ?? "",
                source.pageDescription ?? "",
                source.url,
                subjectSearchText,
                lessonPaths.joined(separator: " "),
            ].joined(separator: " ")
            guard query.isEmpty || searchableText.localizedCaseInsensitiveContains(query) else {
                return false
            }

            let reviewStatuses = source.lessonReviews?.map(\.editorialReviewStatus)
                ?? [source.editorialReviewStatus ?? "review_missing"]
            switch sourceFilter {
            case .all:
                return true
            case .attention:
                return source.state != "unchanged" || reviewStatuses.contains { $0 != "review_scheduled" }
            case .changed:
                return source.state == "changed"
            case .review:
                return reviewStatuses.contains { $0 != "review_scheduled" }
            }
        }
    }

    private var sourcePageCount: Int {
        max(1, (visibleSourceItems.count + sourcePageSize - 1) / sourcePageSize)
    }

    private var pagedSourceItems: [TrustedSourceInventoryItem] {
        let currentPage = min(sourcePage, sourcePageCount - 1)
        let startIndex = currentPage * sourcePageSize
        return Array(visibleSourceItems.dropFirst(startIndex).prefix(sourcePageSize))
    }

    private var ollamaEmbeddingSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(L10n.text("management.ragEmbeddingTitle", store.language))
                    .font(.headline)
            } icon: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(ColiDevVisualSystem.managementSources.color)
            }

            Text(L10n.text("management.ragEmbeddingDescription", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TextField(
                    L10n.text("management.ragEmbeddingModelPlaceholder", store.language),
                    text: $ollamaEmbeddingModelDraft
                )
                .textFieldStyle(.roundedBorder)
                .disabled(isSavingOllamaEmbeddingSettings)
                .accessibilityIdentifier("control-center.rag.embedding-model")

                Menu {
                    ForEach(store.localOllamaModelCatalog.models, id: \.self) { model in
                        Button(model) { ollamaEmbeddingModelDraft = model }
                    }
                } label: {
                    Label(L10n.text("management.ragEmbeddingInstalledModels", store.language), systemImage: "chevron.down")
                }
                .disabled(store.localOllamaModelCatalog.models.isEmpty || isSavingOllamaEmbeddingSettings)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await saveOllamaEmbeddingModel() }
                } label: {
                    if isSavingOllamaEmbeddingSettings {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(L10n.text("management.ragEmbeddingSave", store.language), systemImage: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    isLoadingOllamaEmbeddingSettings
                        || isSavingOllamaEmbeddingSettings
                        || ollamaEmbeddingModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .accessibilityIdentifier("control-center.rag.save-embedding-model")

                Button {
                    Task { await disableOllamaEmbeddingModel() }
                } label: {
                    Label(L10n.text("management.ragEmbeddingDisable", store.language), systemImage: "text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingOllamaEmbeddingSettings || isSavingOllamaEmbeddingSettings)
                .accessibilityIdentifier("control-center.rag.disable-embedding-model")

                Spacer(minLength: 0)

                if isLoadingOllamaEmbeddingSettings {
                    ProgressView().controlSize(.small)
                } else if let settings = ollamaEmbeddingModelSettings {
                    Label(
                        L10n.text(
                            settings.configured ? "management.ragEmbeddingEnabled" : "management.ragEmbeddingKeywordOnly",
                            store.language
                        ),
                        systemImage: settings.configured ? "checkmark.circle.fill" : "text.magnifyingglass"
                    )
                    .font(.caption)
                    .foregroundStyle(settings.configured ? Color.green : Color.secondary)
                    .accessibilityIdentifier("control-center.rag.embedding-status")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .coliGlassControl(cornerRadius: 16)
    }

    // Until the backend answers, the network state is unknown rather than offline.
    private var networkStatus: (key: String, symbol: String) {
        switch store.aiHealth?.online {
        case true?:
            return ("management.networkOnline", "network")
        case false?:
            return ("management.networkOffline", "wifi.slash")
        case nil:
            return (store.isCheckingAI ? "management.networkChecking" : "management.networkUnknown", "network")
        }
    }

    private var dailyOnlineLimitSummary: String {
        guard let current = store.aiHealth?.sessionCurrent,
              let maximum = store.aiHealth?.sessionMax else {
            return "—"
        }
        return String(format: L10n.text("management.dailyOnlineLimitValue", store.language), current, maximum)
    }

    @MainActor
    private func prepareDiagnosticsExport() async {
        let courseCoverageSnapshot = await loadCourseCoverageIfNeeded()
        let health = store.aiHealth
        let inventory = sourceInventory
        let usage = store.providerUsage
        let coverage: [[String: Any]] = courseCoverageSnapshot.map { value in
            return [
                "subject": value.subject.rawValue,
                "bundled_lessons": value.bundledLessonCount,
                "bilingual_lessons": value.bilingualLessonCount,
                "lessons_with_sources": value.sourceCitedLessonCount,
                "roadmap_topics": value.topicCount,
                "topics_linked_to_full_lessons": value.linkedLessonCount,
            ]
        }
        let modelUsage: [[String: Any]] = usage?.providers.map { provider in
            [
                "provider": provider.provider,
                "model": provider.model,
                "successful_responses": provider.successfulResponses,
                "reported_tokens": provider.totalTokens,
                "reported_cost_usd": provider.reportedCostUSD as Any? ?? NSNull(),
                "responses_with_reported_cost": provider.responsesWithReportedCost as Any? ?? NSNull(),
            ]
        } ?? []
        let report: [String: Any] = [
            "schema_version": 1,
            "generated_at": ISO8601DateFormatter().string(from: Date()),
            "app": [
                "bundle_identifier": Bundle.main.bundleIdentifier ?? "unknown",
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
                "language": store.language.rawValue,
            ],
            "system": [
                "operating_system": ProcessInfo.processInfo.operatingSystemVersionString,
            ],
            "backend": [
                "ready": backendSupervisor.isReady,
                "health_available": health != nil,
                "online": health?.online as Any? ?? NSNull(),
                "ollama_available": health?.ollamaAvailable as Any? ?? NSNull(),
                "ollama_model_ready": health?.ollamaModelReady as Any? ?? NSNull(),
                "ollama_endpoint_is_local": health?.isOllamaEndpointLocal as Any? ?? NSNull(),
                "obsidian_endpoint_is_local": health?.isObsidianEndpointLocal as Any? ?? NSNull(),
                "indexed_documents": health?.knowledgeDocumentCount as Any? ?? NSNull(),
                "index_checked_at": health?.knowledgeIndexCheckedAt as Any? ?? NSNull(),
                "online_requests_today": health?.sessionCurrent as Any? ?? NSNull(),
                "online_requests_daily_limit": health?.sessionMax as Any? ?? NSNull(),
                "cloud_model_calls_today": health?.cloudModelCallsToday as Any? ?? NSNull(),
                "cloud_model_calls_daily_limit": health?.cloudModelCallsMax as Any? ?? NSNull(),
                "review_items_due": health?.knowledgeReviewDueDocumentCount as Any? ?? NSNull(),
                "review_schedules_missing": health?.knowledgeReviewScheduleMissingDocumentCount as Any? ?? NSNull(),
            ],
            "sources": [
                "inventory_available": inventory != nil,
                "listed": inventory?.listedCount as Any? ?? NSNull(),
                "unchecked": inventory?.uncheckedCount as Any? ?? NSNull(),
                "changed": inventory?.changedCount as Any? ?? NSNull(),
                "needs_attention": inventory?.needsAttentionCount as Any? ?? NSNull(),
                "automatic_check_enabled": inventory?.automaticCheckEnabled as Any? ?? NSNull(),
                "automatic_check_interval_hours": inventory?.automaticCheckIntervalHours as Any? ?? NSNull(),
                "automatic_check_due_at": inventory?.automaticCheckDueAt as Any? ?? NSNull(),
                "unsupported": inventory?.unsupportedCount as Any? ?? NSNull(),
                "omitted": inventory?.omittedCount as Any? ?? NSNull(),
            ],
            "curriculum": coverage,
            "provider_usage": [
                "available": usage != nil,
                "period_days": usage?.periodDays as Any? ?? NSNull(),
                "successful_responses": usage?.totals.successfulResponses as Any? ?? NSNull(),
                "reported_tokens": usage?.totals.totalTokens as Any? ?? NSNull(),
                "reported_cost_usd": usage?.totals.reportedCostUSD as Any? ?? NSNull(),
                "responses_with_reported_cost": usage?.totals.responsesWithReportedCost as Any? ?? NSNull(),
                "models": modelUsage,
            ],
            "privacy": [
                "api_keys_included": false,
                "chat_messages_included": false,
                "learning_reflections_included": false,
                "source_page_text_included": false,
            ],
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            diagnosticsDocument = LearningProgressBackupFile(data: data)
            statusMessage = nil
            isExportingDiagnostics = true
        } catch {
            reportError("management.diagnosticsFailed")
        }
    }

    private var dailyCloudCallSummary: String {
        guard let current = store.aiHealth?.cloudModelCallsToday,
              let maximum = store.aiHealth?.cloudModelCallsMax else {
            return L10n.text("management.usageUnknown", store.language)
        }
        return String(format: L10n.text("management.dailyOnlineLimitValue", store.language), current, maximum)
    }

    private var integrationsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox(
                    label: Text(L10n.text("management.providers", store.language))
                        .accessibilityIdentifier("control-center.integrations.providers-heading")
                ) {
                    VStack(spacing: 10) {
                        integrationRow(
                            title: "Gemini",
                            symbol: "sparkles",
                            detail: keyStatus("gemini"),
                            ready: store.providerSecretStatuses["gemini"]?.configured == true
                        )
                        integrationRow(
                            title: "Kimi",
                            symbol: "brain.head.profile",
                            detail: keyStatus("kimi"),
                            ready: store.providerSecretStatuses["kimi"]?.configured == true
                        )
                        integrationRow(
                            title: "OpenRouter",
                            symbol: "point.3.connected.trianglepath.dotted",
                            detail: store.aiHealth?.openRouterModel ?? keyStatus("openrouter"),
                            ready: store.providerSecretStatuses["openrouter"]?.configured == true
                        )
                        integrationRow(
                            title: L10n.text("management.compatibleTitle", store.language),
                            symbol: "point.3.connected.trianglepath.dotted",
                            detail: store.openAICompatibleSettings?.baseURL.isEmpty == false
                                ? (store.openAICompatibleSettings?.model ?? "")
                                : L10n.text("management.notConfigured", store.language),
                            ready: store.providerSecretStatuses["compatible"]?.configured == true
                                && store.openAICompatibleSettings?.providerReady == true
                        )
                        integrationRow(
                            title: "Ollama",
                            symbol: "desktopcomputer",
                            detail: store.aiHealth?.ollamaModel ?? L10n.text("management.serviceUnavailable", store.language),
                            ready: store.aiHealth?.hasLocalModel == true
                        )
                        integrationRow(
                            title: "Obsidian",
                            symbol: "externaldrive",
                            detail: store.aiHealth?.isObsidianEndpointLocal == true
                                ? keyStatus("obsidian")
                                : L10n.text("management.serviceUnavailable", store.language),
                            ready: store.aiHealth?.isObsidianEndpointLocal == true
                                && store.providerSecretStatuses["obsidian"]?.configured == true
                        )
                        integrationRow(
                            title: "NotebookLM",
                            symbol: "doc.on.doc",
                            detail: L10n.text("management.notebookManual", store.language),
                            ready: nil
                        )
                    }
                    .padding(.top, 6)
                }

                GroupBox(label: Text(L10n.text("settings.keysTitle", store.language))) {
                    VStack(alignment: .leading, spacing: 12) {
                        ProviderKeyEntryView(provider: "gemini", title: "Gemini")
                        ProviderKeyEntryView(provider: "kimi", title: "Kimi")
                        ProviderKeyEntryView(provider: "openrouter", title: "OpenRouter")
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.text("management.compatibleTitle", store.language))
                                .font(.headline)
                            Text(L10n.text("management.compatibleHelp", store.language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            TextField(
                                L10n.text("management.compatibleBaseURL", store.language),
                                text: $compatibleBaseURL
                            )
                            .textFieldStyle(.roundedBorder)
                            TextField(
                                L10n.text("management.compatibleModel", store.language),
                                text: $compatibleModel
                            )
                            .textFieldStyle(.roundedBorder)
                            HStack {
                                Button {
                                    Task { await saveCompatibleSettings() }
                                } label: {
                                    if isSavingCompatibleSettings {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Text(L10n.text("management.compatibleSave", store.language))
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isSavingCompatibleSettings)
                                if let config = store.openAICompatibleSettings, config.providerReady {
                                    Label(L10n.text("management.compatibleReady", store.language), systemImage: "checkmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            ProviderKeyEntryView(
                                provider: "compatible",
                                title: L10n.text("management.compatibleKeyTitle", store.language)
                            )
                        }
                        .padding(.vertical, 4)
                        ProviderKeyEntryView(provider: "obsidian", title: "Obsidian Local REST API")
                        Text(L10n.text("settings.keysPrivacy", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                GroupBox(label: Text(L10n.text("management.agents", store.language))) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(L10n.text("management.agentStatus", store.language))
                            .font(.callout)
                        Text(L10n.text("management.agentCaveat", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                }

                GroupBox(label: Text(L10n.text("management.backupTitle", store.language))) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.text("management.backupDescription", store.language))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.text("management.backupPrivacy", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            Button {
                                Task { await prepareProgressBackup() }
                            } label: {
                                if isPreparingBackup {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label(L10n.text("management.backupExport", store.language), systemImage: "square.and.arrow.down")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isPreparingBackup || isRestoringBackup)

                            Button {
                                isImportingBackup = true
                            } label: {
                                Label(L10n.text("management.backupImport", store.language), systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isPreparingBackup || isRestoringBackup)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                }

                GroupBox(label: Text(L10n.text("management.autoCostPolicy", store.language))) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.text("management.autoCostPolicyHelp", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Toggle(
                            L10n.text("management.allowPaidAutoRoutes", store.language),
                            isOn: $allowsPaidAutoRoutes
                        )

                        Stepper(value: $dailyCloudCallLimit, in: 0...1_000) {
                            HStack {
                                Text(L10n.text("management.dailyCloudCallLimitSetting", store.language))
                                Spacer()
                                Text(dailyCloudCallLimit.formatted())
                                    .monospacedDigit()
                                    .accessibilityIdentifier("control-center.daily-cloud-call-limit.value")
                            }
                        }
                        .accessibilityIdentifier("control-center.daily-cloud-call-limit")

                        Text(L10n.text("management.dailyCloudCallLimitHelp", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            Task { await saveAutoCostPolicy() }
                        } label: {
                            if isSavingCostPolicy {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(L10n.text("management.saveCostPolicy", store.language))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSavingCostPolicy)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                }

                GroupBox(label: Text(L10n.text("management.finalSynthesis", store.language))) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.text("management.finalSynthesisHelp", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Picker(L10n.text("management.routeProvider", store.language), selection: $finalSynthesisProvider) {
                            ForEach(["auto", "gemini", "kimi", "openrouter", "compatible", "ollama"], id: \.self) { provider in
                                Text(L10n.text("management.routeProvider.\(provider)", store.language))
                                    .tag(provider)
                            }
                        }
                        .frame(maxWidth: 360, alignment: .leading)

                        if finalSynthesisProvider != "auto" {
                            TextField(L10n.text("management.routeModel", store.language), text: $finalSynthesisModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 520)
                        }
                        if routeMaySendContextToCloud(
                            provider: finalSynthesisProvider,
                            activeProvider: store.finalSynthesisModelRoute?.effectiveProvider
                        ) {
                            Label(
                                L10n.text("management.autoAgentCloudNotice", store.language),
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        if let route = store.finalSynthesisModelRoute {
                            HStack(spacing: 8) {
                                Image(systemName: route.providerReady == false
                                      ? "exclamationmark.circle"
                                      : (route.provider == "auto" ? "arrow.triangle.2.circlepath" : "checkmark.circle"))
                                    .foregroundStyle(route.providerReady == false ? Color.orange : Color.secondary)
                                Text(L10n.text("management.routeStatus.\(route.status)", store.language))
                                Text(
                                    "\(L10n.text("management.routeProvider.\(route.provider)", store.language)) → " +
                                        L10n.text("management.routeProvider.\(route.effectiveProvider)", store.language)
                                )
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                Text(route.effectiveModel)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .font(.caption)
                            .accessibilityElement(children: .combine)
                        }

                        HStack(spacing: 10) {
                            Button {
                                Task { await saveFinalSynthesisRoute() }
                            } label: {
                                if isSavingRoute {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text(L10n.text("management.routeSave", store.language))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSavingRoute)

                            Button(L10n.text("management.routeReset", store.language)) {
                                Task { await resetFinalSynthesisRoute() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isSavingRoute)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                }

                GroupBox(label: Text(L10n.text("management.subjectRouting", store.language))) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker(L10n.text("management.routeSubject", store.language), selection: $routeSubject) {
                            ForEach(Subject.allCases) { subject in
                                Text(subject.title(in: store.language)).tag(subject)
                            }
                        }
                        .frame(maxWidth: 360, alignment: .leading)

                        Picker(L10n.text("management.routeProvider", store.language), selection: $routeProvider) {
                            ForEach(["auto", "gemini", "kimi", "openrouter", "compatible", "ollama"], id: \.self) { provider in
                                Text(L10n.text("management.routeProvider.\(provider)", store.language))
                                    .tag(provider)
                            }
                        }
                        .frame(maxWidth: 360, alignment: .leading)

                        if routeProvider != "auto" {
                            TextField(L10n.text("management.routeModel", store.language), text: $routeModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 520)
                            Text(L10n.text("management.routeModelHelp", store.language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if routeMaySendContextToCloud(
                            provider: routeProvider,
                            activeProvider: store.subjectModelRoutes[routeSubject.rawValue]?.effectiveProvider
                        ) {
                            Label(
                                L10n.text("management.autoAgentCloudNotice", store.language),
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        if let route = store.subjectModelRoutes[routeSubject.rawValue] {
                            HStack(spacing: 8) {
                                Image(systemName: route.effectiveProviderReady == false
                                      ? "exclamationmark.circle"
                                      : (route.provider == "auto" ? "arrow.triangle.2.circlepath" : "checkmark.circle"))
                                    .foregroundStyle(route.effectiveProviderReady == false ? Color.orange : Color.secondary)
                                Text(L10n.text("management.routeStatus.\(route.status)", store.language))
                                Text(
                                    "\(L10n.text("management.routeProvider.\(route.provider)", store.language)) → " +
                                        L10n.text("management.routeProvider.\(route.effectiveProvider)", store.language)
                                )
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                if let model = route.effectiveModel {
                                    Text(model).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                            .font(.caption)
                            .accessibilityElement(children: .combine)
                        }

                        HStack(spacing: 10) {
                            Button {
                                Task { await saveSubjectModelRoute() }
                            } label: {
                                if isSavingRoute {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text(L10n.text("management.routeSave", store.language))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSavingRoute)

                            Button(L10n.text("management.routeReset", store.language)) {
                                Task { await resetSubjectModelRoute() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isSavingRoute)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                }

                GroupBox(label: Text(L10n.text("management.autoAgentModels", store.language))) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.text("management.autoAgentModelsHelp", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Picker(L10n.text("management.autoAgentRole", store.language), selection: $autoAgentRole) {
                            ForEach(["local_draft", "gemini_draft", "critic", "verifier"], id: \.self) { role in
                                Text(L10n.text("management.autoAgentRole.\(role)", store.language)).tag(role)
                            }
                        }
                        .frame(maxWidth: 360, alignment: .leading)

                        Picker(L10n.text("management.routeProvider", store.language), selection: $autoAgentProvider) {
                            ForEach(["auto", "ollama", "openrouter", "gemini", "kimi", "compatible"], id: \.self) { provider in
                                Text(L10n.text("management.routeProvider.\(provider)", store.language))
                                    .tag(provider)
                            }
                        }
                        .frame(maxWidth: 360, alignment: .leading)

                        if autoAgentProvider != "auto" {
                            TextField(L10n.text("management.routeModel", store.language), text: $autoAgentModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 520)
                        }
                        if autoAgentProvider == "ollama" {
                            HStack(spacing: 10) {
                                Button {
                                    Task { await store.refreshLocalOllamaModelCatalog() }
                                } label: {
                                    if store.isRefreshingLocalOllamaModelCatalog {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Label(
                                            L10n.text("management.ollamaModelsRefresh", store.language),
                                            systemImage: "arrow.clockwise"
                                        )
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(store.isRefreshingLocalOllamaModelCatalog)

                                Menu {
                                    ForEach(store.localOllamaModelCatalog.models, id: \.self) { model in
                                        Button(model) { autoAgentModel = model }
                                    }
                                } label: {
                                    Label(
                                        L10n.text("management.ollamaModelsChoose", store.language),
                                        systemImage: "list.bullet"
                                    )
                                }
                                .disabled(store.localOllamaModelCatalog.models.isEmpty)
                            }
                            if store.localOllamaModelCatalog.available {
                                Text(store.localOllamaModelCatalog.models.isEmpty
                                    ? L10n.text("management.ollamaModelsEmpty", store.language)
                                    : L10n.text("management.ollamaModelsReady", store.language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if store.localOllamaModelCatalog.status != "not_checked" {
                                Text(L10n.text(
                                    "management.ollamaModelsStatus.\(store.localOllamaModelCatalog.status)",
                                    store.language
                                ))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if autoAgentProvider != "ollama"
                            && (autoAgentProvider != "auto"
                                || store.autoAgentModelRoutes[autoAgentRole]?.effectiveProvider != "ollama") {
                            Label(
                                L10n.text("management.autoAgentCloudNotice", store.language),
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(L10n.text("management.autoAgentModelHelp", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let route = store.autoAgentModelRoutes[autoAgentRole] {
                            HStack(spacing: 8) {
                                Image(systemName: route.effectiveProviderReady == false ? "exclamationmark.circle" : "checkmark.circle")
                                    .foregroundStyle(route.effectiveProviderReady == false ? Color.orange : Color.secondary)
                                Text(L10n.text("management.routeStatus.\(route.status)", store.language))
                                Text("\(route.effectiveProvider) · \(route.effectiveModel)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .font(.caption)
                            .accessibilityElement(children: .combine)
                        }

                        HStack(spacing: 10) {
                            Button {
                                Task { await saveAutoAgentModel() }
                            } label: {
                                if isSavingRoute {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text(L10n.text("management.routeSave", store.language))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSavingRoute)

                            Button(L10n.text("management.routeReset", store.language)) {
                                Task { await resetAutoAgentModel() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isSavingRoute)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                }

                Button(L10n.text("management.openSettings", store.language), action: openSettings)
                    .buttonStyle(.bordered)
            }
            .padding(.bottom, 18)
        }
        .accessibilityIdentifier("control-center.integrations")
    }

    private func metric(title: String, value: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(
                        colors: [tint.opacity(0.24), tint.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                }
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(value)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.18), tint.opacity(0.045)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        }
        .coliGlassControl(cornerRadius: 14)
    }

    private func statusRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }

    private func integrationRow(title: String, symbol: String, detail: String, ready: Bool?) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: symbol)
            Spacer(minLength: 10)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
            if let ready {
                Image(systemName: ready ? "checkmark.circle.fill" : "minus.circle")
                    .foregroundStyle(ready ? Color.green : Color.secondary)
                    .accessibilityLabel(L10n.text(ready ? "management.serviceReady" : "management.serviceUnavailable", store.language))
            }
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }

    private func keyStatus(_ provider: String) -> String {
        guard let status = store.providerSecretStatuses[provider] else {
            return L10n.text("management.notConfigured", store.language)
        }
        switch status.source {
        case "keychain": return L10n.text("settings.keyStatusKeychain", store.language)
        case "environment": return L10n.text("settings.keyStatusEnvironment", store.language)
        case "missing": return L10n.text("management.notConfigured", store.language)
        default: return L10n.text("management.serviceUnavailable", store.language)
        }
    }

    @MainActor
    private func reloadSourceInventory() async {
        guard let latest = try? await OrchestratorClient.trustedSourceInventory() else { return }
        sourceInventory = latest
    }

    @MainActor
    private func prepareProgressBackup() async {
        isPreparingBackup = true
        defer { isPreparingBackup = false }
        guard await backendSupervisor.ensureRunning() else {
            reportError("management.backupFailed")
            return
        }
        await store.syncStudyProgress()
        guard store.pendingStudyReviewCount == 0 else {
            reportError("management.backupSyncFailed")
            return
        }
        do {
            let data = try await OrchestratorClient.learningProgressBackup()
            progressBackupDocument = LearningProgressBackupFile(data: data)
            isExportingBackup = true
        } catch {
            reportError("management.backupFailed")
        }
    }

    @MainActor
    private func restoreProgressBackup() async {
        guard let pendingBackupData else { return }
        isRestoringBackup = true
        defer {
            isRestoringBackup = false
            self.pendingBackupData = nil
        }
        guard await backendSupervisor.ensureRunning() else {
            reportError("management.backupFailed")
            return
        }
        await store.syncStudyProgress()
        guard store.pendingStudyReviewCount == 0 else {
            reportError("management.backupSyncFailed")
            return
        }
        do {
            let result = try await OrchestratorClient.restoreLearningProgressBackup(pendingBackupData)
            await store.syncStudyProgress()
            statusMessage = String(
                format: L10n.text("management.backupRestored", store.language),
                result.restored,
                result.unchanged
            )
            statusIsError = false
        } catch {
            reportError("management.backupFailed")
        }
    }

    @MainActor
    private func loadCourseCoverageIfNeeded() async -> [SubjectCurriculumCoverage] {
        if hasLoadedCourseCoverage {
            return courseCoverage
        }

        let task: Task<[SubjectCurriculumCoverage], Never>
        if let courseCoverageLoadTask {
            task = courseCoverageLoadTask
        } else {
            isLoadingCourseCoverage = true
            let backgroundTask = Task.detached(priority: .userInitiated) {
                Subject.allCases.map { CurriculumCatalog.coverage(for: $0) }
            }
            courseCoverageLoadTask = backgroundTask
            task = backgroundTask
        }

        let snapshot = await task.value
        if !hasLoadedCourseCoverage {
            courseCoverage = snapshot
            hasLoadedCourseCoverage = true
            courseCoverageLoadTask = nil
        }
        isLoadingCourseCoverage = false
        return courseCoverage
    }

    @MainActor
    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        guard await backendSupervisor.ensureRunning() else {
            statusMessage = L10n.text("management.loadFailed", store.language)
            statusIsError = true
            return
        }
        await store.refreshAIStatus()
        await store.refreshProviderSecretStatuses()
        await store.refreshOpenAICompatibleSettings()
        await store.refreshSubjectModelRoutes()
        await store.refreshAutoAgentModelRoutes()
        await store.refreshLocalOllamaModelCatalog()
        await store.refreshFinalSynthesisModelRoute()
        await store.refreshAutoCostPolicy()
        await store.refreshProviderUsage()
        syncSubjectModelRouteForm()
        syncAutoAgentModelForm()
        syncFinalSynthesisRouteForm()
        syncAutoCostPolicyForm()
        compatibleBaseURL = store.openAICompatibleSettings?.baseURL ?? ""
        compatibleModel = store.openAICompatibleSettings?.model ?? ""
        do {
            sourceInventory = try await OrchestratorClient.trustedSourceInventory()
            statusMessage = nil
            statusIsError = false
        } catch {
            sourceInventory = nil
            statusMessage = L10n.text("management.loadFailed", store.language)
            statusIsError = true
        }
    }

    @MainActor
    private func refreshIndex() async {
        isRefreshingIndex = true
        defer { isRefreshingIndex = false }
        guard await backendSupervisor.ensureRunning() else {
            reportError("management.refreshIndexFailed")
            return
        }
        do {
            let result = try await OrchestratorClient.refreshKnowledgeIndex()
            await store.refreshAIStatus()
            statusMessage = String(format: L10n.text("management.refreshIndexDone", store.language), result.documentCount)
            statusIsError = false
        } catch {
            reportError("management.refreshIndexFailed")
        }
    }

    @MainActor
    private func checkSources() async {
        isCheckingSources = true
        defer { isCheckingSources = false }
        guard await backendSupervisor.ensureRunning() else {
            reportError("management.checkSourcesFailed")
            return
        }
        do {
            let result = try await OrchestratorClient.checkTrustedSourceReferences()
            sourceInventory = try await OrchestratorClient.trustedSourceInventory()
            statusMessage = String(
                format: L10n.text("management.checkSourcesDone", store.language),
                result.checkedCount,
                result.changedCount,
                result.needsAttentionCount
            )
            statusIsError = result.needsAttentionCount > 0
        } catch {
            reportError("management.checkSourcesFailed")
        }
    }

    @MainActor
    private func loadOllamaEmbeddingSettingsIfNeeded() async {
        guard !hasLoadedOllamaEmbeddingSettings else { return }
        hasLoadedOllamaEmbeddingSettings = true
        isLoadingOllamaEmbeddingSettings = true
        defer { isLoadingOllamaEmbeddingSettings = false }
        guard await backendSupervisor.ensureRunning() else {
            hasLoadedOllamaEmbeddingSettings = false
            reportError("management.ragEmbeddingLoadFailed")
            return
        }
        do {
            let settings = try await OrchestratorClient.ollamaEmbeddingModelSettings()
            ollamaEmbeddingModelSettings = settings
            ollamaEmbeddingModelDraft = settings.model ?? ""
            statusMessage = nil
            statusIsError = false
        } catch {
            hasLoadedOllamaEmbeddingSettings = false
            reportError("management.ragEmbeddingLoadFailed")
        }
    }

    @MainActor
    private func saveOllamaEmbeddingModel() async {
        let model = ollamaEmbeddingModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { return }
        await updateOllamaEmbeddingModel(model)
    }

    @MainActor
    private func disableOllamaEmbeddingModel() async {
        await updateOllamaEmbeddingModel(nil)
    }

    @MainActor
    private func updateOllamaEmbeddingModel(_ model: String?) async {
        isSavingOllamaEmbeddingSettings = true
        defer { isSavingOllamaEmbeddingSettings = false }
        guard await backendSupervisor.ensureRunning() else {
            reportError("management.ragEmbeddingSaveFailed")
            return
        }
        do {
            let settings = try await OrchestratorClient.saveOllamaEmbeddingModel(model)
            ollamaEmbeddingModelSettings = settings
            ollamaEmbeddingModelDraft = settings.model ?? ""
            await store.refreshAIStatus()
            if let savedModel = settings.model, settings.configured {
                statusMessage = String(
                    format: L10n.text("management.ragEmbeddingSaved", store.language),
                    savedModel
                )
            } else {
                statusMessage = L10n.text("management.ragEmbeddingDisabled", store.language)
            }
            statusIsError = false
        } catch {
            reportError("management.ragEmbeddingSaveFailed")
        }
    }

    @MainActor
    private func searchRAG() async {
        let query = ragQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearchingRAG = true
        defer { isSearchingRAG = false }
        guard await backendSupervisor.ensureRunning() else {
            reportError("management.ragSearchFailed")
            return
        }
        do {
            ragSearchResult = try await OrchestratorClient.searchKnowledgeRAG(
                query: query,
                includeObsidian: includeObsidianRAG
            )
            statusMessage = nil
            statusIsError = false
        } catch {
            reportError("management.ragSearchFailed")
        }
    }

    @MainActor
    private func reportError(_ key: String) {
        statusMessage = L10n.text(key, store.language)
        statusIsError = true
    }

    @MainActor
    private func syncSubjectModelRouteForm() {
        let route = store.subjectModelRoutes[routeSubject.rawValue]
        routeProvider = route?.provider ?? "auto"
        routeModel = route?.model ?? ""
    }

    @MainActor
    private func syncFinalSynthesisRouteForm() {
        let route = store.finalSynthesisModelRoute
        finalSynthesisProvider = route?.provider ?? "auto"
        finalSynthesisModel = route?.model ?? ""
    }

    @MainActor
    private func syncAutoAgentModelForm() {
        let route = store.autoAgentModelRoutes[autoAgentRole]
        autoAgentProvider = route?.provider ?? "auto"
        autoAgentModel = route?.model ?? ""
    }

    @MainActor
    private func syncAutoCostPolicyForm() {
        allowsPaidAutoRoutes = store.autoCostPolicy?.allowPaidRoutes ?? false
        dailyCloudCallLimit = store.autoCostPolicy?.dailyCloudCallLimit ?? 25
    }

    private func routeMaySendContextToCloud(
        provider: String,
        activeProvider: String?
    ) -> Bool {
        let effectiveProvider = provider == "auto" ? (activeProvider ?? "auto") : provider
        guard effectiveProvider != "ollama" else { return false }
        guard effectiveProvider == "compatible" else { return true }
        guard let host = URLComponents(string: compatibleBaseURL)?.host?.lowercased() else {
            return true
        }
        return !(host == "localhost" || host == "::1" || host.hasPrefix("127."))
    }

    @MainActor
    private func saveSubjectModelRoute() async {
        isSavingRoute = true
        defer { isSavingRoute = false }
        do {
            let model = routeModel.trimmingCharacters(in: .whitespacesAndNewlines)
            try await store.saveSubjectModelRoute(
                subject: routeSubject,
                provider: routeProvider,
                model: routeProvider == "auto" || model.isEmpty ? nil : model
            )
            syncSubjectModelRouteForm()
            statusMessage = L10n.text("management.routeSaved", store.language)
            statusIsError = false
        } catch {
            reportError("management.routeSaveFailed")
        }
    }

    @MainActor
    private func resetSubjectModelRoute() async {
        isSavingRoute = true
        defer { isSavingRoute = false }
        do {
            try await store.resetSubjectModelRoute(subject: routeSubject)
            syncSubjectModelRouteForm()
            statusMessage = L10n.text("management.routeResetDone", store.language)
            statusIsError = false
        } catch {
            reportError("management.routeSaveFailed")
        }
    }

    @MainActor
    private func saveAutoAgentModel() async {
        isSavingRoute = true
        defer { isSavingRoute = false }
        do {
            let model = autoAgentModel.trimmingCharacters(in: .whitespacesAndNewlines)
            try await store.saveAutoAgentModelRoute(
                role: autoAgentRole,
                provider: autoAgentProvider,
                model: autoAgentProvider == "auto" || model.isEmpty ? nil : model
            )
            syncAutoAgentModelForm()
            statusMessage = L10n.text("management.routeSaved", store.language)
            statusIsError = false
        } catch {
            reportError("management.routeSaveFailed")
        }
    }

    @MainActor
    private func resetAutoAgentModel() async {
        isSavingRoute = true
        defer { isSavingRoute = false }
        do {
            try await store.resetAutoAgentModelRoute(role: autoAgentRole)
            syncAutoAgentModelForm()
            statusMessage = L10n.text("management.routeResetDone", store.language)
            statusIsError = false
        } catch {
            reportError("management.routeSaveFailed")
        }
    }

    @MainActor
    private func saveFinalSynthesisRoute() async {
        isSavingRoute = true
        defer { isSavingRoute = false }
        do {
            let model = finalSynthesisModel.trimmingCharacters(in: .whitespacesAndNewlines)
            try await store.saveFinalSynthesisModelRoute(
                provider: finalSynthesisProvider,
                model: finalSynthesisProvider == "auto" || model.isEmpty ? nil : model
            )
            syncFinalSynthesisRouteForm()
            statusMessage = L10n.text("management.routeSaved", store.language)
            statusIsError = false
        } catch {
            reportError("management.routeSaveFailed")
        }
    }

    @MainActor
    private func resetFinalSynthesisRoute() async {
        isSavingRoute = true
        defer { isSavingRoute = false }
        do {
            try await store.resetFinalSynthesisModelRoute()
            syncFinalSynthesisRouteForm()
            statusMessage = L10n.text("management.routeResetDone", store.language)
            statusIsError = false
        } catch {
            reportError("management.routeSaveFailed")
        }
    }

    @MainActor
    private func saveAutoCostPolicy() async {
        isSavingCostPolicy = true
        defer { isSavingCostPolicy = false }
        do {
            try await store.saveAutoCostPolicy(
                allowPaidRoutes: allowsPaidAutoRoutes,
                dailyCloudCallLimit: dailyCloudCallLimit
            )
            await store.refreshAIStatus()
            await store.refreshFinalSynthesisModelRoute()
            statusMessage = L10n.text("management.costPolicySaved", store.language)
            statusIsError = false
        } catch {
            reportError("management.costPolicySaveFailed")
        }
    }

    @MainActor
    private func saveCompatibleSettings() async {
        isSavingCompatibleSettings = true
        defer { isSavingCompatibleSettings = false }
        guard await backendSupervisor.ensureRunning() else {
            reportError("management.compatibleSaveFailed")
            return
        }
        do {
            try await store.saveOpenAICompatibleSettings(
                baseURL: compatibleBaseURL,
                model: compatibleModel
            )
            compatibleBaseURL = store.openAICompatibleSettings?.baseURL ?? ""
            compatibleModel = store.openAICompatibleSettings?.model ?? ""
            await store.refreshProviderSecretStatuses()
            statusMessage = L10n.text("management.compatibleSaved", store.language)
            statusIsError = false
        } catch {
            reportError("management.compatibleSaveFailed")
        }
    }

    private func formatManagementDate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
}

private enum SourceRegistrySheet: Identifiable {
    case preview(TrustedSourcePagePreview)
    case history(String)

    var id: String {
        switch self {
        case .preview(let preview): return "preview:\(preview.id)"
        case .history(let url): return "history:\(url)"
        }
    }
}

private struct SourceRegistryRow: View {
    let source: TrustedSourceInventoryItem
    let language: AppLanguage
    let onReviewSaved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(source.lessonPaths?.joined(separator: " · ") ?? source.lessonPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Label(L10n.text(statusKey, language), systemImage: statusSymbol)
                    .font(.caption)
                    .foregroundStyle(statusTint)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = URL(string: source.url) {
                    Button {
                        Task { await loadPreview() }
                    } label: {
                        if isLoadingPreview {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingPreview)
                    .help(L10n.text("management.sourcePreview", language))
                    .accessibilityLabel(
                        L10n.text(
                            isLoadingPreview ? "management.sourcePreviewLoading" : "management.sourcePreview",
                            language
                        )
                    )

                    Button {
                        activeSheet = .history(source.url)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.plain)
                    .help(L10n.text("management.sourceReviewHistory", language))
                    .accessibilityLabel(L10n.text("management.sourceReviewHistory", language))

                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.plain)
                    .help(source.url)
                    .accessibilityLabel(source.title)
                }
            }
            Text(source.url)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            if let pageTitle = source.pageTitle {
                LabeledContent(L10n.text("management.sourcePageTitle", language), value: pageTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let pageDescription = source.pageDescription {
                Text(pageDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            if source.pagePublishedAt != nil || source.pageUpdatedAt != nil {
                HStack(spacing: 12) {
                    if let pagePublishedAt = source.pagePublishedAt {
                        Text(L10n.text("management.sourcePublisherPublishedAt", language) + ": " + pagePublishedAt)
                    }
                    if let pageUpdatedAt = source.pageUpdatedAt {
                        Text(L10n.text("management.sourcePublisherUpdatedAt", language) + ": " + pageUpdatedAt)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                Text(L10n.text("management.sourcePublisherDateCaveat", language))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let ragContentState = source.ragContentState {
                HStack(spacing: 8) {
                    Label(
                        L10n.text(
                            ragContentState == "cached"
                                ? "management.sourceRAGCached"
                                : ragContentState == "license_approved_pending_check"
                                    ? "management.sourceRAGPending"
                                    : ragContentState == "metadata_only_rights_review"
                                        ? "management.sourceRAGRightsReview"
                                        : "management.sourceRAGMetadataOnly",
                            language
                        ),
                        systemImage: ragContentState == "cached" ? "doc.text.magnifyingglass" : "doc.text"
                    )
                    if let license = source.ragLicense {
                        Text(license)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let licenseURL = source.ragLicenseURL,
                           let destination = URL(string: licenseURL) {
                            Link(destination: destination) {
                                Image(systemName: "arrow.up.right.square")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(licenseURL)
                        }
                    }
                    if ragContentState == "metadata_only_rights_review",
                       let licenseURL = source.ragRestrictionURL,
                       let destination = URL(string: licenseURL) {
                        Link(L10n.text("management.sourceLicenseTerms", language), destination: destination)
                            .buttonStyle(.plain)
                    }
                    if let fetchedAt = source.ragContentFetchedAt {
                        Text("\(L10n.text("management.sourceRAGFetched", language)): \(formatISODate(fetchedAt))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                if ragContentState == "metadata_only_rights_review" {
                    Text(L10n.text("management.sourceOpenStaxRightsHelp", language))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let reviewStatus = source.editorialReviewStatus {
                HStack(spacing: 12) {
                    Label(
                        L10n.text(editorialReviewKey(reviewStatus), language),
                        systemImage: editorialReviewSymbol(reviewStatus)
                    )
                    .foregroundStyle(editorialReviewTint(reviewStatus))
                    if let dueOn = source.editorialReviewDueOn {
                        Text(L10n.text("management.editorialReviewDueOn", language) + ": " + dueOn)
                    }
                    if (source.lessonReviews?.count ?? 1) <= 1,
                       let interval = source.editorialReviewIntervalDays {
                        Text(L10n.text("management.editorialReviewInterval", language) + ": \(interval)")
                    }
                }
                .font(.caption2)
            }

            if let lessonReviews = source.lessonReviews, lessonReviews.count > 1 {
                ForEach(lessonReviews) { review in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(review.lessonPath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Label(
                                L10n.text(editorialReviewKey(review.editorialReviewStatus), language),
                                systemImage: editorialReviewSymbol(review.editorialReviewStatus)
                            )
                            .foregroundStyle(editorialReviewTint(review.editorialReviewStatus))
                        }
                        HStack(spacing: 10) {
                            Text(
                                L10n.text("management.lessonReviewed", language) + ": "
                                    + (review.lessonReviewedOn ?? L10n.text("management.unknownDate", language))
                            )
                            if let dueOn = review.editorialReviewDueOn {
                                Text(L10n.text("management.editorialReviewDueOn", language) + ": " + dueOn)
                            }
                            if let interval = review.editorialReviewIntervalDays {
                                Text(L10n.text("management.editorialReviewInterval", language) + ": \(interval)")
                            }
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .font(.caption2)
                }
            }

            HStack(spacing: 12) {
                if (source.lessonReviews?.count ?? 1) <= 1 {
                    Text(
                        L10n.text("management.lessonReviewed", language) + ": "
                            + (source.lessonReviewedOn ?? L10n.text("management.unknownDate", language))
                    )
                }
                if let lastCheckedAt = source.lastCheckedAt {
                    Text("\(L10n.text("management.sourceChecked", language)): \(formatISODate(lastCheckedAt))")
                }
                if let contentCheckedAt = source.contentCheckedAt {
                    Text("\(L10n.text("management.sourceContentChecked", language)): \(formatISODate(contentCheckedAt))")
                }
                if let lastModified = source.lastModified {
                    Text("\(L10n.text("management.sourceModified", language)): \(lastModified)")
                }
                if let lastHTTPStatus = source.lastHTTPStatus {
                    Text("HTTP \(lastHTTPStatus)")
                }
                if source.hasETag {
                    Text("ETag")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .textSelection(.enabled)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .contain)
        .sheet(item: $activeSheet) { item in
            switch item {
            case .preview(let preview):
                TrustedSourcePreviewSheet(
                    preview: preview,
                    language: language,
                    onReviewSaved: onReviewSaved
                )
            case .history(let url):
                TrustedSourceReviewHistorySheet(url: url, language: language)
            }
        }
        .alert(
            L10n.text("management.sourcePreviewTitle", language),
            isPresented: $showPreviewError
        ) {
            Button(L10n.text("management.sourcePreviewDone", language), role: .cancel) { }
        } message: {
            Text(L10n.text("management.sourcePreviewFailed", language))
        }
    }

    @MainActor
    private func loadPreview() async {
        isLoadingPreview = true
        defer { isLoadingPreview = false }
        do {
            activeSheet = .preview(try await OrchestratorClient.previewTrustedSource(url: source.url))
        } catch {
            showPreviewError = true
        }
    }

    @State private var isLoadingPreview = false
    @State private var activeSheet: SourceRegistrySheet?
    @State private var showPreviewError = false

    private var statusKey: String {
        switch source.state {
        case "not_checked": return "management.sourceNotChecked"
        case "available_untracked": return "management.sourceAvailable"
        case "content_baseline": return "management.sourceContentBaseline"
        case "unchanged": return "management.sourceUnchanged"
        case "changed": return "management.sourceChanged"
        case "content_unavailable": return "management.sourceContentUnavailable"
        case "content_too_large": return "management.sourceContentTooLarge"
        case "unsupported_content_type": return "management.sourceUnsupportedContent"
        case "redirect_review": return "management.sourceRedirect"
        case "unexpected_not_modified": return "management.sourceUnexpected304"
        case "unavailable": return "management.sourceUnavailable"
        case "network_error": return "management.sourceNetworkError"
        default: return "management.sourceUnknown"
        }
    }

    private var statusSymbol: String {
        switch source.state {
        case "changed", "content_baseline", "content_unavailable", "content_too_large",
             "unsupported_content_type", "redirect_review", "unexpected_not_modified",
             "unavailable", "network_error":
            return "exclamationmark.triangle.fill"
        case "unchanged": return "checkmark.circle"
        case "available_untracked": return "questionmark.circle"
        default: return "clock"
        }
    }

    private var statusTint: Color {
        switch source.state {
        case "changed", "content_baseline", "content_unavailable", "content_too_large",
             "unsupported_content_type", "redirect_review", "unexpected_not_modified",
             "unavailable", "network_error": return .orange
        default: return .secondary
        }
    }

    private func editorialReviewKey(_ status: String) -> String {
        switch status {
        case "review_due": return "management.editorialReviewDue"
        case "review_scheduled": return "management.editorialReviewScheduled"
        case "review_missing": return "management.editorialReviewMissing"
        case "review_unscheduled": return "management.editorialReviewUnscheduled"
        default: return "management.editorialReviewUnknown"
        }
    }

    private func editorialReviewSymbol(_ status: String) -> String {
        switch status {
        case "review_due", "review_missing": return "exclamationmark.circle.fill"
        case "review_scheduled": return "calendar"
        case "review_unscheduled": return "calendar.badge.exclamationmark"
        default: return "questionmark.circle"
        }
    }

    private func editorialReviewTint(_ status: String) -> Color {
        switch status {
        case "review_due", "review_missing": return .orange
        default: return .secondary
        }
    }

    private func formatISODate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
}

private struct TrustedSourceReviewHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let url: String
    let language: AppLanguage

    @State private var reviews: [TrustedSourceEditorialReview] = []
    @State private var nextBeforeReviewID: Int?
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if reviews.isEmpty && isLoading {
                    ProgressView(L10n.text("management.sourceReviewHistoryLoading", language))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if reviews.isEmpty && loadFailed {
                    VStack(spacing: 12) {
                        Label(
                            L10n.text("management.sourceReviewHistoryFailed", language),
                            systemImage: "exclamationmark.triangle"
                        )
                        Button(L10n.text("management.retry", language)) {
                            Task { await loadNextPage() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if reviews.isEmpty {
                    VStack(spacing: 12) {
                        Label(
                            L10n.text("management.sourceReviewHistoryEmpty", language),
                            systemImage: "clock"
                        )
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(url)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            ForEach(reviews) { review in
                                GroupBox {
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack {
                                            Label(review.reviewedOn, systemImage: "checkmark.seal")
                                            Spacer()
                                            Text("#\(review.reviewID)")
                                                .foregroundStyle(.tertiary)
                                        }
                                        Text(review.lessonPath)
                                            .font(.caption.monospaced())
                                            .textSelection(.enabled)
                                        Text(
                                            "SHA-256 " + String(review.reviewedDigest.prefix(12)) + "…"
                                        )
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        Text(formatReviewedAt(review.reviewedAt))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else if loadFailed {
                                Label(
                                    L10n.text("management.sourceReviewHistoryFailed", language),
                                    systemImage: "exclamationmark.triangle"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                Button(L10n.text("management.retry", language)) {
                                    Task { await loadNextPage() }
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            } else if hasMore {
                                Button(L10n.text("management.sourceReviewHistoryMore", language)) {
                                    Task { await loadNextPage() }
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(L10n.text("management.sourceReviewHistoryTitle", language))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("management.sourcePreviewDone", language)) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            guard reviews.isEmpty else { return }
            await loadNextPage()
        }
        .frame(minWidth: 540, minHeight: 420)
    }

    @MainActor
    private func loadNextPage() async {
        guard !isLoading else { return }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            let page = try await OrchestratorClient.trustedSourceReviewHistory(
                url: url,
                beforeReviewID: nextBeforeReviewID
            )
            reviews.append(contentsOf: page.reviews)
            hasMore = page.hasMore
            nextBeforeReviewID = page.nextBeforeReviewID
        } catch {
            loadFailed = true
        }
    }

    private func formatReviewedAt(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
}

private struct TrustedSourcePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: TrustedSourcePagePreview
    let language: AppLanguage
    let onReviewSaved: () -> Void
    @State private var selectedLessonPath: String?
    @State private var isSavingReview = false
    @State private var reviewedLessonPaths: Set<String> = []
    @State private var showReviewError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(preview.title)
                        .font(.headline)
                    if let pageTitle = preview.pageTitle, !pageTitle.isEmpty {
                        Text(pageTitle)
                            .font(.title2.weight(.semibold))
                    }
                    if let description = preview.pageDescription, !description.isEmpty {
                        Text(description)
                            .foregroundStyle(.secondary)
                    }
                    if preview.pagePublishedAt != nil || preview.pageUpdatedAt != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            if let publishedAt = preview.pagePublishedAt {
                                Text(L10n.text("management.sourcePublisherPublishedAt", language) + ": " + publishedAt)
                            }
                            if let updatedAt = preview.pageUpdatedAt {
                                Text(L10n.text("management.sourcePublisherUpdatedAt", language) + ": " + updatedAt)
                            }
                            Text(L10n.text("management.sourcePublisherDateCaveat", language))
                                .foregroundStyle(.tertiary)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    }
                    if preview.excerptTruncated {
                        Label(
                            L10n.text("management.sourcePreviewTruncated", language),
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Text(verbatim: preview.excerpt)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            if preview.lessonPaths.count > 1 {
                                Picker(
                                    L10n.text("management.sourceReviewLesson", language),
                                    selection: $selectedLessonPath
                                ) {
                                    ForEach(preview.lessonPaths, id: \.self) { path in
                                        Text(path).tag(Optional(path))
                                    }
                                }
                            } else if let lessonPath = preview.lessonPaths.first {
                                Text(lessonPath)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }

                            Text(L10n.text("management.sourceReviewExplanation", language))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if selectedLessonAlreadyReviewed {
                                Label(
                                    L10n.text("management.sourceReviewSaved", language),
                                    systemImage: "checkmark.circle.fill"
                                )
                                .foregroundStyle(.green)
                            }

                            Button {
                                Task { await recordReview() }
                            } label: {
                                if isSavingReview {
                                    ProgressView().controlSize(.small)
                                    Text(L10n.text("management.sourceReviewSaving", language))
                                } else {
                                    Label(
                                        L10n.text("management.sourceReviewAction", language),
                                        systemImage: "checkmark.seal"
                                    )
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSavingReview || selectedLessonPath == nil || selectedLessonAlreadyReviewed)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    Text(L10n.text("management.sourcePreviewLessons", language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(preview.lessonPaths.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    HStack {
                        Text(L10n.text("management.sourcePreviewFetched", language))
                        Text(preview.fetchedAt).monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    if let url = URL(string: preview.url) {
                        Link(preview.url, destination: url)
                            .font(.caption)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(L10n.text("management.sourcePreviewTitle", language))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("management.sourcePreviewDone", language)) {
                        dismiss()
                    }
                }
            }
            .frame(minWidth: 540, minHeight: 420)
            .task {
                if selectedLessonPath == nil {
                    selectedLessonPath = preview.lessonPaths.first
                }
            }
            .alert(
                L10n.text("management.sourceReviewAction", language),
                isPresented: $showReviewError
            ) {
                Button(L10n.text("management.sourcePreviewDone", language), role: .cancel) { }
            } message: {
                Text(L10n.text("management.sourceReviewFailed", language))
            }
        }
    }

    @MainActor
    private func recordReview() async {
        guard let selectedLessonPath else { return }
        isSavingReview = true
        defer { isSavingReview = false }
        do {
            try await OrchestratorClient.recordTrustedSourceReview(
                url: preview.url,
                lessonPath: selectedLessonPath,
                previewDigest: preview.contentDigest
            )
            reviewedLessonPaths.insert(selectedLessonPath)
            onReviewSaved()
        } catch {
            showReviewError = true
        }
    }

    private var selectedLessonAlreadyReviewed: Bool {
        guard let selectedLessonPath else { return false }
        return reviewedLessonPaths.contains(selectedLessonPath)
    }
}
