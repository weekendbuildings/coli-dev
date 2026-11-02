import SwiftUI

/// One lesson on the AI path, in its course. / Один урок пути ИИ в своём курсе.
struct AIPathLesson: Identifiable, Equatable {
    let subject: Subject
    let resource: String

    var id: String { resource }
    var lessonID: String { "\(subject.rawValue).\(resource)" }
}

struct AIPathStep: Identifiable, Equatable {
    let number: Int
    let lessons: [AIPathLesson]

    var id: Int { number }
    var titleKey: String { "path.step\(number).title" }
    var whyKey: String { "path.step\(number).why" }
}

/// The one route from the first line of Python to a language model the learner trains themselves.
/// See `project-plan/AI_PATH_RU_EN.md`. A lesson appears here before it is written and opens once it is in its curriculum.
/// Единый маршрут от первой строки на Python до своей обученной языковой модели. Урок виден здесь заранее,
/// а открывается, когда появится в карте своего курса.
enum AIPathCatalog {
    private static func math(_ resource: String) -> AIPathLesson { AIPathLesson(subject: .mathematics, resource: resource) }
    private static func code(_ resource: String) -> AIPathLesson { AIPathLesson(subject: .programming, resource: resource) }

    static let steps: [AIPathStep] = [
        AIPathStep(number: 1, lessons: [
            code("variables_and_types"), code("conditions_loops_functions"), code("collections_and_loops"),
            code("strings_files_and_exceptions"), code("python_classes_and_composition")
        ]),
        AIPathStep(number: 2, lessons: [math("vectors_and_matrices")]),
        AIPathStep(number: 3, lessons: [
            math("rates_of_change_and_derivative"), math("gradient_and_partial_derivatives"), code("gradient_descent_and_learning_rate")
        ]),
        AIPathStep(number: 4, lessons: [
            math("descriptive_statistics_and_potential_outliers"), math("probability_and_bayes"), math("random_variables_and_sampling")
        ]),
        AIPathStep(number: 5, lessons: [math("information_and_cross_entropy")]),
        AIPathStep(number: 6, lessons: [code("classification_and_softmax")]),
        AIPathStep(number: 7, lessons: [code("neural_network_backpropagation"), code("neural_network_hidden_layer_xor")]),
        AIPathStep(number: 8, lessons: [code("ml_baseline_and_holdout"), code("minibatches_and_overfitting")]),
        AIPathStep(number: 9, lessons: [code("embeddings_and_similarity")]),
        AIPathStep(number: 10, lessons: [code("attention_mechanism"), code("transformer_block")]),
        AIPathStep(number: 11, lessons: [code("build_your_language_model")]),
        AIPathStep(number: 12, lessons: [code("consciousness_known_and_unknown")])
    ]

    static var lessons: [AIPathLesson] { steps.flatMap(\.lessons) }

    /// The first open lesson that is not finished. / Первый открытый и ещё не пройденный урок.
    static func next(completed: Set<String>, available: Set<String>) -> AIPathLesson? {
        lessons.first { available.contains($0.resource) && !completed.contains($0.lessonID) }
    }
}

/// The whole path on one screen. Every written lesson opens at once, with no waiting for the ones before it.
/// Весь путь на одном экране. Каждый готовый урок открывается сразу, без ожидания предыдущих.
struct AIPathView: View {
    @EnvironmentObject private var store: LearningStore
    let openLesson: (AIPathLesson) -> Void

    /// Lesson names come from the curricula, so a lesson opens here as soon as it is added to its curriculum.
    private let topics: [String: CurriculumTopic] = {
        var found: [String: CurriculumTopic] = [:]
        for subject in [Subject.mathematics, .programming] {
            for level in CurriculumCatalog.roadmap(for: subject) {
                for topic in level.topics {
                    if let resource = topic.lessonResource { found[resource] = topic }
                }
            }
        }
        return found
    }()

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    private var available: [AIPathLesson] { AIPathCatalog.lessons.filter { topics[$0.resource] != nil } }
    private var finished: Int { available.filter { store.isComplete(lessonID: $0.lessonID) }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(text("path.title")).font(.largeTitle.bold())
                Text(text("path.subtitle")).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                summary
                ForEach(AIPathCatalog.steps) { step in
                    stepRow(step)
                }
                finishLine
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("path.screen")
    }

    private var summaryLine: String {
        let missing = AIPathCatalog.lessons.count - available.count
        let total = String(AIPathCatalog.lessons.count)
        if missing == 0 { return String(format: text("path.progressComplete"), String(finished), total) }
        return String(format: text("path.progress"), String(finished), total, String(missing))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressView(value: Double(finished), total: Double(max(AIPathCatalog.lessons.count, 1)))
            HStack {
                Text(summaryLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if let next = AIPathCatalog.next(completed: store.completedLessonIDs, available: Set(available.map(\.resource))) {
                    Button { openLesson(next) } label: { Label(text("path.continue"), systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("path.continue")
                }
            }
        }
        .padding(14)
        .coliContentCard(tint: .accentColor)
    }

    private func stepRow(_ step: AIPathStep) -> some View {
        let done = step.lessons.allSatisfy { store.isComplete(lessonID: $0.lessonID) }
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.green : Color.accentColor.opacity(0.2))
                if done {
                    Image(systemName: "checkmark").font(.callout.bold()).foregroundStyle(.white)
                } else {
                    Text(String(step.number)).font(.callout.bold()).monospacedDigit()
                }
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 8) {
                Text(text(step.titleKey)).font(.title3.weight(.semibold))
                Text(text(step.whyKey)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ForEach(step.lessons) { lesson in
                    lessonRow(lesson)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .coliContentCard(tint: done ? .green : .accentColor)
    }

    @ViewBuilder
    private func lessonRow(_ lesson: AIPathLesson) -> some View {
        if let topic = topics[lesson.resource] {
            let complete = store.isComplete(lessonID: lesson.lessonID)
            Button { openLesson(lesson) } label: {
                HStack(spacing: 8) {
                    Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(complete ? Color.green : Color.secondary)
                    Text(topic.name.value(in: store.language)).multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("path.lesson.\(lesson.resource)")
        } else {
            HStack(spacing: 8) {
                Image(systemName: "hourglass").foregroundStyle(.secondary)
                Text(text("path.lesson.\(lesson.resource)")).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(text("path.soon")).font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("path.planned.\(lesson.resource)")
        }
    }

    private var finishLine: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flag.checkered").font(.title2).frame(width: 34)
            VStack(alignment: .leading, spacing: 6) {
                Text(text("path.finishTitle")).font(.title3.weight(.semibold))
                Text(text("path.finishBody")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .coliContentCard(tint: .orange)
    }
}
