import SwiftUI

/// Shared building blocks for the interactive labs: plot axes with ticks and labels, large readouts,
/// a coloured status, a goal the learner can reach, and an explanation folded away until wanted.

/// Maps data coordinates to a plot area inside a canvas and draws its grid, ticks, and axis labels.
struct LabPlotGeometry {
    let rect: CGRect
    let x: ClosedRange<Double>
    let y: ClosedRange<Double>

    init(size: CGSize, x: ClosedRange<Double>, y: ClosedRange<Double>,
         leading: CGFloat = 46, bottom: CGFloat = 30, top: CGFloat = 10, trailing: CGFloat = 12) {
        rect = CGRect(x: leading, y: top, width: max(1, size.width - leading - trailing), height: max(1, size.height - top - bottom))
        self.x = x
        self.y = y
    }

    func point(_ valueX: Double, _ valueY: Double) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * CGFloat((valueX - x.lowerBound) / (x.upperBound - x.lowerBound)),
                y: rect.maxY - rect.height * CGFloat((valueY - y.lowerBound) / (y.upperBound - y.lowerBound)))
    }

    func value(at location: CGPoint) -> (x: Double, y: Double) {
        (x.lowerBound + Double((location.x - rect.minX) / rect.width) * (x.upperBound - x.lowerBound),
         y.lowerBound + Double((rect.maxY - location.y) / rect.height) * (y.upperBound - y.lowerBound))
    }

    /// Round tick values (1, 2, or 5 times a power of ten) covering the range.
    static func ticks(_ range: ClosedRange<Double>, count: Int = 5) -> [Double] {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return [range.lowerBound] }
        let rough = span / Double(max(count, 1))
        let power = pow(10, floor(log10(rough)))
        let step = [1.0, 2, 5, 10].map { $0 * power }.first { $0 >= rough } ?? rough
        var values: [Double] = []
        var tick = (range.lowerBound / step).rounded(.up) * step
        while tick <= range.upperBound + step * 1e-9 {
            values.append(abs(tick) < step * 1e-9 ? 0 : tick)
            tick += step
        }
        return values
    }

    func drawAxes(in context: GraphicsContext, xLabel: String, yLabel: String,
                  xTicks: [Double]? = nil, yTicks: [Double]? = nil, format: (Double) -> String) {
        let xs = xTicks ?? Self.ticks(x)
        let ys = yTicks ?? Self.ticks(y)
        var grid = Path()
        for value in xs {
            grid.move(to: point(value, y.lowerBound))
            grid.addLine(to: point(value, y.upperBound))
        }
        for value in ys {
            grid.move(to: point(x.lowerBound, value))
            grid.addLine(to: point(x.upperBound, value))
        }
        context.stroke(grid, with: .color(.secondary.opacity(0.18)), lineWidth: 0.8)
        var frame = Path()
        frame.move(to: CGPoint(x: rect.minX, y: rect.minY))
        frame.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        frame.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        context.stroke(frame, with: .color(.secondary.opacity(0.7)), lineWidth: 1)
        for value in xs {
            context.draw(Text(verbatim: format(value)).font(.caption2).foregroundColor(.secondary),
                         at: CGPoint(x: point(value, y.lowerBound).x, y: rect.maxY + 9))
        }
        for value in ys {
            context.draw(Text(verbatim: format(value)).font(.caption2).foregroundColor(.secondary),
                         at: CGPoint(x: rect.minX - 6, y: point(x.lowerBound, value).y), anchor: .trailing)
        }
        context.draw(Text(verbatim: xLabel).font(.caption.weight(.semibold)).foregroundColor(.secondary),
                     at: CGPoint(x: rect.maxX, y: rect.maxY + 22), anchor: .trailing)
        context.draw(Text(verbatim: yLabel).font(.caption.weight(.semibold)).foregroundColor(.secondary),
                     at: CGPoint(x: rect.minX + 4, y: rect.minY), anchor: .topLeading)
    }
}

/// A short title with a one-line instruction under it.
struct LabHeader: View {
    let title: String
    let instruction: String
    /// Accessibility identifier for the instruction text, for labs whose UI tests read it.
    var instructionIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(instruction)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(instructionIdentifier ?? "")
        }
    }
}

/// A large readout with a small caption, tinted to group related numbers.
struct LabStat: View {
    let label: String
    let value: String
    var tint: Color = .accentColor
    var identifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier(identifier ?? "")
            Text(verbatim: label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: value)
    }
}

/// Readouts laid out in as many columns as fit.
struct LabStatGrid<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], alignment: .leading, spacing: 10) {
            content
        }
    }
}

enum LabStatusKind {
    case good, warning, bad, info

    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .bad: return .red
        case .info: return .accentColor
        }
    }

    var symbol: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .bad: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }
}

/// A coloured verdict such as "converges" or "diverges".
struct LabStatusBadge: View {
    let kind: LabStatusKind
    let text: String
    var identifier: String?

    var body: some View {
        Label {
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier ?? "")
        } icon: {
            Image(systemName: kind.symbol)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(kind.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: text)
    }
}

/// A goal the learner can reach by experimenting; it turns green with a check mark when reached.
struct LabChallenge: View {
    let caption: String
    let task: String
    let solved: Bool
    let solvedText: String
    var identifier: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: solved ? "checkmark.seal.fill" : "target")
                .font(.title2)
                .foregroundStyle(solved ? Color.green : Color.orange)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(verbatim: solved ? solvedText : task)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(identifier ?? "")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((solved ? Color.green : Color.orange).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: solved)
    }
}

/// The formulas and limits of a lab, folded away so the lab itself stays uncluttered.
struct LabExplainer: View {
    let title: String
    let paragraphs: [String]

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(verbatim: paragraph)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 6)
        } label: {
            Label(title, systemImage: "lightbulb")
                .font(.callout.weight(.medium))
        }
    }
}

/// A colour scale from deep blue (low) through teal and green to yellow (high), for heat maps.
enum LabHeatScale {
    static func color(_ share: Double) -> Color {
        let t = min(max(share, 0), 1)
        let stops: [(Double, Double, Double)] = [(0.10, 0.15, 0.45), (0.10, 0.45, 0.65), (0.20, 0.70, 0.55), (0.75, 0.85, 0.30), (0.98, 0.90, 0.35)]
        let scaled = t * Double(stops.count - 1)
        let index = min(Int(scaled), stops.count - 2)
        let local = scaled - Double(index)
        let a = stops[index], b = stops[index + 1]
        return Color(red: a.0 + (b.0 - a.0) * local, green: a.1 + (b.1 - a.1) * local, blue: a.2 + (b.2 - a.2) * local)
    }
}
