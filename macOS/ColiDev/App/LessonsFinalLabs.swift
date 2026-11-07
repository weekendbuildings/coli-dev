import SwiftUI

// Labs for the importance B and C lessons of the AI path. Models live in LessonsFinalModels.swift.
// Тренажёры уроков важности B и C пути ИИ. Модели лежат в LessonsFinalModels.swift.

/// The same card look as the other labs.
struct LessonsFinalCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .coliSurface(cornerRadius: 18)
    }
}

// MARK: - Pair counter / Счётчик пар

struct BigramLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var letter: Character = "м"
    @State private var temperature = 1.0
    @State private var smoothingIndex = 3
    @State private var seed: UInt64 = 7
    @State private var sample = BigramCounter.generate(temperature: 1.0)
    @State private var sawInfinity = false
    @State private var sawBest = false

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int = 3) -> String {
        value.isInfinite ? "∞" : L10n.number(value, fractionDigits: digits, store.language)
    }
    private func shown(_ c: Character) -> String { c == " " ? "␣" : String(c) }
    private var alpha: Double { BigramCounter.smoothingSteps[smoothingIndex] }

    var body: some View {
        let testLoss = BigramCounter.loss(BigramCounter.test, alpha: alpha)
        let trainLoss = BigramCounter.loss(BigramCounter.train, alpha: alpha)
        LessonsFinalCard {
            LabHeader(title: text("lab.bigram.title"), instruction: text("lab.bigram.subtitle"))
            letterButtons
            probabilityChart
                .frame(height: 220)
                .accessibilityLabel(text("lab.bigram.chartSpoken"))
            HStack {
                Text(String(format: text("lab.bigram.temperature"), number(temperature, 1)))
                    .frame(width: 170, alignment: .leading)
                Slider(value: $temperature, in: 0.2...3, step: 0.1)
                    .accessibilityIdentifier("lab.bigram.temperature")
            }
            HStack(alignment: .top, spacing: 12) {
                Button(text("lab.bigram.write")) {
                    seed &+= 1
                    sample = BigramCounter.generate(temperature: temperature, seed: seed)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("lab.bigram.write")
                Text(sample)
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("lab.bigram.sample")
            }
            lossChart
                .frame(height: 200)
                .accessibilityLabel(text("lab.bigram.lossSpoken"))
            HStack {
                Text(String(format: text("lab.bigram.alpha"), number(alpha, 3)))
                    .frame(width: 170, alignment: .leading)
                Slider(value: Binding(get: { Double(smoothingIndex) }, set: { smoothingIndex = Int($0.rounded()) }),
                       in: 0...Double(BigramCounter.smoothingSteps.count - 1), step: 1)
                    .accessibilityIdentifier("lab.bigram.alphaSlider")
            }
            LabStatGrid {
                LabStat(label: text("lab.bigram.statTrain"), value: number(trainLoss), tint: .blue, identifier: "lab.bigram.train")
                LabStat(label: text("lab.bigram.statTest"), value: number(testLoss), tint: testLoss.isInfinite ? .red : .green, identifier: "lab.bigram.test")
                LabStat(label: text("lab.bigram.statRandom"), value: number(BigramCounter.randomGuess), tint: .gray, identifier: "lab.bigram.random")
            }
            LabStatusBadge(kind: testLoss.isInfinite ? .bad : (smoothingIndex == BigramCounter.bestSmoothingIndex ? .good : .info),
                           text: testLoss.isInfinite ? text("lab.bigram.infinite")
                               : (smoothingIndex == BigramCounter.bestSmoothingIndex ? text("lab.bigram.best") : text("lab.bigram.notBest")),
                           identifier: "lab.bigram.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.bigram.challenge"), solved: sawInfinity && sawBest,
                         solvedText: text("lab.bigram.challengeDone"), identifier: "lab.bigram.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.bigram.howCount"), text("lab.bigram.howSmooth"), text("lab.bigram.howNot")])
        }
        .onChange(of: smoothingIndex) { value in
            if BigramCounter.loss(BigramCounter.test, alpha: BigramCounter.smoothingSteps[value]).isInfinite { sawInfinity = true }
            if value == BigramCounter.bestSmoothingIndex { sawBest = true }
        }
    }

    private var letterButtons: some View {
        HStack(spacing: 6) {
            ForEach(Array(BigramCounter.commonLetters.prefix(12)), id: \.self) { c in
                Button(shown(c)) { letter = c }
                    .buttonStyle(.bordered)
                    .tint(c == letter ? AppPalette.accent.color : .secondary)
                    .accessibilityIdentifier("lab.bigram.letter.\(shown(c))")
            }
        }
    }

    /// Bars: probability of each next letter after the chosen one, at the current temperature.
    private var probabilityChart: some View {
        let dist = Array(BigramCounter.probabilities(after: letter, temperature: temperature).prefix(10))
        return Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: 0...Double(max(dist.count, 1)), y: 0...1)
            plot.drawAxes(in: context, xLabel: String(format: text("lab.bigram.xAxis"), shown(letter)), yLabel: text("lab.bigram.yAxis"),
                          xTicks: [], yTicks: [0, 0.25, 0.5, 0.75, 1], format: { L10n.number($0, fractionDigits: 2, store.language) })
            for (index, item) in dist.enumerated() {
                let left: CGPoint = plot.point(Double(index) + 0.15, item.1)
                let right: CGPoint = plot.point(Double(index) + 0.85, 0)
                let rect = CGRect(x: left.x, y: left.y, width: right.x - left.x, height: right.y - left.y)
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(index == 0 ? AppPalette.accent.color : Color.teal))
                let label: CGPoint = plot.point(Double(index) + 0.5, 0)
                context.draw(Text(shown(item.0)).font(.headline).foregroundColor(.primary), at: CGPoint(x: label.x, y: label.y + 12))
                let top: CGPoint = plot.point(Double(index) + 0.5, item.1)
                context.draw(Text(L10n.number(item.1, fractionDigits: 2, store.language)).font(.caption2).foregroundColor(.secondary),
                             at: CGPoint(x: top.x, y: top.y - 8))
            }
        }
    }

    /// Test error against the smoothing step; infinity is drawn at the top in red.
    private var lossChart: some View {
        let steps = BigramCounter.smoothingSteps
        let losses = steps.map { BigramCounter.loss(BigramCounter.test, alpha: $0) }
        return Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: 0...Double(steps.count - 1), y: 1...3.5)
            plot.drawAxes(in: context, xLabel: text("lab.bigram.alphaAxis"), yLabel: text("lab.bigram.lossAxis"),
                          xTicks: [], yTicks: [1, 1.5, 2, 2.5, 3, 3.5],
                          format: { L10n.number($0, fractionDigits: 1, store.language) })
            for (index, step) in steps.enumerated() {
                let base: CGPoint = plot.point(Double(index), 1)
                context.draw(Text(L10n.number(step, fractionDigits: step < 0.01 && step > 0 ? 3 : (step < 1 ? 2 : 0), store.language))
                    .font(.caption2).foregroundColor(.secondary), at: CGPoint(x: base.x, y: base.y + 12))
            }
            var line = Path()
            for (index, value) in losses.enumerated() where !value.isInfinite {
                let point: CGPoint = plot.point(Double(index), value)
                if line.isEmpty { line.move(to: point) } else { line.addLine(to: point) }
            }
            context.stroke(line, with: .color(.green), lineWidth: 2.5)
            let random: CGPoint = plot.point(0, BigramCounter.randomGuess)
            let randomEnd: CGPoint = plot.point(Double(steps.count - 1), BigramCounter.randomGuess)
            var guess = Path()
            guess.move(to: random)
            guess.addLine(to: randomEnd)
            context.stroke(guess, with: .color(.gray), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            for (index, value) in losses.enumerated() {
                let shownValue = value.isInfinite ? 3.5 : value
                let point: CGPoint = plot.point(Double(index), shownValue)
                let radius: CGFloat = index == smoothingIndex ? 8 : 4
                let dot = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: dot), with: .color(value.isInfinite ? .red : (index == smoothingIndex ? AppPalette.accent.color : .green)))
                if value.isInfinite {
                    context.draw(Text("∞").font(.headline).foregroundColor(.red), at: CGPoint(x: point.x + 14, y: point.y + 2))
                }
            }
        }
    }
}

