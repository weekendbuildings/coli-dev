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

/// A number like 3,2 · 10¹⁰ for very large and very small values.
func lessonsFinalScientific(_ value: Double, _ language: AppLanguage) -> String {
    guard value > 0, value.isFinite else { return "—" }
    let exponent = Int(floor(log10(value)))
    let mantissa = value / pow(10.0, Double(exponent))
    let superscripts: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"]
    let power = String(String(exponent).map { superscripts[$0] ?? $0 })
    return L10n.number(mantissa, fractionDigits: 1, language) + " · 10" + power
}

// MARK: - Scaling laws / Законы масштабирования

struct ComputeBudgetLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var logCompute = 21.0
    @State private var logSize = 12.0
    @State private var solvedBudgets: Set<Double> = []

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func sci(_ value: Double) -> String { lessonsFinalScientific(value, store.language) }

    var body: some View {
        let compute = pow(10.0, logCompute)
        let n = pow(10.0, logSize)
        let d = compute / (6.0 * n)
        let best = ScalingLaw.best(compute: compute)
        let close = abs(logSize - log10(best.n)) <= 0.1
        LessonsFinalCard {
            LabHeader(title: text("lab.scaling.title"), instruction: text("lab.scaling.subtitle"))
            chart(compute: compute, best: best)
                .frame(height: 240)
                .accessibilityLabel(text("lab.scaling.chartSpoken"))
            HStack {
                Text(String(format: text("lab.scaling.compute"), sci(compute))).frame(width: 200, alignment: .leading)
                Slider(value: $logCompute, in: 18...26, step: 0.5).accessibilityIdentifier("lab.scaling.compute")
            }
            HStack {
                Text(String(format: text("lab.scaling.size"), sci(n))).frame(width: 200, alignment: .leading)
                Slider(value: $logSize, in: 6...13, step: 0.05).accessibilityIdentifier("lab.scaling.size")
            }
            LabStatGrid {
                LabStat(label: text("lab.scaling.statError"), value: L10n.number(ScalingLaw.loss(n: n, d: d), fractionDigits: 3, store.language), tint: close ? .green : .orange, identifier: "lab.scaling.error")
                LabStat(label: text("lab.scaling.statTokens"), value: sci(d), identifier: "lab.scaling.tokens")
                LabStat(label: text("lab.scaling.statRatio"), value: L10n.number(d / n, fractionDigits: d / n < 10 ? 2 : 0, store.language), tint: .teal, identifier: "lab.scaling.ratio")
                LabStat(label: text("lab.scaling.statPython"), value: sci(ScalingLaw.years(compute: compute, speed: ScalingLaw.mySpeed)), tint: .red, identifier: "lab.scaling.python")
                LabStat(label: text("lab.scaling.statGPU"), value: sci(ScalingLaw.years(compute: compute, speed: ScalingLaw.gpuPeak)), tint: .purple, identifier: "lab.scaling.gpu")
            }
            LabStatusBadge(kind: close ? .good : .info,
                           text: close ? text("lab.scaling.atBottom") : String(format: text("lab.scaling.notBottom"), sci(best.n)),
                           identifier: "lab.scaling.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.scaling.challenge"), solved: solvedBudgets.count >= 2,
                         solvedText: text("lab.scaling.challengeDone"), identifier: "lab.scaling.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.scaling.howFormula"), text("lab.scaling.howNot")])
        }
        .onChange(of: logSize) { _ in note() }
        .onChange(of: logCompute) { _ in note() }
    }

    private func note() {
        let best = ScalingLaw.best(compute: pow(10.0, logCompute))
        if abs(logSize - log10(best.n)) <= 0.1 { solvedBudgets.insert(logCompute) }
    }

    /// Error against model size at a fixed budget; drag across the chart to move the model size.
    private func chart(compute: Double, best: (n: Double, d: Double, loss: Double)) -> some View {
        GeometryReader { proxy in
            let plot = LabPlotGeometry(size: proxy.size, x: 6...13, y: 1.5...6)
            Canvas { context, _ in
                plot.drawAxes(in: context, xLabel: text("lab.scaling.xAxis"), yLabel: text("lab.scaling.yAxis"),
                              xTicks: [6, 7, 8, 9, 10, 11, 12, 13], yTicks: [2, 3, 4, 5, 6],
                              format: { L10n.number($0, fractionDigits: 0, store.language) })
                var curve = Path()
                for step in 0...140 {
                    let logN = 6.0 + Double(step) * 0.05
                    let size = pow(10.0, logN)
                    let value = min(6.0, ScalingLaw.loss(n: size, d: compute / (6.0 * size)))
                    let point: CGPoint = plot.point(logN, value)
                    if step == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
                }
                context.stroke(curve, with: .color(.teal), lineWidth: 2.5)
                let bottom: CGPoint = plot.point(log10(best.n), min(6.0, best.loss))
                context.fill(Path(ellipseIn: CGRect(x: bottom.x - 5, y: bottom.y - 5, width: 10, height: 10)), with: .color(.green))
                let size = pow(10.0, logSize)
                let current: CGPoint = plot.point(logSize, min(6.0, ScalingLaw.loss(n: size, d: compute / (6.0 * size))))
                context.fill(Path(ellipseIn: CGRect(x: current.x - 9, y: current.y - 9, width: 18, height: 18)), with: .color(AppPalette.accent.color))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let logN = plot.value(at: value.location).x
                logSize = min(13, max(6, (logN * 20).rounded() / 20))
            })
        }
    }
}

// MARK: - Cleaning data / Очистка данных

