import AppKit
import SwiftUI

struct ColorToken: Equatable {
    let lightHex: UInt32
    let darkHex: UInt32

    var color: Color { Color(nsColor: nsColor) }

    var nsColor: NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return Self.nsColor(hex: isDark ? darkHex : lightHex)
        }
    }

    /// WCAG contrast ratio between two opaque colors, from 1 to 21.
    /// Контраст по WCAG между двумя непрозрачными цветами, от 1 до 21.
    static func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        func luminance(_ hex: UInt32) -> Double {
            func channel(_ value: UInt32) -> Double {
                let unit = Double(value & 0xFF) / 255
                return unit <= 0.03928 ? unit / 12.92 : pow((unit + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(hex >> 16) + 0.7152 * channel(hex >> 8) + 0.0722 * channel(hex)
        }
        let (a, b) = (luminance(first), luminance(second))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func nsColor(hex: UInt32) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// The one palette for the app's surfaces. Colors are explicit, not system ones: the system window
/// background turns dull under the wallpaper tint and changes when the window loses focus.
/// Единая палитра поверхностей приложения. Цвета заданы явно, а не берутся из системы: системный фон
/// окна блёкнет от оттенка обоев и меняется при потере фокуса.
enum AppPalette {
    static let canvas = ColorToken(lightHex: 0xF4F5FA, darkHex: 0x14161D)
    static let sidebar = ColorToken(lightHex: 0xE9ECF5, darkHex: 0x0F1117)
    static let card = ColorToken(lightHex: 0xFFFFFF, darkHex: 0x1E212C)
    /// A recessed area inside a card. / Углублённая область внутри карточки.
    static let inset = ColorToken(lightHex: 0xF0F2F8, darkHex: 0x171921)
    static let raised = ColorToken(lightHex: 0xFFFFFF, darkHex: 0x292D3A)
    static let stroke = ColorToken(lightHex: 0xDCE0EB, darkHex: 0x2F3442)
    static let accent = ColorToken(lightHex: 0x4A4FC4, darkHex: 0x7077F2)
    /// The soft fill of a selected row. / Мягкая заливка выбранной строки.
    static let selection = ColorToken(lightHex: 0xDADCF7, darkHex: 0x2C2F55)
}

enum ColiDevVisualSystem {
    static let soundPreferenceKey = "colidev.soundEffectsEnabled"
    static let routineTransitionDuration = 0.18

    static let managementKnowledge = ColorToken(lightHex: 0x4B4294, darkHex: 0xB6A9FF)
    static let managementSources = ColorToken(lightHex: 0x0E6F66, darkHex: 0x68DCCB)
    static let managementReviewDue = ColorToken(lightHex: 0xA64055, darkHex: 0xFF98AA)

    static func subjectToken(_ subject: String) -> ColorToken {
        switch subject {
        case "mathematics": return ColorToken(lightHex: 0x5747B8, darkHex: 0xB6A8FF)
        case "english": return ColorToken(lightHex: 0xB64B2B, darkHex: 0xFF9778)
        case "physics": return ColorToken(lightHex: 0x176FAD, darkHex: 0x68B9FF)
        case "chemistry": return ColorToken(lightHex: 0x9B3474, darkHex: 0xF28CC8)
        case "biology": return ColorToken(lightHex: 0x1F7652, darkHex: 0x65D39B)
        case "zoology": return ColorToken(lightHex: 0x8A5E13, darkHex: 0xF2BD63)
        case "programming": return ColorToken(lightHex: 0x0E6F79, darkHex: 0x55D4DF)
        default: return ColorToken(lightHex: 0x405F9B, darkHex: 0x91B9FF)
        }
    }

    static func subjectColor(_ subject: String) -> Color {
        subjectToken(subject).color
    }

    static func studyAccentToken(subjectID: String, resource: String? = nil) -> ColorToken {
        let resolvedSubjectID: String
        switch subjectID {
        case "intro":
            resolvedSubjectID = resource ?? ""
        case let value where value.hasPrefix("custom-builtin:"):
            resolvedSubjectID = String(value.dropFirst("custom-builtin:".count))
        case let value where value.hasPrefix("custom-user:"):
            resolvedSubjectID = "custom-user"
        default:
            resolvedSubjectID = subjectID
        }
        return subjectToken(resolvedSubjectID)
    }
}

enum AppSoundFeedback {
    private static let completionSound = NSSound(named: NSSound.Name("Glass"))

    static func playCompletion() {
        guard UserDefaults.standard.bool(forKey: ColiDevVisualSystem.soundPreferenceKey),
              let sound = completionSound else {
            return
        }
        sound.play()
    }
}

struct ColiDevGlassControlModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            legacyMaterial(content)
        }
#else
        legacyMaterial(content)
#endif
    }

    private func legacyMaterial(_ content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        return content.background {
            shape
                .fill(AppPalette.raised.color)
                .overlay(shape.strokeBorder(AppPalette.stroke.color, lineWidth: 1))
        }
    }
}

struct ColiDevContentCardModifier: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .background {
                shape
                    .fill(AppPalette.card.color)
                    .overlay {
                        LinearGradient(
                            colors: [tint.opacity(0.13), tint.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(shape)
                    }
                    .overlay(shape.strokeBorder(tint.opacity(0.22), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
    }
}

/// The plain card every lesson and lab sits on. The border and shadow stay behind the content, so that
/// nothing covers a 3D scene or redraws with it. / Обычная карточка, на которой лежат уроки и тренажёры.
/// Рамка и тень лежат за содержимым: ничто не закрывает 3D-сцену и не перерисовывается вместе с ней.
struct ColiDevSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content.background {
            shape
                .fill(AppPalette.card.color)
                .overlay(shape.strokeBorder(AppPalette.stroke.color, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
}

/// A text field on the palette: the system rounded border is a black box on a dark card.
/// Поле ввода на цветах палитры: системная рамка на тёмной карточке выглядит чёрным прямоугольником.
struct ColiDevTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7)
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                shape
                    .fill(AppPalette.inset.color)
                    .overlay(shape.strokeBorder(AppPalette.stroke.color, lineWidth: 1))
            }
    }
}

extension View {
    func coliTextField() -> some View {
        modifier(ColiDevTextFieldModifier())
    }

    func coliGlassControl(cornerRadius: CGFloat = 16) -> some View {
        modifier(ColiDevGlassControlModifier(cornerRadius: cornerRadius))
    }

    func coliSurface(cornerRadius: CGFloat = 16) -> some View {
        modifier(ColiDevSurfaceModifier(cornerRadius: cornerRadius))
    }

    func coliContentCard(tint: Color, cornerRadius: CGFloat = 16) -> some View {
        modifier(ColiDevContentCardModifier(tint: tint, cornerRadius: cornerRadius))
    }
}
