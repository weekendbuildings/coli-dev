import SwiftUI

struct QuadraticFunctionLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var coefficientMagnitude = 1.0
    @State private var horizontalShift = -1.0
    @State private var verticalShift = 1.0
    @State private var opensDown = false
    @State private var predictionRound = QuadraticPredictionRound(
        answerOrder: QuizAnswerOrder(optionCount: 3, answerOriginalIndex: 1)
    )
    @State private var answerOrderSequence = QuizAnswerOrderSequence(optionCount: 3)
    @State private var assessment = QuadraticPredictionAssessment()
    @State private var hasStartedExperiment = false

    private var answerOrder: QuizAnswerOrder { predictionRound.answerOrder }
    private var selectedAnswer: Int? { predictionRound.selectedDisplayedIndex }

    private var function: QuadraticFunctionPractice {
        QuadraticFunctionPractice(
            a: opensDown ? -coefficientMagnitude : coefficientMagnitude,
            h: horizontalShift,
            k: verticalShift
        )!
    }

    private var coefficientText: String {
        number(function.coefficient)
    }

    private var formula: String {
        let horizontalPart: String
        if horizontalShift == 0 {
            horizontalPart = "x"
        } else if horizontalShift > 0 {
            horizontalPart = "(x − \(number(horizontalShift)))"
        } else {
            horizontalPart = "(x + \(number(abs(horizontalShift))))"
        }
        let verticalPart = verticalShift < 0
            ? "− \(number(abs(verticalShift)))"
            : "+ \(number(verticalShift))"
        return "f(x) = \(coefficientText)\(horizontalPart)² \(verticalPart)"
    }

    private var widthKey: String {
        switch function.width {
        case .wider: "lab.quadratic.width.wider"
        case .standard: "lab.quadratic.width.standard"
        case .narrower: "lab.quadratic.width.narrower"
        }
    }

    private var rootSummary: String {
        let roots = function.realRoots().map(number).joined(separator: store.language == .ru ? "; " : ", ")
        guard !roots.isEmpty else { return L10n.text("lab.quadratic.roots.none", store.language) }
        return String(format: L10n.text("lab.quadratic.roots", store.language), roots)
    }

    var body: some View {
        QuadraticLabCard {
            Text(L10n.text("lab.quadratic.prompt", store.language))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.text("lab.quadratic.prediction", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(Array(answerOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        submitAnswer(displayIndex)
                    } label: {
                        Text(L10n.text("lab.quadratic.option.\(originalIndex)", store.language))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 7)
                            .background(answerColor(for: displayIndex), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedAnswer != nil)
                }
            }

            if let selectedIndex = selectedAnswer {
                let isCorrect = answerOrder.isCorrect(displayedIndex: selectedIndex)
                Label(
                    L10n.text(isCorrect ? "lab.quadratic.correct" : "lab.quadratic.incorrect", store.language),
                    systemImage: isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                )
                .foregroundStyle(isCorrect ? Color.green : Color.orange)
                .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("lab.quadratic.feedback", store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !isCorrect {
                    Button(L10n.text("lab.quadratic.retry", store.language)) {
                        beginNextPrediction()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(formula)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(Text(String(format: L10n.text("lab.quadratic.formula", store.language), formula)))

            QuadraticFunctionPlot(function: function, language: store.language)
                .frame(height: 230)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(
                    format: L10n.text("lab.quadratic.vertex", store.language),
                    number(function.vertexX),
                    number(function.vertexY)
                ))
                Text(String(format: L10n.text("lab.quadratic.axis", store.language), number(function.vertexX)))
                Text(L10n.text(function.opensUp ? "lab.quadratic.direction.up" : "lab.quadratic.direction.down", store.language))
                Text(L10n.text(widthKey, store.language))
                Text(rootSummary)
            }
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Text(L10n.text("lab.quadratic.experiment", store.language))
                .font(.subheadline.weight(.semibold))

            parameterRow("lab.quadratic.coefficient", value: $coefficientMagnitude, range: 0.25...2, step: 0.25, number: number(coefficientMagnitude))
            Toggle(L10n.text("lab.quadratic.opensDown", store.language), isOn: $opensDown)
                .toggleStyle(.switch)
                .accessibilityHint(Text(L10n.text("lab.quadratic.opensDownHint", store.language)))
                .disabled(!hasStartedExperiment)
            parameterRow("lab.quadratic.horizontal", value: $horizontalShift, range: -3...3, step: 0.5, number: number(horizontalShift))
            parameterRow("lab.quadratic.vertical", value: $verticalShift, range: -3...3, step: 0.5, number: number(verticalShift))

            Text(L10n.text("lab.quadratic.limits", store.language))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func parameterRow(
        _ labelKey: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        number: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(L10n.text(labelKey, store.language))
                .frame(width: 112, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(Text(L10n.text(labelKey, store.language)))
            Text(number)
                .font(.body.monospacedDigit())
                .frame(width: 42, alignment: .trailing)
        }
        .disabled(!hasStartedExperiment)
    }

    private func answerColor(for displayIndex: Int) -> Color {
        guard selectedAnswer == displayIndex else { return Color.secondary.opacity(0.08) }
        return answerOrder.isCorrect(displayedIndex: displayIndex)
            ? Color.green.opacity(0.16)
            : Color.orange.opacity(0.16)
    }

    private func submitAnswer(_ displayIndex: Int) {
        guard let correct = predictionRound.submit(displayedIndex: displayIndex) else { return }
        hasStartedExperiment = true
        store.recordStudyAssessment(
            lessonID: QuadraticPredictionAssessment.lessonID,
            evidence: assessment.recordAnswer(isCorrect: correct)
        )
    }

    private func beginNextPrediction() {
        let nextOrder = answerOrderSequence.nextOrder(
            answerOriginalIndex: 1,
            following: predictionRound.answerOrder
        )
        predictionRound.beginNewQuestion(answerOrder: nextOrder)
    }

    private func number(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: store.language == .ru ? "ru_RU" : "en_US"))
                .precision(.fractionLength(0...2))
        )
    }
}