struct DedupLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var threshold = 0.95

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let removed = DedupToy.nearCopies(threshold: threshold)
        let solved = removed == [9: 0, 5: 1]
        LessonsFinalCard {
            LabHeader(title: text("lab.dedup.title"), instruction: text("lab.dedup.subtitle"))
            heatmap
                .frame(height: 300)
                .accessibilityLabel(text("lab.dedup.chartSpoken"))
            HStack {
                Text(String(format: text("lab.dedup.threshold"), L10n.number(threshold, fractionDigits: 2, store.language))).frame(width: 150, alignment: .leading)
                Slider(value: $threshold, in: 0.1...0.95, step: 0.05).accessibilityIdentifier("lab.dedup.threshold")
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(DedupToy.docs.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Text("[\(index)]").font(.caption.monospacedDigit()).frame(width: 30, alignment: .leading)
                        Text(DedupToy.docs[index]).font(.caption).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(status(index, removed: removed)).font(.caption.bold()).foregroundStyle(color(index, removed: removed))
                    }
                }
            }
            LabStatGrid {
                LabStat(label: text("lab.dedup.statKept"), value: String(DedupToy.unique.count - removed.count), tint: .green, identifier: "lab.dedup.kept")
                LabStat(label: text("lab.dedup.statNear"), value: String(removed.count), tint: .orange, identifier: "lab.dedup.near")
            }
            LabStatusBadge(kind: solved ? .good : (removed[11] != nil ? .bad : .info),
                           text: solved ? text("lab.dedup.right") : (removed[11] != nil ? text("lab.dedup.tooLow") : text("lab.dedup.tooHigh")),
                           identifier: "lab.dedup.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.dedup.challenge"), solved: solved,
                         solvedText: text("lab.dedup.challengeDone"), identifier: "lab.dedup.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.dedup.howSteps"), text("lab.dedup.howJaccard")])
        }
    }

    private func status(_ index: Int, removed: [Int: Int]) -> String {
        if let reason = DedupToy.quality(DedupToy.docs[index]) {
            switch reason {
            case .tooShort: return text("lab.dedup.short")
            case .noFullStop: return text("lab.dedup.noStop")
            case .repeats: return text("lab.dedup.repeats")
            }
        }
        if let original = DedupToy.exactCopies[index] { return String(format: text("lab.dedup.exact"), String(original)) }
        if let original = removed[index] { return String(format: text("lab.dedup.nearOf"), String(original)) }
        return text("lab.dedup.kept")
    }

    private func color(_ index: Int, removed: [Int: Int]) -> Color {
        if DedupToy.quality(DedupToy.docs[index]) != nil || DedupToy.exactCopies[index] != nil { return .secondary }
        return removed[index] != nil ? .orange : .green
    }

    /// Jaccard similarity of every pair of texts left after steps 1 and 2; cells at or above the threshold are outlined.
    private var heatmap: some View {
        let list = DedupToy.unique
        return Canvas { context, size in
            let margin: CGFloat = 34
            let side: CGFloat = min(size.width, size.height) - margin
            let cell: CGFloat = side / CGFloat(list.count)
            for (row, a) in list.enumerated() {
                let rowLabel = CGPoint(x: margin / 2, y: margin + cell * (CGFloat(row) + 0.5))
                context.draw(Text("[\(a)]").font(.caption2).foregroundColor(.secondary), at: rowLabel)
                let columnLabel = CGPoint(x: margin + cell * (CGFloat(row) + 0.5), y: margin / 2)
                context.draw(Text("[\(a)]").font(.caption2).foregroundColor(.secondary), at: columnLabel)
                for (column, b) in list.enumerated() {
                    let value = a == b ? 1.0 : DedupToy.jaccard(a, b)
                    let rect = CGRect(x: margin + cell * CGFloat(column), y: margin + cell * CGFloat(row), width: cell - 2, height: cell - 2)
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(a == b ? Color.gray.opacity(0.25) : LabHeatScale.color(value)))
                    if a != b {
                        context.draw(Text(L10n.number(value, fractionDigits: 2, store.language)).font(.caption2).foregroundColor(.primary),
                                     at: CGPoint(x: rect.midX, y: rect.midY))
                        if value >= threshold {
                            context.stroke(Path(roundedRect: rect, cornerRadius: 3), with: .color(.orange), lineWidth: 3)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sparse features / Разреженные признаки

struct SparseFeatureLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var penaltyIndex = 0
    @State private var results: [Int: SparseAutoencoder.Result] = [:]

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int = 2) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private static let colors: [Color] = [.blue, .orange, .green, .purple, .pink]

    var body: some View {
        let result = results[penaltyIndex]
        let solved = result.map { $0.found == 5 && abs($0.activePerPoint - 0.5) < 0.1 } ?? false
        LessonsFinalCard {
            LabHeader(title: text("lab.sparse.title"), instruction: text("lab.sparse.subtitle"))
            plane(result)
                .frame(height: 320)
                .accessibilityLabel(text("lab.sparse.chartSpoken"))
            Picker(text("lab.sparse.penalty"), selection: $penaltyIndex) {
                ForEach(SparseAutoencoder.penalties.indices, id: \.self) { index in
                    Text(penaltyLabel(index)).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.sparse.penalty")
            if let result {
                LabStatGrid {
                    LabStat(label: text("lab.sparse.statFound"), value: "\(result.found) / 5", tint: result.found == 5 ? .green : .orange, identifier: "lab.sparse.found")
                    LabStat(label: text("lab.sparse.statActive"), value: number(result.activePerPoint), tint: .teal, identifier: "lab.sparse.active")
                    LabStat(label: text("lab.sparse.statError"), value: number(result.error, 4), tint: .blue, identifier: "lab.sparse.error")
                    LabStat(label: text("lab.sparse.statDead"), value: String(result.dead), tint: result.dead > 0 ? .red : .gray, identifier: "lab.sparse.dead")
                }
                LabStatusBadge(kind: solved ? .good : .info, text: verdict(result), identifier: "lab.sparse.status")
            } else {
                ProgressView()
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.sparse.challenge"), solved: solved,
                         solvedText: text("lab.sparse.challengeDone"), identifier: "lab.sparse.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.sparse.howModel"), text("lab.sparse.howNot")])
        }
        .task(id: penaltyIndex) {
            if results[penaltyIndex] == nil {
                let lambda = SparseAutoencoder.penalties[penaltyIndex]
                results[penaltyIndex] = SparseAutoencoder.train(lambda: lambda)
            }
        }
    }

    private func penaltyLabel(_ index: Int) -> String {
        let value: Double = SparseAutoencoder.penalties[index]
        let digits: Int = (value > 0 && value < 0.1) ? 2 : 1
        return "λ = \(L10n.number(value, fractionDigits: digits, store.language))"
    }

    private func verdict(_ result: SparseAutoencoder.Result) -> String {
        if result.dead == 5 { return text("lab.sparse.allDead") }
        if result.activePerPoint > 1 { return text("lab.sparse.dense") }
        if result.found < 5 { return text("lab.sparse.missing") }
        if result.activePerPoint < 0.4 { return text("lab.sparse.shrunk") }
        return text("lab.sparse.right")
    }

    private func plane(_ result: SparseAutoencoder.Result?) -> some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let frame = CGSize(width: side, height: side)
            let plot = LabPlotGeometry(size: frame, x: -1.3...1.3, y: -1.3...1.3)
            plot.drawAxes(in: context, xLabel: "x₁", yLabel: "x₂", xTicks: [-1, 0, 1], yTicks: [-1, 0, 1],
                          format: { L10n.number($0, fractionDigits: 0, store.language) })
            for point in SparseAutoencoder.data.prefix(900) where point.0 != 0 || point.1 != 0 {
                let p: CGPoint = plot.point(point.0, point.1)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)), with: .color(Color.secondary.opacity(0.5)))
            }
            let origin: CGPoint = plot.point(0, 0)
            for direction in SparseAutoencoder.features {
                var line = Path()
                line.move(to: origin)
                line.addLine(to: plot.point(direction.0 * 1.25, direction.1 * 1.25))
                context.stroke(line, with: .color(.gray), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            guard let result else { return }
            for (index, d) in result.decoder.enumerated() {
                let tip: CGPoint = plot.point(d.0 * 1.1, d.1 * 1.1)
                var arrow = Path()
                arrow.move(to: origin)
                arrow.addLine(to: tip)
                let color: Color = result.alive[index] ? Self.colors[index] : Color.gray.opacity(0.4)
                context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: result.alive[index] ? 3.5 : 2, dash: result.alive[index] ? [] : [3, 3]))
                context.fill(Path(ellipseIn: CGRect(x: tip.x - 5, y: tip.y - 5, width: 10, height: 10)), with: .color(color))
            }
        }
    }
}