// MARK: - Choosing the next token / Выбор следующего токена

struct SamplingLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var k = 20.0
    @State private var p = 0.9
    @State private var hits = [Int](repeating: 0, count: 20)
    @State private var seed: UInt64 = 1
    @State private var sawOnlyParis = false
    @State private var sawBigNucleus = false

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int = 2) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private var kept: Int? { RealTop20.kept(k: Int(k), p: p) }

    var body: some View {
        let probabilities = RealTop20.probabilities
        let keptCount = kept ?? 20
        let keptMass = probabilities.prefix(keptCount).reduce(0, +)
        LessonsFinalCard {
            LabHeader(title: text("lab.sampling.title"), instruction: text("lab.sampling.subtitle"))
            chart(probabilities, keptCount: keptCount)
                .frame(height: 260)
                .accessibilityLabel(text("lab.sampling.chartSpoken"))
            HStack {
                Text(String(format: text("lab.sampling.k"), String(Int(k)))).frame(width: 130, alignment: .leading)
                Slider(value: $k, in: 1...20, step: 1).accessibilityIdentifier("lab.sampling.k")
            }
            HStack {
                Text(String(format: text("lab.sampling.p"), number(p))).frame(width: 130, alignment: .leading)
                Slider(value: $p, in: 0.3...0.99, step: 0.01).accessibilityIdentifier("lab.sampling.p")
            }
            Button(text("lab.sampling.pick")) {
                seed &+= 1
                hits = RealTop20.pick(kept: keptCount, count: 50, seed: seed)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("lab.sampling.pick")
            LabStatGrid {
                LabStat(label: text("lab.sampling.statKept"), value: kept.map(String.init) ?? "> 20", identifier: "lab.sampling.kept")
                LabStat(label: text("lab.sampling.statMass"), value: number(keptMass), tint: .teal, identifier: "lab.sampling.mass")
                LabStat(label: text("lab.sampling.statParis"), value: number(probabilities[0] / keptMass), tint: .green, identifier: "lab.sampling.paris")
            }
            LabStatusBadge(kind: kept == nil ? .warning : .info,
                           text: kept == nil ? text("lab.sampling.tooLong") : text("lab.sampling.junk"),
                           identifier: "lab.sampling.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.sampling.challenge"), solved: sawOnlyParis && sawBigNucleus,
                         solvedText: text("lab.sampling.challengeDone"), identifier: "lab.sampling.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.sampling.howRules"), text("lab.sampling.howData")])
        }
        .onChange(of: k) { _ in note() }
        .onChange(of: p) { _ in note() }
    }

    private func note() {
        hits = [Int](repeating: 0, count: 20)
        if kept == 1 { sawOnlyParis = true }
        if let kept, kept > 10 { sawBigNucleus = true }
    }

    private func chart(_ probabilities: [Double], keptCount: Int) -> some View {
        Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: 0...20, y: 0...0.7, bottom: 64)
            plot.drawAxes(in: context, xLabel: "", yLabel: text("lab.sampling.yAxis"), xTicks: [], yTicks: [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7],
                          format: { L10n.number($0, fractionDigits: 1, store.language) })
            for (index, q) in probabilities.enumerated() {
                let topLeft: CGPoint = plot.point(Double(index) + 0.12, q)
                let bottomRight: CGPoint = plot.point(Double(index) + 0.88, 0)
                let rect = CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
                let isKept = index < keptCount
                context.fill(Path(roundedRect: rect, cornerRadius: 3),
                             with: .color(isKept ? (index == 0 ? AppPalette.accent.color : Color.teal) : Color.gray.opacity(0.3)))
                if hits[index] > 0 {
                    let mark: CGPoint = plot.point(Double(index) + 0.5, q)
                    context.draw(Text("×\(hits[index])").font(.caption2.bold()).foregroundColor(.orange), at: CGPoint(x: mark.x, y: mark.y - 9))
                }
                let base: CGPoint = plot.point(Double(index) + 0.5, 0)
                var label = context.resolve(Text(RealTop20.shown(index)).font(.caption2).foregroundColor(isKept ? .primary : .secondary))
                label.shading = .color(isKept ? .primary : .secondary)
                context.drawLayer { layer in
                    layer.translateBy(x: base.x, y: base.y + 6)
                    layer.rotate(by: .degrees(60))
                    layer.draw(label, at: .zero, anchor: .leading)
                }
            }
        }
    }
}