private struct QuadraticLabCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .coliSurface(cornerRadius: 18)
    }
}

private struct QuadraticFunctionPlot: View {
    let function: QuadraticFunctionPractice
    let language: AppLanguage

    private let xRange = -5.0...5.0
    private let yRange = -5.0...8.0

    var body: some View {
        Canvas { context, size in
            let plot = CGRect(x: 30, y: 10, width: max(0, size.width - 42), height: max(0, size.height - 24))
            guard plot.width > 0, plot.height > 0 else { return }
            var clipPath = Path()
            clipPath.addRect(plot)
            context.clip(to: clipPath)

            var grid = Path()
            for tick in -5...5 {
                let x = pointX(Double(tick), in: plot)
                grid.move(to: CGPoint(x: x, y: plot.minY))
                grid.addLine(to: CGPoint(x: x, y: plot.maxY))
            }
            for tick in -5...8 {
                let y = pointY(Double(tick), in: plot)
                grid.move(to: CGPoint(x: plot.minX, y: y))
                grid.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
            context.stroke(grid, with: .color(Color.secondary.opacity(0.14)), lineWidth: 1)

            var axes = Path()
            axes.move(to: CGPoint(x: plot.minX, y: pointY(0, in: plot)))
            axes.addLine(to: CGPoint(x: plot.maxX, y: pointY(0, in: plot)))
            axes.move(to: CGPoint(x: pointX(0, in: plot), y: plot.minY))
            axes.addLine(to: CGPoint(x: pointX(0, in: plot), y: plot.maxY))
            context.stroke(axes, with: .color(Color.secondary.opacity(0.6)), lineWidth: 1.3)

            let horizontalAxis = pointY(0, in: plot)
            let verticalAxis = pointX(0, in: plot)
            for tick in [-4, -2, 2, 4] {
                context.draw(
                    Text("\(tick)")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: pointX(Double(tick), in: plot), y: horizontalAxis + 11)
                )
                context.draw(
                    Text("\(tick)")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: verticalAxis - 10, y: pointY(Double(tick), in: plot))
                )
            }
            context.draw(
                Text("x")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary),
                at: CGPoint(x: plot.maxX - 8, y: horizontalAxis - 10)
            )
            context.draw(
                Text("y")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary),
                at: CGPoint(x: verticalAxis + 10, y: plot.minY + 9)
            )

            var curve = Path()
            for sample in 0...240 {
                let fraction = Double(sample) / 240
                let x = xRange.lowerBound + fraction * (xRange.upperBound - xRange.lowerBound)
                let point = CGPoint(x: pointX(x, in: plot), y: pointY(function.value(at: x), in: plot))
                if sample == 0 {
                    curve.move(to: point)
                } else {
                    curve.addLine(to: point)
                }
            }
            context.stroke(curve, with: .color(AppPalette.accent.color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

            let vertex = CGPoint(x: pointX(function.vertexX, in: plot), y: pointY(function.vertexY, in: plot))
            let marker = CGRect(x: vertex.x - 5, y: vertex.y - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: marker), with: .color(AppPalette.accent.color))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: L10n.text("lab.quadratic.graphLabel", language),
            number(function.coefficient),
            number(function.vertexX),
            number(function.vertexY)
        )))
    }

    private func number(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: language == .ru ? "ru_RU" : "en_US"))
                .precision(.fractionLength(0...2))
        )
    }

    private func pointX(_ value: Double, in rect: CGRect) -> CGFloat {
        rect.minX + CGFloat((value - xRange.lowerBound) / (xRange.upperBound - xRange.lowerBound)) * rect.width
    }

    private func pointY(_ value: Double, in rect: CGRect) -> CGFloat {
        rect.minY + CGFloat((yRange.upperBound - value) / (yRange.upperBound - yRange.lowerBound)) * rect.height
    }
}