// MARK: - Circuits / Цепи

struct NetworkCircuitLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var on: Set<Int> = Set(0..<6)
    @State private var patchedNeuron: Int?

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int = 3) -> String { L10n.number(value, fractionDigits: digits, store.language) }

    var body: some View {
        let correct = TinyCircuit.accuracy(keep: on)
        let solved = on.count == 2 && correct == 8
        LessonsFinalCard {
            LabHeader(title: text("lab.netcircuit.title"), instruction: text("lab.netcircuit.subtitle"))
            HStack(alignment: .top, spacing: 16) {
                diagram
                    .frame(width: 340, height: 280)
                    .accessibilityLabel(text("lab.netcircuit.chartSpoken"))
                answers
            }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { j in
                    Button(String(format: text("lab.netcircuit.neuron"), String(j))) {
                        if on.contains(j) { on.remove(j) } else { on.insert(j) }
                    }
                    .buttonStyle(.bordered)
                    .tint(on.contains(j) ? AppPalette.accent.color : .gray)
                    .accessibilityIdentifier("lab.netcircuit.toggle.\(j)")
                }
                Button(text("lab.netcircuit.allOn")) { on = Set(0..<6) }
                    .accessibilityIdentifier("lab.netcircuit.allOn")
            }
            LabStatGrid {
                LabStat(label: text("lab.netcircuit.statOn"), value: String(on.count), tint: .teal, identifier: "lab.netcircuit.on")
                LabStat(label: text("lab.netcircuit.statRight"), value: "\(correct) / 8", tint: correct == 8 ? .green : .red, identifier: "lab.netcircuit.right")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(text("lab.netcircuit.patchTitle")).font(.headline)
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { j in
                        Button(String(j)) { patchedNeuron = j }
                            .buttonStyle(.bordered)
                            .tint(patchedNeuron == j ? .orange : .secondary)
                            .accessibilityIdentifier("lab.netcircuit.patch.\(j)")
                    }
                }
                if let patchedNeuron {
                    Text(String(format: text("lab.netcircuit.patchResult"), String(patchedNeuron), number(TinyCircuit.patched(patchedNeuron))))
                        .font(.callout)
                        .accessibilityIdentifier("lab.netcircuit.patchResult")
                }
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.netcircuit.challenge"), solved: solved,
                         solvedText: text("lab.netcircuit.challengeDone"), identifier: "lab.netcircuit.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.netcircuit.howOff"), text("lab.netcircuit.howPatch")])
        }
    }

    private var answers: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text("lab.netcircuit.answers")).font(.caption.bold())
            ForEach(TinyCircuit.inputs.indices, id: \.self) { index in
                let x = TinyCircuit.inputs[index]
                let y = TinyCircuit.output(x, keep: on)
                let right = (y > 0.5) == TinyCircuit.target(x)
                HStack(spacing: 6) {
                    Text("\(Int(x[0])) \(Int(x[1])) \(Int(x[2]))").font(.caption.monospaced())
                    Text("→ " + number(y, 2)).font(.caption.monospacedDigit())
                    Text(right ? "✓" : "✗").font(.caption.bold()).foregroundStyle(right ? Color.green : Color.red)
                }
            }
        }
    }

    /// Inputs, six hidden neurons and the output; line width shows a weight's size, colour its sign.
    private var diagram: some View {
        Canvas { context, size in
            let inputY: [CGFloat] = [0.25, 0.5, 0.75].map { size.height * $0 }
            let hiddenY: [CGFloat] = (0..<6).map { size.height * (CGFloat($0) + 0.5) / 6 }
            let left = CGFloat(30), middle = size.width / 2, right = size.width - 30
            for j in 0..<6 {
                let active = on.contains(j)
                for i in 0..<3 {
                    var edge = Path()
                    edge.move(to: CGPoint(x: left, y: inputY[i]))
                    edge.addLine(to: CGPoint(x: middle, y: hiddenY[j]))
                    let w = TinyCircuit.w1[j][i]
                    let width: CGFloat = CGFloat(min(6.0, abs(w) * 0.6))
                    context.stroke(edge, with: .color((w > 0 ? Color.blue : Color.red).opacity(active ? 0.7 : 0.12)), lineWidth: width)
                }
                var out = Path()
                out.move(to: CGPoint(x: middle, y: hiddenY[j]))
                out.addLine(to: CGPoint(x: right, y: size.height / 2))
                let w = TinyCircuit.w2[j]
                let width: CGFloat = CGFloat(min(7.0, abs(w) * 0.45))
                context.stroke(out, with: .color((w > 0 ? Color.blue : Color.red).opacity(active ? 0.7 : 0.12)), lineWidth: width)
            }
            for (i, label) in ["a", "b", "c"].enumerated() {
                let rect = CGRect(x: left - 14, y: inputY[i] - 14, width: 28, height: 28)
                context.fill(Path(ellipseIn: rect), with: .color(.teal))
                context.draw(Text(label).font(.headline).foregroundColor(.white), at: CGPoint(x: rect.midX, y: rect.midY))
            }
            for j in 0..<6 {
                let rect = CGRect(x: middle - 16, y: hiddenY[j] - 16, width: 32, height: 32)
                context.fill(Path(ellipseIn: rect), with: .color(on.contains(j) ? AppPalette.accent.color : Color.gray.opacity(0.4)))
                context.draw(Text(String(j)).font(.headline).foregroundColor(.white), at: CGPoint(x: rect.midX, y: rect.midY))
            }
            let rect = CGRect(x: right - 16, y: size.height / 2 - 16, width: 32, height: 32)
            context.fill(Path(ellipseIn: rect), with: .color(.green))
            context.draw(Text("y").font(.headline).foregroundColor(.white), at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }
}

// MARK: - Tree search / Поиск по дереву

struct TreeSearchLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var optionIndex = 1
    @State private var pile = 21
    @State private var cache: [Int: [Int: Bool]] = [:]

    private static let options = [5, 10, 20, 50, 100, 200, 500, 1000]
    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private var simulations: Int { Self.options[optionIndex] }

    private func results(_ index: Int) -> [Int: Bool] { cache[index] ?? StickGame.results(simulations: Self.options[index]) }
    private func allRight(_ index: Int) -> Bool { results(index).values.allSatisfy { $0 } }

    var body: some View {
        let current = results(optionIndex)
        let right = current.values.filter { $0 }.count
        let solved = allRight(optionIndex) && (optionIndex == 0 || !allRight(optionIndex - 1))
        let search = StickGame.mcts(pile, simulations: simulations, seed: UInt64(pile))
        LessonsFinalCard {
            LabHeader(title: text("lab.tree.title"), instruction: text("lab.tree.subtitle"))
            strip(current)
            HStack {
                Text(String(format: text("lab.tree.simulations"), String(simulations))).frame(width: 170, alignment: .leading)
                Slider(value: Binding(get: { Double(optionIndex) }, set: { optionIndex = Int($0.rounded()) }),
                       in: 0...Double(Self.options.count - 1), step: 1)
                    .accessibilityIdentifier("lab.tree.simulations")
            }
            HStack(alignment: .top, spacing: 18) {
                sticks
                visitBars(search)
                    .frame(width: 240, height: 160)
                    .accessibilityLabel(text("lab.tree.barsSpoken"))
            }
            LabStatGrid {
                LabStat(label: text("lab.tree.statRight"), value: "\(right) / \(current.count)", tint: right == current.count ? .green : .orange, identifier: "lab.tree.right")
                LabStat(label: text("lab.tree.statMove"), value: String(search.move), tint: StickGame.perfectMoves(pile).contains(search.move) ? .green : .red, identifier: "lab.tree.move")
                LabStat(label: text("lab.tree.statPerfect"), value: StickGame.perfectMoves(pile).isEmpty ? "—" : StickGame.perfectMoves(pile).map(String.init).joined(separator: ", "), identifier: "lab.tree.perfect")
            }
            LabStatusBadge(kind: StickGame.win[pile] ? .info : .warning,
                           text: StickGame.win[pile] ? text("lab.tree.winning") : text("lab.tree.losing"), identifier: "lab.tree.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.tree.challenge"), solved: solved,
                         solvedText: text("lab.tree.challengeDone"), identifier: "lab.tree.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.tree.howSearch"), text("lab.tree.howNot")])
        }
        .task(id: optionIndex) {
            if cache[optionIndex] == nil { cache[optionIndex] = StickGame.results(simulations: simulations) }
            if optionIndex > 0, cache[optionIndex - 1] == nil { cache[optionIndex - 1] = StickGame.results(simulations: Self.options[optionIndex - 1]) }
        }
    }

    /// Piles 5 to 21: green right move, red wrong move, grey a losing pile. Click a pile to look inside.
    private func strip(_ current: [Int: Bool]) -> some View {
        HStack(spacing: 4) {
            ForEach(5...21, id: \.self) { n in
                let color: Color = current[n].map { $0 ? Color.green : Color.red } ?? Color.gray.opacity(0.35)
                Button { pile = n } label: {
                    Text(String(n))
                        .font(.caption.bold().monospacedDigit())
                        .frame(width: 26, height: 30)
                        .background(color.opacity(n == pile ? 1 : 0.65), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(n == pile ? Color.primary : Color.clear, lineWidth: 2))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("lab.tree.pile.\(n)")
            }
        }
    }

    private var sticks: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: text("lab.tree.pile"), String(pile))).font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(8), spacing: 4), count: 11), spacing: 6) {
                ForEach(0..<pile, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2).fill(Color.orange).frame(width: 6, height: 34)
                }
            }
        }
        .frame(width: 150, alignment: .leading)
    }

    private func visitBars(_ search: (move: Int, visits: [Int: Int])) -> some View {
        let most = Double(max(1, search.visits.values.max() ?? 1))
        return Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: 0.5...3.5, y: 0...most)
            plot.drawAxes(in: context, xLabel: text("lab.tree.xAxis"), yLabel: text("lab.tree.yAxis"), xTicks: [1, 2, 3], yTicks: [0, most],
                          format: { L10n.number($0, fractionDigits: 0, store.language) })
            for take in 1...3 {
                guard let count = search.visits[take] else { continue }
                let top: CGPoint = plot.point(Double(take) - 0.3, Double(count))
                let bottom: CGPoint = plot.point(Double(take) + 0.3, 0)
                let rect = CGRect(x: top.x, y: top.y, width: bottom.x - top.x, height: bottom.y - top.y)
                let perfect = StickGame.perfectMoves(pile).contains(take)
                context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(take == search.move ? AppPalette.accent.color : Color.teal.opacity(0.6)))
                if perfect {
                    context.draw(Text("★").font(.headline).foregroundColor(.green), at: CGPoint(x: rect.midX, y: rect.minY - 10))
                }
            }
        }
    }
}