// MARK: - Rules as the judge and DPO / Правила как судья и DPO

struct DPOLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var steps = 0
    @State private var beta = 1.0
    @State private var truthRule = false
    @State private var running = false
    @State private var sawSplit = false
    @State private var sawTruth = false

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int = 2) -> String { L10n.number(value, fractionDigits: digits, store.language) }

    var body: some View {
        let pi = DPOToy.probabilities(DPOToy.train(beta: beta, steps: steps, truthRule: truthRule))
        let wrong = (pi[0][3] + pi[1][3]) / 2
        let kl = (DPOToy.kl(pi[0]) + DPOToy.kl(pi[1])) / 2
        LessonsFinalCard {
            LabHeader(title: text("lab.dpo.title"), instruction: text("lab.dpo.subtitle"))
            ForEach(0..<2, id: \.self) { p in
                VStack(alignment: .leading, spacing: 6) {
                    Text(DPOToy.prompts[p].0).font(.headline)
                    ForEach(0..<4, id: \.self) { a in answerBar(prompt: p, answer: a, probability: pi[p][a]) }
                }
            }
            Picker(text("lab.dpo.beta"), selection: $beta) {
                Text("β = 0,1").tag(0.1)
                Text("β = 1").tag(1.0)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.dpo.beta")
            Toggle(text("lab.dpo.truthRule"), isOn: $truthRule)
                .accessibilityIdentifier("lab.dpo.truthRule")
            HStack {
                Button(text("lab.dpo.step")) { steps = min(300, steps + 10) }
                    .accessibilityIdentifier("lab.dpo.step")
                Button(running ? text("lab.dpo.pause") : text("lab.dpo.run")) { running.toggle() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lab.dpo.run")
                Button(text("lab.dpo.reset")) { running = false; steps = 0 }
                    .accessibilityIdentifier("lab.dpo.reset")
            }
            LabStatGrid {
                LabStat(label: text("lab.dpo.statSteps"), value: String(steps), identifier: "lab.dpo.steps")
                LabStat(label: text("lab.dpo.statWrong"), value: number(wrong), tint: wrong > 0.3 ? .red : .green, identifier: "lab.dpo.wrong")
                LabStat(label: text("lab.dpo.statKL"), value: number(kl), tint: .purple, identifier: "lab.dpo.kl")
            }
            LabStatusBadge(kind: truthRule ? .good : (wrong > 0.3 ? .warning : .info),
                           text: truthRule ? text("lab.dpo.withTruth") : text("lab.dpo.withoutTruth"), identifier: "lab.dpo.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.dpo.challenge"), solved: sawSplit && sawTruth,
                         solvedText: text("lab.dpo.challengeDone"), identifier: "lab.dpo.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.dpo.howLoss"), text("lab.dpo.howJudge")])
        }
        .onChange(of: truthRule) { _ in steps = 0 }
        .onChange(of: beta) { _ in steps = 0 }
        .onChange(of: steps) { _ in
            let now = DPOToy.probabilities(DPOToy.train(beta: beta, steps: steps, truthRule: truthRule))
            if !truthRule, steps >= 300, now[0][3] > 0.45 { sawSplit = true }
            if truthRule, steps >= 300, now[0][3] < 0.05, now[1][3] < 0.05 { sawTruth = true }
        }
        .task(id: running) {
            while running && steps < 300 {
                try? await Task.sleep(nanoseconds: 60_000_000)
                steps = min(300, steps + 5)
            }
            running = false
        }
    }

    private func answerBar(prompt: Int, answer: Int, probability: Double) -> some View {
        let broken = DPOToy.breaks(prompt: prompt, answer: answer, truthRule: truthRule)
        let right = DPOToy.correct[prompt][answer]
        return HStack(spacing: 8) {
            Text(DPOToy.prompts[prompt].1[answer])
                .font(.caption)
                .lineLimit(1)
                .frame(width: 260, alignment: .leading)
            GeometryReader { proxy in
                let width: CGFloat = proxy.size.width * CGFloat(probability)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4).fill(right ? Color.green : Color.red.opacity(0.8)).frame(width: max(2, width))
                }
            }
            .frame(height: 16)
            Text(number(probability)).font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
            Text(broken.isEmpty ? "✓" : String(broken.count)).font(.caption.bold())
                .foregroundStyle(broken.isEmpty ? Color.green : Color.orange).frame(width: 18)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lab.dpo.bar.\(prompt).\(answer)")
    }
}
