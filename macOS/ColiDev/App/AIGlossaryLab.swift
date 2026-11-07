import SwiftUI

/// Lab for the AI path glossary: a clickable map of the stages, search, and a "which word is this" quiz.
/// Тренажёр словаря пути ИИ: карта этапов, поиск и игра «какое это слово».
struct AIGlossaryLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var query = ""
    @State private var stage: Int?
    @State private var showAll = false
    @State private var quizOn = false
    @State private var seed: UInt64 = 7
    @State private var questionNumber = 0
    @State private var picked: Int?
    @State private var streak = 0
    @State private var best = 0
    @State private var answered = 0

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private var russian: Bool { store.language == .ru }

    private var entries: [AIGlossaryEntry] {
        guard let markdown = CurriculumCatalog.lessonMarkdown(for: .programming, resource: "ai_path_glossary") else { return [] }
        return AIGlossary.parse(markdown, russian: russian)
    }

    private static let stageColors: [Color] = [.blue, .teal, .purple, .orange, .pink]
    private func color(_ stage: Int) -> Color { Self.stageColors[max(0, min(4, stage - 1))] }

    var body: some View {
        let all = entries
        let found = AIGlossary.filter(all, query: query, stage: stage)
        VStack(alignment: .leading, spacing: 16) {
            LabHeader(title: text("lab.glossary.title"), instruction: text("lab.glossary.subtitle"))
            if all.isEmpty {
                LabStatusBadge(kind: .warning, text: text("lab.glossary.missing"))
            } else {
                stageMap(all)
                TextField(text("lab.glossary.search"), text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("lab.glossary.search")
                LabStatGrid {
                    LabStat(label: text("lab.glossary.found"), value: String(found.count), identifier: "lab.glossary.found")
                    LabStat(label: text("lab.glossary.streak"), value: String(streak), tint: .green, identifier: "lab.glossary.streak")
                    LabStat(label: text("lab.glossary.best"), value: String(best), tint: .orange, identifier: "lab.glossary.best")
                }
                if quizOn {
                    quiz(pool: stage == nil ? all : all.filter { $0.stage == stage })
                } else {
                    list(found)
                }
                Button(quizOn ? text("lab.glossary.backToList") : text("lab.glossary.quiz")) {
                    quizOn.toggle()
                    picked = nil
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("lab.glossary.quizToggle")
                LabChallenge(caption: text("lab.kit.task"), task: text("lab.glossary.challenge"), solved: best >= 5,
                             solvedText: text("lab.glossary.challengeDone"), identifier: "lab.glossary.challenge")
                LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.glossary.howQuiz"), text("lab.glossary.howLimit")])
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .coliSurface(cornerRadius: 18)
        .onChange(of: stage) { _ in resetQuiz() }
    }

    /// Five bars, one per stage; the width is the number of words. Clicking a bar filters by that stage.
    private func stageMap(_ all: [AIGlossaryEntry]) -> some View {
        let counts = AIGlossary.countByStage(all)
        let most = Double(counts.values.max() ?? 1)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(1...5, id: \.self) { number in
                let count = counts[number] ?? 0
                Button {
                    stage = stage == number ? nil : number
                } label: {
                    HStack(spacing: 10) {
                        Text(String(format: text("lab.glossary.stage"), String(number)))
                            .font(.callout.weight(.semibold))
                            .frame(width: 70, alignment: .leading)
                        GeometryReader { proxy in
                            let width: CGFloat = proxy.size.width * CGFloat(Double(count) / most)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(color(number).opacity(stage == nil || stage == number ? 0.85 : 0.25))
                                .frame(width: max(8, width))
                        }
                        .frame(height: 22)
                        Text(String(count))
                            .font(.callout.monospacedDigit())
                            .frame(width: 34, alignment: .trailing)
                        Text(text("path.stage\(number).title"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 130, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("lab.glossary.stage.\(number)")
            }
            Text(stage == nil ? text("lab.glossary.allStages") : text("lab.glossary.oneStage"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func list(_ found: [AIGlossaryEntry]) -> some View {
        let limit = showAll ? found.count : min(found.count, 12)
        return VStack(alignment: .leading, spacing: 10) {
            if found.isEmpty {
                Text(text("lab.glossary.none")).foregroundStyle(.secondary)
            }
            ForEach(found.prefix(limit)) { entry in
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(color(entry.stage)).frame(width: 4)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.term).font(.headline)
                        Text(entry.explanation).fixedSize(horizontal: false, vertical: true)
                        Text(String(format: text("lab.glossary.lesson"), entry.lessonTitle, String(entry.step)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if found.count > limit {
                Button(String(format: text("lab.glossary.showAll"), String(limit), String(found.count))) { showAll = true }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("lab.glossary.showAll")
            }
        }
        .accessibilityIdentifier("lab.glossary.list")
    }

    @ViewBuilder
    private func quiz(pool: [AIGlossaryEntry]) -> some View {
        if let question = AIGlossary.question(number: questionNumber, poolSize: pool.count, seed: seed) {
            let answer = pool[question.answer]
            VStack(alignment: .leading, spacing: 12) {
                Text(text("lab.glossary.quizPrompt")).font(.callout).foregroundStyle(.secondary)
                Text(answer.explanation)
                    .font(.title3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(color(answer.stage).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("lab.glossary.quizExplanation")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { position, option in
                        Button {
                            choose(option, answer: question.answer)
                        } label: {
                            Text(pool[option].term)
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(.bordered)
                        .tint(tint(for: option, answer: question.answer))
                        .disabled(picked != nil)
                        .accessibilityIdentifier("lab.glossary.option.\(position)")
                    }
                }
                if let picked {
                    let right = picked == question.answer
                    LabStatusBadge(kind: right ? .good : .warning,
                                   text: right ? text("lab.glossary.right")
                                       : String(format: text("lab.glossary.wrong"), answer.term, answer.lessonTitle),
                                   identifier: "lab.glossary.verdict")
                    Button(text("lab.glossary.next")) {
                        questionNumber += 1
                        self.picked = nil
                    }
                    .accessibilityIdentifier("lab.glossary.next")
                }
            }
        } else {
            Text(text("lab.glossary.none")).foregroundStyle(.secondary)
        }
    }

    private func tint(for option: Int, answer: Int) -> Color? {
        guard let picked else { return nil }
        if option == answer { return .green }
        return option == picked ? .red : nil
    }

    private func choose(_ option: Int, answer: Int) {
        picked = option
        answered += 1
        if option == answer {
            streak += 1
            best = max(best, streak)
        } else {
            streak = 0
        }
    }

    private func resetQuiz() {
        picked = nil
        streak = 0
        seed &+= 1
        questionNumber = 0
    }
}