// MARK: - Beyond the training range / За пределами виденного

struct AdditionRangeLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var rangeIndex = 0
    @State private var trained: [Int: AdditionNet.Trained] = [:]

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int = 3) -> String { L10n.number(value, fractionDigits: digits, store.language) }

    var body: some View {
        let high = AdditionNet.trainingRanges[rangeIndex]
        let net = trained[rangeIndex]
        let corner = net.map { $0.predict((2, 2)) }
        let cornerError = corner.map { ($0 - 4) * ($0 - 4) }
        let solved = (cornerError ?? 1) < 0.1
        LessonsFinalCard {
            LabHeader(title: text("lab.ood.title"), instruction: text("lab.ood.subtitle"))
            chart(net: net, high: high)
                .frame(height: 260)
                .accessibilityLabel(text("lab.ood.chartSpoken"))
            Picker(text("lab.ood.range"), selection: $rangeIndex) {
                ForEach(AdditionNet.trainingRanges.indices, id: \.self) { index in
                    Text("0 … " + L10n.number(AdditionNet.trainingRanges[index], fractionDigits: 1, store.language)).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.ood.range")
            if let net, let corner, let cornerError {
                LabStatGrid {
                    LabStat(label: text("lab.ood.statInside"), value: number(net.error(net.near), 5), tint: .green, identifier: "lab.ood.inside")
                    LabStat(label: text("lab.ood.statCorner"), value: number(corner, 2), tint: .orange, identifier: "lab.ood.corner")
                    LabStat(label: text("lab.ood.statCornerError"), value: number(cornerError), tint: solved ? .green : .red, identifier: "lab.ood.cornerError")
                }
            } else {
                ProgressView()
            }
            LabStatusBadge(kind: solved ? .good : .warning, text: solved ? text("lab.ood.covered") : text("lab.ood.beyond"), identifier: "lab.ood.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.ood.challenge"), solved: solved,
                         solvedText: text("lab.ood.challengeDone"), identifier: "lab.ood.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.ood.howNet"), text("lab.ood.howNot")])
        }
        .task(id: rangeIndex) {
            if trained[rangeIndex] == nil { trained[rangeIndex] = AdditionNet.train(high: AdditionNet.trainingRanges[rangeIndex]) }
        }
    }

    /// Along the diagonal x₁ = x₂ = t: the right answer 2t, the network's answer, and the training range in grey.
    private func chart(net: AdditionNet.Trained?, high: Double) -> some View {
        Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: 0...2.6, y: 0...5.2)
            let left: CGPoint = plot.point(0, 5.2)
            let right: CGPoint = plot.point(high, 0)
            context.fill(Path(CGRect(x: left.x, y: left.y, width: right.x - left.x, height: right.y - left.y)), with: .color(Color.gray.opacity(0.15)))
            plot.drawAxes(in: context, xLabel: text("lab.ood.xAxis"), yLabel: text("lab.ood.yAxis"), xTicks: [0, 0.5, 1, 1.5, 2, 2.5], yTicks: [0, 1, 2, 3, 4, 5],
                          format: { L10n.number($0, fractionDigits: $0 == $0.rounded() ? 0 : 1, store.language) })
            var truth = Path()
            truth.move(to: plot.point(0, 0))
            truth.addLine(to: plot.point(2.6, 5.2))
            context.stroke(truth, with: .color(.green), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            guard let net else { return }
            var curve = Path()
            for step in 0...52 {
                let t = Double(step) * 0.05
                let point: CGPoint = plot.point(t, min(5.2, max(0, net.predict((t, t)))))
                if step == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
            }
            context.stroke(curve, with: .color(AppPalette.accent.color), lineWidth: 3)
            let corner: CGPoint = plot.point(2, min(5.2, net.predict((2, 2))))
            context.fill(Path(ellipseIn: CGRect(x: corner.x - 6, y: corner.y - 6, width: 12, height: 12)), with: .color(.orange))
        }
    }
}

