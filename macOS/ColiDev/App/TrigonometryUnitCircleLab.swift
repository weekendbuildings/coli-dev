import SwiftUI

struct TrigonometryUnitCircleLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var angleRadians = Double.pi / 3
    @State private var answerOrder = QuizAnswerOrder(optionCount: 3, answerOriginalIndex: 2)
    @State private var answerOrderSequence = QuizAnswerOrderSequence(optionCount: 3)
    @State private var selectedAnswer: Int?
    @State private var isExplanationRevealed = false
    @State private var attemptCount = 0
    @State private var firstTryCorrect: Bool?

    private let answerKeys = [
        "lab.trigonometry.option.negative",
        "lab.trigonometry.option.zero",
        "lab.trigonometry.option.positive"
    ]

    private var model: TrigonometricUnitCircle {
        TrigonometricUnitCircle(angleRadians: angleRadians)!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("lab.trigonometry.intro", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    circlePanel
                    graphPanel
                }
                VStack(spacing: 16) {
                    circlePanel
                    graphPanel
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.text("lab.trigonometry.angle", store.language))
                    Spacer()
                    Text(angleDescription)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $angleRadians, in: (-2 * Double.pi)...(2 * Double.pi), step: Double.pi / 36)
                    .accessibilityLabel(Text(L10n.text("lab.trigonometry.angle", store.language)))
                    .accessibilityValue(Text(angleDescription))
                Text(coordinateDescription)
                    .font(.callout.monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("lab.trigonometry.question", store.language))
                    .font(.headline)
                Text(String(format: L10n.text("lab.trigonometry.questionAngle", store.language), angleDescription))
                    .font(.callout)

                ForEach(Array(answerOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        submitAnswer(displayIndex)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedAnswer == displayIndex ? "checkmark.circle.fill" : "circle")
                            Text(L10n.text(answerKeys[originalIndex], store.language))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedAnswer != nil)
                    .accessibilityAddTraits(selectedAnswer == displayIndex ? .isSelected : [])
                }

                if let selectedAnswer {
                    let correct = answerOrder.isCorrect(displayedIndex: selectedAnswer)
                    let feedback = LessonAnswerFeedback.presentation(
                        isCorrect: correct,
                        explanationRevealed: isExplanationRevealed,
                        explanation: answerExplanation,
                        correctPrompt: L10n.text("lab.trigonometry.correct", store.language),
                        retryPrompt: L10n.text("lab.trigonometry.retryHint", store.language)
                    )
                    Label(
                        feedback.statusMessage,
                        systemImage: correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle"
                    )
                    .foregroundStyle(correct ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)

                    if feedback.canRevealExplanation {
                        Button {
                            isExplanationRevealed = true
                        } label: {
                            Label(L10n.text("lab.trigonometry.showExplanation", store.language), systemImage: "eye")
                        }
                        .buttonStyle(.borderless)
                    }

                    if let explanation = feedback.explanation {
                        Text(explanation)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !correct {
                        Button(L10n.text("lab.trigonometry.tryAgain", store.language), action: retry)
                            .buttonStyle(.bordered)
                    }
                }
            }

            Text(L10n.text("lab.trigonometry.limits", store.language))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .onChange(of: angleRadians) { _ in
            selectedAnswer = nil
            isExplanationRevealed = false
            answerOrder = answerOrderSequence.nextOrder(
                answerOriginalIndex: sineSignIndex,
                following: answerOrder
            )
        }
    }

    private var circlePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("lab.trigonometry.circleTitle", store.language))
                .font(.subheadline.weight(.semibold))
            UnitCircleDiagram(model: model, language: store.language)
                .frame(height: 210)
            Text(L10n.text("lab.trigonometry.circleLegend", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var graphPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("lab.trigonometry.graphTitle", store.language))
                .font(.subheadline.weight(.semibold))
            SineCosineDiagram(angleRadians: angleRadians, language: store.language)
                .frame(height: 210)
            Text(L10n.text("lab.trigonometry.graphTicks", store.language))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
            HStack(spacing: 14) {
                Label("sin θ", systemImage: "circle.fill").foregroundStyle(.blue)
                Label("cos θ", systemImage: "circle.fill").foregroundStyle(.orange)
            }
            .font(.caption)
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var angleDescription: String {
        let radians = L10n.number(angleRadians, fractionDigits: 2, store.language)
        let degrees = L10n.number(model.angleDegrees, fractionDigits: 1, store.language)
        return String(format: L10n.text("lab.trigonometry.angleValue", store.language), radians, degrees)
    }

    private var coordinateDescription: String {
        let x = L10n.number(model.xCoordinate, fractionDigits: 3, store.language)
        let y = L10n.number(model.yCoordinate, fractionDigits: 3, store.language)
        return String(format: L10n.text("lab.trigonometry.coordinates", store.language), x, y)
    }

    private var sineSignIndex: Int {
        model.sineSign.answerOriginalIndex
    }

    private var answerExplanation: String {
        let sine = L10n.number(model.yCoordinate, fractionDigits: 3, store.language)
        return String(
            format: L10n.text(model.sineSign.explanationKey, store.language),
            angleDescription,
            sine
        )
    }

    private func submitAnswer(_ displayIndex: Int) {
        guard selectedAnswer == nil else { return }
        let correct = answerOrder.isCorrect(displayedIndex: displayIndex)
        attemptCount += 1
        if firstTryCorrect == nil { firstTryCorrect = correct }
        selectedAnswer = displayIndex
        store.recordStudyAssessment(
            lessonID: "mathematics.trigonometry_and_periodic_functions",
            evidence: StudyAssessmentEvidence(
                taskType: "interactive_prediction",
                attempts: attemptCount,
                firstTryCorrect: firstTryCorrect ?? correct,
                hintsUsed: 0,
                itemID: TrigonometricUnitCircle.sineSignQuestionID
            )
        )
    }

    private func retry() {
        answerOrder = answerOrderSequence.nextOrder(
            answerOriginalIndex: sineSignIndex,
            following: answerOrder
        )
        selectedAnswer = nil
        isExplanationRevealed = false
    }
}

