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
                    Text("λ = " + L10n.number(SparseAutoencoder.penalties[index], fractionDigits: SparseAutoencoder.penalties[index] < 0.1 && SparseAutoencoder.penalties[index] > 0 ? 2 : 1, store.language)).tag(index)
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