// MARK: - Replacing neurons / Замена нейронов

struct NeuronReplacementLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var chips = 0.0
    @State private var answer: Int?

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let count = Int(chips)
        let difference = ReplacementBrain.largestDifference(chips: count)
        LessonsFinalCard {
            LabHeader(title: text("lab.replace.title"), instruction: text("lab.replace.subtitle"))
            HStack(alignment: .center, spacing: 20) {
                brain(count).frame(width: 230, height: 110)
                trace(count).frame(height: 160).accessibilityLabel(text("lab.replace.chartSpoken"))
            }
            HStack {
                Text(String(format: text("lab.replace.count"), String(count))).frame(width: 170, alignment: .leading)
                Slider(value: $chips, in: 0...10, step: 1).accessibilityIdentifier("lab.replace.count")
            }
            LabStatGrid {
                LabStat(label: text("lab.replace.statChips"), value: "\(count) / 10", tint: .gray, identifier: "lab.replace.chips")
                LabStat(label: text("lab.replace.statDifference"), value: lessonsFinalScientific(difference, store.language), tint: .green, identifier: "lab.replace.difference")
            }
            Text(text("lab.replace.question")).font(.headline)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Button(text("lab.replace.answer\(index)")) { answer = index }
                        .buttonStyle(.bordered)
                        .tint(answer == index ? AppPalette.accent.color : .secondary)
                        .disabled(count < 10)
                        .accessibilityIdentifier("lab.replace.answer.\(index)")
                }
            }
            if let answer {
                Text(text("lab.replace.camp\(answer)"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("lab.replace.camp")
            }
            LabStatusBadge(kind: .info, text: text("lab.replace.limit"), identifier: "lab.replace.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.replace.challenge"), solved: count == 10 && answer != nil,
                         solvedText: text("lab.replace.challengeDone"), identifier: "lab.replace.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.replace.howNet"), text("lab.replace.howNot")])
        }
    }

    private func brain(_ count: Int) -> some View {
        Canvas { context, size in
            let cell = size.width / 5
            for j in 0..<10 {
                let center = CGPoint(x: cell * (CGFloat(j % 5) + 0.5), y: size.height * (j < 5 ? 0.28 : 0.72))
                let rect = CGRect(x: center.x - 17, y: center.y - 17, width: 34, height: 34)
                if j < count {
                    context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color.gray))
                } else {
                    context.fill(Path(ellipseIn: rect), with: .color(Color.pink.opacity(0.8)))
                }
                context.draw(Text(String(j)).font(.caption.bold()).foregroundColor(.white), at: center)
            }
        }
        .accessibilityLabel(text("lab.replace.brainSpoken"))
    }

    private func trace(_ count: Int) -> some View {
        let original = ReplacementBrain.run(chips: 0)
        let replaced = ReplacementBrain.run(chips: count)
        return Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: 1...12, y: 0...1)
            plot.drawAxes(in: context, xLabel: text("lab.replace.xAxis"), yLabel: text("lab.replace.yAxis"), xTicks: [1, 4, 8, 12], yTicks: [0, 0.5, 1],
                          format: { L10n.number($0, fractionDigits: $0 == $0.rounded() ? 0 : 1, store.language) })
            for (values, color, width) in [(original, Color.pink, CGFloat(6)), (replaced, Color.gray, CGFloat(2.5))] {
                var line = Path()
                for (index, value) in values.enumerated() {
                    let point: CGPoint = plot.point(Double(index + 1), value)
                    if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
                }
                context.stroke(line, with: .color(color.opacity(0.85)), lineWidth: width)
            }
        }
    }
}

// MARK: - Preregistration / Предрегистрация

struct PreregistrationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var cut = 0.9
    @State private var minimum = 0.2
    @State private var written = false
    @State private var copies = 1
    @State private var sawAboveZero = false

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int = 2) -> String { L10n.number(value, fractionDigits: digits, store.language) }

    var body: some View {
        let gap = Preregistration.gap(Preregistration.data, cut: cut)
        let ci = written ? Preregistration.interval(cut: cut, copies: copies) : nil
        let confirmed = (gap ?? 0) >= minimum && (ci?.low ?? -1) > 0
        LessonsFinalCard {
            LabHeader(title: text("lab.prereg.title"), instruction: text("lab.prereg.subtitle"))
            HStack {
                Text(String(format: text("lab.prereg.cut"), number(cut))).frame(width: 220, alignment: .leading)
                Slider(value: $cut, in: 0.5...0.95, step: 0.05).disabled(written).accessibilityIdentifier("lab.prereg.cut")
            }
            HStack {
                Text(String(format: text("lab.prereg.minimum"), number(minimum))).frame(width: 220, alignment: .leading)
                Slider(value: $minimum, in: 0.05...0.5, step: 0.05).disabled(written).accessibilityIdentifier("lab.prereg.minimum")
            }
            HStack {
                Button(text("lab.prereg.write")) { written = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(written)
                    .accessibilityIdentifier("lab.prereg.write")
                Button(text("lab.prereg.again")) { written = false; copies = 1 }
                    .disabled(!written)
                    .accessibilityIdentifier("lab.prereg.again")
            }
            if written, let ci {
                interval(gap: gap, ci: ci)
                    .frame(height: 90)
                    .accessibilityLabel(text("lab.prereg.chartSpoken"))
                Picker(text("lab.prereg.copies"), selection: $copies) {
                    ForEach([1, 2, 4, 8], id: \.self) { value in Text(String(value * 20)).tag(value) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("lab.prereg.copies")
                LabStatGrid {
                    LabStat(label: text("lab.prereg.statGap"), value: gap.map { number($0) } ?? "—", tint: .teal, identifier: "lab.prereg.gap")
                    LabStat(label: text("lab.prereg.statInterval"), value: number(ci.low) + " … " + number(ci.high), tint: ci.low > 0 ? .green : .orange, identifier: "lab.prereg.interval")
                }
                LabStatusBadge(kind: confirmed ? .good : .warning,
                               text: confirmed ? text("lab.prereg.confirmed") : text("lab.prereg.notConfirmed"), identifier: "lab.prereg.status")
                if copies > 1 {
                    Text(text("lab.prereg.copiesNote")).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                LabStatusBadge(kind: .info, text: text("lab.prereg.hidden"), identifier: "lab.prereg.status")
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.prereg.challenge"), solved: sawAboveZero,
                         solvedText: text("lab.prereg.challengeDone"), identifier: "lab.prereg.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.prereg.howBootstrap"), text("lab.prereg.howNot")])
        }
        .onChange(of: copies) { value in
            if written, Preregistration.interval(cut: cut, copies: value).low > 0 { sawAboveZero = true }
        }
    }

    private func interval(gap: Double?, ci: (low: Double, high: Double)) -> some View {
        Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: -0.4...1, y: 0...1)
            plot.drawAxes(in: context, xLabel: text("lab.prereg.xAxis"), yLabel: "", xTicks: [-0.4, 0, 0.2, 0.5, 1], yTicks: [],
                          format: { L10n.number($0, fractionDigits: 1, store.language) })
            let zeroTop: CGPoint = plot.point(0, 1)
            let zeroBottom: CGPoint = plot.point(0, 0)
            var zero = Path()
            zero.move(to: zeroTop)
            zero.addLine(to: zeroBottom)
            context.stroke(zero, with: .color(.red), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            let left: CGPoint = plot.point(max(-0.4, ci.low), 0.5)
            let right: CGPoint = plot.point(min(1, ci.high), 0.5)
            var bar = Path()
            bar.move(to: left)
            bar.addLine(to: right)
            context.stroke(bar, with: .color(ci.low > 0 ? .green : .orange), lineWidth: 8)
            if let gap {
                let dot: CGPoint = plot.point(gap, 0.5)
                context.fill(Path(ellipseIn: CGRect(x: dot.x - 7, y: dot.y - 7, width: 14, height: 14)), with: .color(AppPalette.accent.color))
            }
            let threshold: CGPoint = plot.point(minimum, 0.9)
            context.draw(Text("▼").font(.caption).foregroundColor(.purple), at: threshold)
        }
    }
}