private struct UnitCircleDiagram: View {
    let model: TrigonometricUnitCircle
    let language: AppLanguage

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.38
            let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: circleRect), with: .color(.secondary.opacity(0.55)), lineWidth: 1.5)

            var axes = Path()
            axes.move(to: CGPoint(x: center.x - radius - 10, y: center.y))
            axes.addLine(to: CGPoint(x: center.x + radius + 10, y: center.y))
            axes.move(to: CGPoint(x: center.x, y: center.y + radius + 10))
            axes.addLine(to: CGPoint(x: center.x, y: center.y - radius - 10))
            context.stroke(axes, with: .color(.secondary.opacity(0.38)), lineWidth: 1)

            let point = CGPoint(
                x: center.x + CGFloat(model.xCoordinate) * radius,
                y: center.y - CGFloat(model.yCoordinate) * radius
            )
            var radiusLine = Path()
            radiusLine.move(to: center)
            radiusLine.addLine(to: point)
            context.stroke(radiusLine, with: .color(AppPalette.accent.color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            let origin = Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6))
            let marker = Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
            context.fill(origin, with: .color(.secondary))
            context.fill(marker, with: .color(AppPalette.accent.color))
        }
        .accessibilityElement()
        .accessibilityLabel(Text(L10n.text("lab.trigonometry.circleTitle", language)))
        .accessibilityValue(Text(String(format: L10n.text("lab.trigonometry.coordinates", language), decimal(model.xCoordinate), decimal(model.yCoordinate))))
    }

    private func decimal(_ value: Double) -> String {
        L10n.number(value, fractionDigits: 3, language)
    }
}

private struct SineCosineDiagram: View {
    let angleRadians: Double
    let language: AppLanguage

    private let minimumAngle = -2 * Double.pi
    private let maximumAngle = 2 * Double.pi

    var body: some View {
        Canvas { context, size in
            let xInset: CGFloat = 20
            let yInset: CGFloat = 14
            let plotWidth = max(1, size.width - 2 * xInset)
            let plotHeight = max(1, size.height - 2 * yInset)
            let xPosition: (Double) -> CGFloat = { x in
                xInset + CGFloat((x - minimumAngle) / (maximumAngle - minimumAngle)) * plotWidth
            }
            let yPosition: (Double) -> CGFloat = { y in
                yInset + CGFloat((1 - y) / 2) * plotHeight
            }

            for level in [-1.0, 0.0, 1.0] {
                var grid = Path()
                grid.move(to: CGPoint(x: xInset, y: yPosition(level)))
                grid.addLine(to: CGPoint(x: xInset + plotWidth, y: yPosition(level)))
                context.stroke(grid, with: .color(.secondary.opacity(level == 0 ? 0.45 : 0.16)), lineWidth: 1)
            }

            context.stroke(
                sampledPath(xInset: xInset, yInset: yInset, plotWidth: plotWidth, plotHeight: plotHeight, function: { sin($0) }),
                with: .color(.blue),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                sampledPath(xInset: xInset, yInset: yInset, plotWidth: plotWidth, plotHeight: plotHeight, function: { cos($0) }),
                with: .color(.orange),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )

            let markerX = xPosition(angleRadians)
            var markerLine = Path()
            markerLine.move(to: CGPoint(x: markerX, y: yInset))
            markerLine.addLine(to: CGPoint(x: markerX, y: yInset + plotHeight))
            context.stroke(markerLine, with: .color(.primary.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

            let markerRadius: CGFloat = 4.5
            let sinePoint = CGRect(x: markerX - markerRadius, y: yPosition(sin(angleRadians)) - markerRadius, width: markerRadius * 2, height: markerRadius * 2)
            let cosinePoint = CGRect(x: markerX - markerRadius, y: yPosition(cos(angleRadians)) - markerRadius, width: markerRadius * 2, height: markerRadius * 2)
            context.fill(Path(ellipseIn: sinePoint), with: .color(.blue))
            context.fill(Path(ellipseIn: cosinePoint), with: .color(.orange))
        }
        .accessibilityElement()
        .accessibilityLabel(Text(L10n.text("lab.trigonometry.graphTitle", language)))
        .accessibilityValue(Text(L10n.text("lab.trigonometry.graphAccessibility", language)))
    }

    private func sampledPath(
        xInset: CGFloat,
        yInset: CGFloat,
        plotWidth: CGFloat,
        plotHeight: CGFloat,
        function: (Double) -> Double
    ) -> Path {
        var path = Path()
        for index in 0...240 {
            let progress = Double(index) / 240
            let angle = minimumAngle + progress * (maximumAngle - minimumAngle)
            let point = CGPoint(
                x: xInset + CGFloat(progress) * plotWidth,
                y: yInset + CGFloat((1 - function(angle)) / 2) * plotHeight
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
