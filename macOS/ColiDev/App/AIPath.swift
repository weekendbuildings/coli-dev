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

/// One of the five big parts of the path. / Один из пяти больших этапов пути.
struct AIPathStage: Identifiable, Equatable {
    let number: Int
    let steps: [AIPathStep]

    var id: Int { number }
    var titleKey: String { "path.stage\(number).title" }
    var whyKey: String { "path.stage\(number).why" }
}

/// The one route from the first run of a real model to a language model the learner trains themselves.
/// See `project-plan/AI_PATH_RU_EN.md`. A lesson appears here before it is written and opens once it is in its curriculum.
/// Единый маршрут от первого запуска настоящей модели до своей обученной языковой модели. Урок виден здесь заранее,
/// а открывается, когда появится в карте своего курса.
enum AIPathCatalog {
    private static func math(_ resource: String) -> AIPathLesson { AIPathLesson(subject: .mathematics, resource: resource) }
    private static func code(_ resource: String) -> AIPathLesson { AIPathLesson(subject: .programming, resource: resource) }

    static let stages: [AIPathStage] = [
        AIPathStage(number: 1, steps: [
            AIPathStep(number: 1, lessons: [
                code("live_model_tokens_temperature"), code("chat_roles_and_context"),
                code("model_mistakes_and_checking"), code("asking_well_and_structured_output")
            ])
        ]),
        AIPathStage(number: 2, steps: [
            AIPathStep(number: 2, lessons: [
                code("variables_and_types"), code("conditions_loops_functions"), code("collections_and_loops"),
                code("strings_files_and_exceptions"), code("python_classes_and_composition")
            ]),
            AIPathStep(number: 3, lessons: [math("vectors_and_matrices")]),
            AIPathStep(number: 4, lessons: [
                math("rates_of_change_and_derivative"), math("gradient_and_partial_derivatives"), code("gradient_descent_and_learning_rate")
            ]),
            AIPathStep(number: 5, lessons: [
                math("descriptive_statistics_and_potential_outliers"), math("probability_and_bayes"), math("random_variables_and_sampling")
            ]),
            AIPathStep(number: 6, lessons: [math("information_and_cross_entropy")]),
            AIPathStep(number: 7, lessons: [code("classification_and_softmax")]),
            AIPathStep(number: 8, lessons: [code("neural_network_backpropagation"), code("neural_network_hidden_layer_xor"), code("autograd_engine")]),
            AIPathStep(number: 9, lessons: [
                code("ml_baseline_and_holdout"), code("minibatches_and_overfitting"), code("training_recipe_and_diagnostics"),
                code("optimizers_momentum_adam"), code("initialization_and_normalization")
            ]),
            AIPathStep(number: 10, lessons: [code("tokenizer_bpe"), code("bigram_language_model"), code("embeddings_and_similarity")]),
            AIPathStep(number: 11, lessons: [code("attention_mechanism"), code("transformer_block")]),
            AIPathStep(number: 12, lessons: [code("build_your_language_model"), code("sampling_and_generation")])
        ]),
        AIPathStage(number: 3, steps: [
            AIPathStep(number: 13, lessons: [code("rl_bandits"), code("rl_mdp_bellman"), code("rl_q_learning"), code("rl_policy_gradient")]),
            AIPathStep(number: 14, lessons: [
                code("finetuning_and_lora"), code("rlhf_from_preferences"), code("reasoning_and_rlvr"), code("constitutional_ai_and_dpo")
            ]),
            AIPathStep(number: 15, lessons: [code("rag_from_scratch"), code("agents_and_tools"), code("evaluation_that_means_something")]),
            AIPathStep(number: 16, lessons: [code("scaling_laws_and_resources"), code("data_for_language_models")]),
            AIPathStep(number: 17, lessons: [code("interp_probes"), code("interp_superposition"), code("interp_sparse_features"), code("interp_circuits")]),
            AIPathStep(number: 18, lessons: [code("safety_what_goes_wrong")])
        ]),
        AIPathStage(number: 4, steps: [
            AIPathStep(number: 19, lessons: [code("agi_what_is_intelligence"), code("agi_measuring_arc")]),
            AIPathStep(number: 20, lessons: [code("agi_world_models"), code("agi_planning_search")]),
            AIPathStep(number: 21, lessons: [code("agi_continual_learning")]),
            AIPathStep(number: 22, lessons: [code("agi_scaling_debate"), code("agi_open_problems")])
        ]),
        AIPathStage(number: 5, steps: [
            AIPathStep(number: 23, lessons: [code("consciousness_known_and_unknown"), code("consciousness_hard_problem")]),
            AIPathStep(number: 24, lessons: [
                code("consciousness_global_workspace"), code("consciousness_integrated_information"), code("consciousness_higher_order_and_prediction")
            ]),
            AIPathStep(number: 25, lessons: [code("consciousness_experiments"), code("consciousness_indicators_checklist"), code("consciousness_language_models")]),
            AIPathStep(number: 26, lessons: [code("consciousness_biology_vs_function"), code("consciousness_moral_status"), code("consciousness_what_you_can_do")])
        ])
    ]

    static var steps: [AIPathStep] { stages.flatMap(\.steps) }
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
                ForEach(AIPathCatalog.stages) { stage in
                    stageHeader(stage)
                    ForEach(stage.steps) { step in
                        stepRow(step)
                    }
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
        .coliContentCard(tint: AppPalette.accent.color)
    }

    private func stageHeader(_ stage: AIPathStage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: String(format: text("path.stageLabel"), String(stage.number)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text(stage.titleKey)).font(.title2.bold())
            Text(text(stage.whyKey)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("path.stage.\(stage.number)")
    }

    private func stepRow(_ step: AIPathStep) -> some View {
        let done = step.lessons.allSatisfy { store.isComplete(lessonID: $0.lessonID) }
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.green : AppPalette.accent.color.opacity(0.2))
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
        .coliContentCard(tint: done ? .green : AppPalette.accent.color)
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