// MARK: - SVD of a 2 × 2 matrix / SVD матрицы 2 × 2

struct SVDEllipseLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var a = 0.8
    @State private var b = -0.6
    @State private var c = 0.6
    @State private var d = 0.8

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int = 2) -> String { L10n.number(value, fractionDigits: digits, store.language) }

    var body: some View {
        let svd = SVD2.decompose(a, b, c, d)
        let share = svd.s1 > 0 ? svd.s2 / svd.s1 : 1
        let solved = svd.s1 > 0.5 && share < 0.05
        LessonsFinalCard {
            LabHeader(title: text("lab.svd.title"), instruction: text("lab.svd.subtitle"))
            plane(svd).frame(height: 280).accessibilityLabel(text("lab.svd.chartSpoken"))
            ForEach(Array(zip(["a", "b", "c", "d"], [$a, $b, $c, $d])), id: \.0) { name, value in
                HStack {
                    Text("\(name) = " + number(value.wrappedValue, 1)).font(.callout.monospacedDigit()).frame(width: 80, alignment: .leading)
                    Slider(value: value, in: -2...2, step: 0.1).accessibilityIdentifier("lab.svd.\(name)")
                }
            }
            LabStatGrid {
                LabStat(label: "σ₁", value: number(svd.s1), tint: .blue, identifier: "lab.svd.s1")
                LabStat(label: "σ₂", value: number(svd.s2), tint: .orange, identifier: "lab.svd.s2")
                LabStat(label: text("lab.svd.statShare"), value: number(share * 100, 1) + " %", tint: solved ? .green : .gray, identifier: "lab.svd.share")
            }
            LabStatusBadge(kind: solved ? .good : .info, text: solved ? text("lab.svd.rankOne") : text("lab.svd.fullRank"), identifier: "lab.svd.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.svd.challenge"), solved: solved,
                         solvedText: text("lab.svd.challengeDone"), identifier: "lab.svd.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.svd.howSVD"), text("lab.svd.howLoRA")])
        }
    }

    private func plane(_ svd: (s1: Double, s2: Double, v1: (Double, Double), v2: (Double, Double))) -> some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let plot = LabPlotGeometry(size: CGSize(width: side, height: side), x: -4...4, y: -4...4)
            plot.drawAxes(in: context, xLabel: "x₁", yLabel: "x₂", xTicks: [-4, -2, 0, 2, 4], yTicks: [-4, -2, 0, 2, 4],
                          format: { L10n.number($0, fractionDigits: 0, store.language) })
            var circle = Path()
            var ellipse = Path()
            for step in 0...72 {
                let t = Double(step) / 72 * 2 * Double.pi
                let p = (cos(t), sin(t))
                let q = (a * p.0 + b * p.1, c * p.0 + d * p.1)
                let pc: CGPoint = plot.point(p.0, p.1)
                let qc: CGPoint = plot.point(q.0, q.1)
                if step == 0 { circle.move(to: pc); ellipse.move(to: qc) } else { circle.addLine(to: pc); ellipse.addLine(to: qc) }
            }
            context.stroke(circle, with: .color(.gray), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            context.stroke(ellipse, with: .color(.teal), lineWidth: 3)
            let origin: CGPoint = plot.point(0, 0)
            for (vector, color) in [(svd.v1, Color.blue), (svd.v2, Color.orange)] {
                let image = (a * vector.0 + b * vector.1, c * vector.0 + d * vector.1)
                var arrow = Path()
                arrow.move(to: origin)
                arrow.addLine(to: plot.point(image.0, image.1))
                context.stroke(arrow, with: .color(color), lineWidth: 4)
            }
        }
    }
}

// MARK: - Jacobian of a map / Якобиан отображения

struct JacobianLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var point = (1.0, 1.0)

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int = 2) -> String { L10n.number(value, fractionDigits: digits, store.language) }

    var body: some View {
        let det = JacobianMap.determinant(point)
        let j = JacobianMap.jacobian(point)
        let solved = abs(det) < 0.05
        LessonsFinalCard {
            LabHeader(title: text("lab.jacobian.title"), instruction: text("lab.jacobian.subtitle"))
            HStack(spacing: 14) {
                inputPlane.frame(height: 250).accessibilityLabel(text("lab.jacobian.inputSpoken"))
                outputPlane.frame(height: 250).accessibilityLabel(text("lab.jacobian.outputSpoken"))
            }
            LabStatGrid {
                LabStat(label: text("lab.jacobian.statPoint"), value: "(\(number(point.0)); \(number(point.1)))", identifier: "lab.jacobian.point")
                LabStat(label: "J", value: matrixText(j), tint: .blue, identifier: "lab.jacobian.matrix")
                LabStat(label: text("lab.jacobian.statDet"), value: number(det), tint: solved ? .green : .orange, identifier: "lab.jacobian.det")
            }
            LabStatusBadge(kind: solved ? .good : .info, text: solved ? text("lab.jacobian.flat") : text("lab.jacobian.area"), identifier: "lab.jacobian.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.jacobian.challenge"), solved: solved,
                         solvedText: text("lab.jacobian.challengeDone"), identifier: "lab.jacobian.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.jacobian.howJ"), text("lab.jacobian.howBack")])
        }
    }

    private func matrixText(_ j: [[Double]]) -> String {
        let top: String = "[\(number(j[0][0])), \(number(j[0][1]))]"
        let bottom: String = "[\(number(j[1][0])), \(number(j[1][1]))]"
        return "[\(top), \(bottom)]"
    }

    private var inputPlane: some View {
        GeometryReader { proxy in
            let plot = LabPlotGeometry(size: proxy.size, x: -2...2, y: -3...2)
            Canvas { context, _ in
                plot.drawAxes(in: context, xLabel: "x₁", yLabel: "x₂", xTicks: [-2, -1, 0, 1, 2], yTicks: [-3, -2, -1, 0, 1, 2],
                              format: { L10n.number($0, fractionDigits: 0, store.language) })
                var curve = Path()
                for step in 0...80 {
                    let x = -2.0 + Double(step) * 0.05
                    let p: CGPoint = plot.point(x, -2 * x * x)
                    if step == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
                }
                context.stroke(curve, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                let s = 0.15
                let corner: CGPoint = plot.point(point.0 - s, point.1 + s)
                let far: CGPoint = plot.point(point.0 + s, point.1 - s)
                context.stroke(Path(CGRect(x: corner.x, y: corner.y, width: far.x - corner.x, height: far.y - corner.y)), with: .color(.teal), lineWidth: 2)
                let center: CGPoint = plot.point(point.0, point.1)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)), with: .color(AppPalette.accent.color))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let v = plot.value(at: value.location)
                point = (min(2, max(-2, (v.x * 20).rounded() / 20)), min(2, max(-3, (v.y * 20).rounded() / 20)))
            })
        }
    }

    /// The image of the small square under f (teal, curved) and under the Jacobian (blue parallelogram).
    private var outputPlane: some View {
        Canvas { context, size in
            let center = JacobianMap.f(point)
            let plot = LabPlotGeometry(size: size, x: (center.0 - 1)...(center.0 + 1), y: (center.1 - 1)...(center.1 + 1))
            plot.drawAxes(in: context, xLabel: "y₁", yLabel: "y₂", xTicks: [], yTicks: [], format: { L10n.number($0, fractionDigits: 1, store.language) })
            let s = 0.15
            let corners = [(-s, s), (s, s), (s, -s), (-s, -s), (-s, s)]
            var curved = Path()
            for (index, offset) in corners.dropLast().enumerated() {
                let next = corners[index + 1]
                for k in 0...10 {
                    let t = Double(k) / 10
                    let x = (point.0 + offset.0 + (next.0 - offset.0) * t, point.1 + offset.1 + (next.1 - offset.1) * t)
                    let y = JacobianMap.f(x)
                    let p: CGPoint = plot.point(y.0, y.1)
                    if index == 0 && k == 0 { curved.move(to: p) } else { curved.addLine(to: p) }
                }
            }
            context.stroke(curved, with: .color(.teal), lineWidth: 2.5)
            let j = JacobianMap.jacobian(point)
            var linear = Path()
            for (index, offset) in corners.enumerated() {
                let y = (center.0 + j[0][0] * offset.0 + j[0][1] * offset.1, center.1 + j[1][0] * offset.0 + j[1][1] * offset.1)
                let p: CGPoint = plot.point(y.0, y.1)
                if index == 0 { linear.move(to: p) } else { linear.addLine(to: p) }
            }
            context.stroke(linear, with: .color(.blue), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
        }
    }
}

// MARK: - Hodgkin–Huxley neuron / Нейрон Ходжкина — Хаксли

struct HodgkinHuxleyLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var current = 2.0
    @State private var method: Int?

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int = 1) -> String { L10n.number(value, fractionDigits: digits, store.language) }

    var body: some View {
        let result = HodgkinHuxley.simulate(current: current)
        let previous = HodgkinHuxley.simulate(current: max(0, current - 0.5)).spikes
        let solved = result.spikes >= 3 && previous < 3
        LessonsFinalCard {
            LabHeader(title: text("lab.hh.title"), instruction: text("lab.hh.subtitle"))
            voltage(result.trace).frame(height: 220).accessibilityLabel(text("lab.hh.chartSpoken"))
            HStack {
                Text(String(format: text("lab.hh.current"), number(current))).frame(width: 190, alignment: .leading)
                Slider(value: $current, in: 0...20, step: 0.5).accessibilityIdentifier("lab.hh.current")
            }
            LabStatGrid {
                LabStat(label: text("lab.hh.statSpikes"), value: String(result.spikes), tint: result.spikes >= 3 ? .green : .orange, identifier: "lab.hh.spikes")
                LabStat(label: text("lab.hh.statPeak"), value: number(result.trace.max() ?? 0) + " mV", tint: .red, identifier: "lab.hh.peak")
            }
            LabStatusBadge(kind: solved ? .good : .info,
                           text: result.spikes == 0 ? text("lab.hh.silent") : (result.spikes < 3 ? text("lab.hh.once") : text("lab.hh.firing")),
                           identifier: "lab.hh.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.hh.challenge"), solved: solved,
                         solvedText: text("lab.hh.challengeDone"), identifier: "lab.hh.challenge")
            Text(text("lab.hh.mapTitle")).font(.headline)
            methodMap.frame(height: 200).accessibilityLabel(text("lab.hh.mapSpoken"))
            if let method {
                Text(text("lab.hh.method." + HodgkinHuxley.methods[method].key))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("lab.hh.methodText")
            }
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.hh.howModel"), text("lab.hh.howNot")])
        }
    }

    private func voltage(_ trace: [Double]) -> some View {
        Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: 0...50, y: -90...60)
            plot.drawAxes(in: context, xLabel: text("lab.hh.xAxis"), yLabel: text("lab.hh.yAxis"), xTicks: [0, 10, 20, 30, 40, 50], yTicks: [-80, -40, 0, 40],
                          format: { L10n.number($0, fractionDigits: 0, store.language) })
            var line = Path()
            for index in stride(from: 0, to: trace.count, by: 10) {
                let p: CGPoint = plot.point(Double(index) * 0.01, min(60, max(-90, trace[index])))
                if index == 0 { line.move(to: p) } else { line.addLine(to: p) }
            }
            context.stroke(line, with: .color(AppPalette.accent.color), lineWidth: 2)
            let on: CGPoint = plot.point(5, 60)
            let onBottom: CGPoint = plot.point(5, -90)
            var mark = Path()
            mark.move(to: on)
            mark.addLine(to: onBottom)
            context.stroke(mark, with: .color(.gray), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }

    /// «10⁻³» for −3: written step by step, because the CI compiler times out on one long expression.
    private static func powerOfTen(_ exponent: Double) -> String {
        let digits: [Character: String] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
        let whole: Int = Int(abs(exponent).rounded())
        var result: String = exponent < 0 ? "10⁻" : "10"
        for character in String(whole) {
            result += digits[character] ?? String(character)
        }
        return result
    }

    /// Time resolution against space resolution, both on a log scale; click a method to read about it.
    private var methodMap: some View {
        GeometryReader { proxy in
            let plot = LabPlotGeometry(size: proxy.size, x: -4.5...1, y: -5.5...(-1.5))
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    plot.drawAxes(in: context, xLabel: text("lab.hh.mapX"), yLabel: text("lab.hh.mapY"), xTicks: [-4, -3, -2, -1, 0, 1], yTicks: [-5, -4, -3, -2],
                                  format: { Self.powerOfTen($0) })
                }
                ForEach(HodgkinHuxley.methods.indices, id: \.self) { index in
                    let m = HodgkinHuxley.methods[index]
                    let p: CGPoint = plot.point(log10(m.time), log10(m.space))
                    Button { method = index } label: {
                        Text(text("lab.hh.short." + m.key))
                            .font(.caption.bold())
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background((method == index ? AppPalette.accent.color : Color.teal).opacity(0.85), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .position(x: p.x, y: p.y)
                    .accessibilityIdentifier("lab.hh.map." + m.key)
                }
            }
        }
    }
}

/// Loops against NumPy: where the time of a matrix product goes, the call or the arithmetic.
/// Циклы против NumPy: куда уходит время произведения матриц, на вызов или на счёт.
struct LoopsMatricesLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var sizeIndex = 1.0
    @State private var solved = false

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    private var size: Int { LoopsMatrices.sliderSizes[Int(sizeIndex)] }

    private func duration(_ seconds: Double) -> String {
        if seconds < 1e-3 {
            return L10n.number(seconds * 1e6, fractionDigits: seconds < 1e-5 ? 2 : 1, store.language) + " " + text("lab.loops.microseconds")
        }
        if seconds < 1 {
            return L10n.number(seconds * 1e3, fractionDigits: seconds < 1e-2 ? 2 : 1, store.language) + " " + text("lab.loops.milliseconds")
        }
        return L10n.number(seconds, fractionDigits: 2, store.language) + " " + text("lab.loops.seconds")
    }

    var body: some View {
        let n = size
        let share = LoopsMatrices.computeShare(n)
        let computeBound = share > 0.5
        LessonsFinalCard {
            LabHeader(title: text("lab.loops.title"), instruction: text("lab.loops.subtitle"))
            chart()
                .frame(height: 250)
                .accessibilityLabel(text("lab.loops.chartSpoken"))
            Text(text("lab.loops.legend")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(String(format: text("lab.loops.size"), "\(n)")).frame(width: 150, alignment: .leading)
                Slider(value: $sizeIndex, in: 0...Double(LoopsMatrices.sliderSizes.count - 1), step: 1)
                    .accessibilityIdentifier("lab.loops.size")
            }
            LabStatGrid {
                LabStat(label: text("lab.loops.statMultiplies"), value: lessonsFinalScientific(LoopsMatrices.multiplications(n), store.language), identifier: "lab.loops.multiplies")
                LabStat(label: text("lab.loops.statLoops"), value: duration(LoopsMatrices.loopSeconds(n)), tint: .red, identifier: "lab.loops.loops")
                LabStat(label: text("lab.loops.statNumpy"), value: duration(LoopsMatrices.numpySeconds(n)), tint: .teal, identifier: "lab.loops.numpy")
                LabStat(label: text("lab.loops.statShare"), value: L10n.number(share * 100, fractionDigits: 0, store.language) + " %", tint: computeBound ? .green : .orange, identifier: "lab.loops.share")
                LabStat(label: text("lab.loops.statFaster"), value: "×" + L10n.number(LoopsMatrices.timesFaster(n), fractionDigits: 0, store.language), identifier: "lab.loops.faster")
                LabStat(label: text("lab.loops.statTraining"),
                        value: String(format: text("lab.loops.trainingValue"),
                                      L10n.number(LoopsMatrices.plainTrainingMinutes, fractionDigits: 1, store.language),
                                      L10n.number(LoopsMatrices.numpyTrainingSeconds, fractionDigits: 0, store.language)),
                        tint: .purple, identifier: "lab.loops.training")
            }
            LabStatusBadge(kind: computeBound ? .good : .info,
                           text: computeBound ? text("lab.loops.computeBound") : text("lab.loops.callBound"),
                           identifier: "lab.loops.status")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.loops.challenge"), solved: solved,
                         solvedText: text("lab.loops.challengeDone"), identifier: "lab.loops.challenge")
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.loops.howLoops"), text("lab.loops.howCall"), text("lab.loops.howBatch")])
        }
        .onChange(of: sizeIndex) { _ in
            if size == LoopsMatrices.firstComputeBound { solved = true }
        }
    }

    /// Time against size on log axes: x is log₂ n, y is log₁₀ of seconds. Drag to choose the size.
    private func chart() -> some View {
        GeometryReader { proxy in
            let plot = LabPlotGeometry(size: proxy.size, x: 3...9, y: -7...0)
            Canvas { context, _ in
                plot.drawAxes(in: context, xLabel: text("lab.loops.xAxis"), yLabel: text("lab.loops.yAxis"),
                              xTicks: [3, 4, 5, 6, 7, 8, 9], yTicks: [-6, -3, 0],
                              format: { value in
                                  if value >= 3 { return "\(Int(pow(2.0, value)))" }
                                  if value <= -6 { return "1 " + text("lab.loops.microseconds") }
                                  if value <= -3 { return "1 " + text("lab.loops.milliseconds") }
                                  return "1 " + text("lab.loops.seconds")
                              })
                let curves: [(Color, (Int) -> Double, Bool)] = [
                    (.red, LoopsMatrices.loopSeconds, false),
                    (.teal, LoopsMatrices.numpySeconds, false),
                    (.gray, LoopsMatrices.computeSeconds, true)
                ]
                for (color, seconds, dashed) in curves {
                    var line = Path()
                    for step in 0...60 {
                        let logN: Double = 3.0 + Double(step) * 0.1
                        let n = Int(pow(2.0, logN).rounded())
                        let point: CGPoint = plot.point(logN, max(-7.0, log10(seconds(n))))
                        if step == 0 { line.move(to: point) } else { line.addLine(to: point) }
                    }
                    context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 2, dash: dashed ? [5, 4] : []))
                }
                for (index, n) in LoopsMatrices.measuredSizes.enumerated() {
                    let x: Double = log2(Double(n))
                    let loops: CGPoint = plot.point(x, log10(LoopsMatrices.loopMilliseconds[index] / 1000))
                    let fast: CGPoint = plot.point(x, log10(LoopsMatrices.numpyMilliseconds[index] / 1000))
                    context.fill(Path(ellipseIn: CGRect(x: loops.x - 4, y: loops.y - 4, width: 8, height: 8)), with: .color(.red))
                    context.fill(Path(ellipseIn: CGRect(x: fast.x - 4, y: fast.y - 4, width: 8, height: 8)), with: .color(.teal))
                }
                let current: Double = log2(Double(size))
                var marker = Path()
                marker.move(to: plot.point(current, -7))
                marker.addLine(to: plot.point(current, 0))
                context.stroke(marker, with: .color(AppPalette.accent.color), lineWidth: 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let logN = plot.value(at: value.location).x
                sizeIndex = Double(min(LoopsMatrices.sliderSizes.count - 1, max(0, Int((logN - 3).rounded()))))
            })
        }
    }
}
