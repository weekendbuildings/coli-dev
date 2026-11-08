import SceneKit
import SwiftUI
import simd

/// One bar as the scene draws it. / Столбик, как его рисует сцена.
struct CreatorSceneBar: Equatable {
    let bar: CreatorBar
    /// Under the bar: "1"…"10", "Py", "Инж". / Подпись под столбиком.
    let shortLabel: String
    /// Above the selected bar: "3/10 · 29 %". / Над выбранным столбиком.
    let numbers: String
    /// Skillbox bars stand apart from the path modules. / Столбики Skillbox стоят отдельно от модулей пути.
    let isSkillbox: Bool
}

/// 3D bars of the Creator progress: height is the share done, colour is the quality. A drag turns the scene,
/// a click on a bar shows its numbers. The 2D list next to it says the same for VoiceOver.
/// 3D-столбики прогресса Творца: высота — доля пройденного, цвет — качество. Перетаскивание поворачивает сцену,
/// щелчок по столбику показывает числа. 2D-список рядом говорит то же для VoiceOver.
struct CreatorBars3DView: NSViewRepresentable {
    let bars: [CreatorSceneBar]
    let selected: String?
    let skillboxLabel: String
    let onSelect: (String?) -> Void

    static let maxHeight: Float = 4
    static let spacing: Float = 1.05
    static let skillboxGap: Float = 0.9
    static let floorTop: Float = 0.04

    static func color(forQuality quality: Double?) -> NSColor {
        guard let quality else { return NSColor(white: 0.55, alpha: 1) }
        return NSColor(hue: CGFloat(CreatorProgressMath.hue(forQuality: quality)), saturation: 0.72, brightness: 0.93, alpha: 1)
    }

    /// Centred x of every bar; Skillbox bars after a gap. / Координаты x по центру; Skillbox после промежутка.
    static func positions(_ bars: [CreatorSceneBar]) -> [Float] {
        var x: Float = 0
        var result: [Float] = []
        for (index, bar) in bars.enumerated() {
            if index > 0 { x += spacing + (bar.isSkillbox && !bars[index - 1].isSkillbox ? skillboxGap : 0) }
            result.append(x)
        }
        let middle = ((result.first ?? 0) + (result.last ?? 0)) / 2
        return result.map { $0 - middle }
    }

    final class Coordinator {
        var drawn: [CreatorSceneBar] = []
        var drawnSelected: String?
        var onSelect: ((String?) -> Void)?

        func pick(at location: CGPoint, in view: SCNView) {
            let hit = view.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
                .lazy.compactMap { result -> String? in
                    var node: SCNNode? = result.node
                    while let current = node {
                        if let name = current.name, name.hasPrefix("bar.") { return String(name.dropFirst(4)) }
                        node = current.parent
                    }
                    return nil
                }.first
            onSelect?(hit)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        let scene = SCNScene()
        let camera = SCNNode()
        camera.name = "camera"
        camera.camera = SCNCamera()
        // A horizontal field of view keeps every bar in the frame however narrow the card is.
        // Горизонтальный угол обзора держит все столбики в кадре при любой ширине карточки.
        camera.camera?.projectionDirection = .horizontal
        camera.camera?.fieldOfView = 58
        camera.simdPosition = SIMD3(0, 5.2, 14.5)
        camera.simdLook(at: SIMD3(0, 1.9, 0))
        scene.rootNode.addChildNode(camera)
        TrainingStage.addLights(to: scene, shadows: true, shadowScale: 9, keyPosition: SCNVector3(3, 12, 8))
        let content = SCNNode()
        content.name = "content"
        scene.rootNode.addChildNode(content)
        view.scene = scene
        view.pointOfView = camera
        view.orbit(around: SIMD3(0, 1.9, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        let coordinator = context.coordinator
        view.onClick = { [weak coordinator, weak view] location in
            guard let coordinator, let view else { return }
            coordinator.pick(at: location, in: view)
        }
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSelect = onSelect
        guard coordinator.drawn != bars || coordinator.drawnSelected != selected,
              let content = view.scene?.rootNode.childNode(withName: "content", recursively: false) else { return }
        coordinator.drawn = bars
        coordinator.drawnSelected = selected
        content.childNodes.forEach { $0.removeFromParentNode() }
        build(into: content)
    }

    private func build(into content: SCNNode) {
        let xs = Self.positions(bars)
        let width = CGFloat((xs.last ?? 0) - (xs.first ?? 0)) + 1.8
        let floor = SCNBox(width: width, height: CGFloat(Self.floorTop * 2), length: 2.6, chamferRadius: 0.05)
        floor.firstMaterial = TrainingStage.material(NSColor(red: 0.13, green: 0.15, blue: 0.22, alpha: 1))
        content.addChildNode(SCNNode(geometry: floor))

        for (bar, x) in zip(bars, xs) {
            let group = SCNNode()
            group.name = "bar." + bar.bar.id
            group.simdPosition = SIMD3(x, Self.floorTop, 0)
            let isSelected = bar.bar.id == selected

            // A faint glass case shows the full height, so the eye sees the share. / Прозрачный футляр — полная высота.
            let glass = SCNBox(width: 0.74, height: CGFloat(Self.maxHeight), length: 0.74, chamferRadius: 0.04)
            // Additive light: the case can only brighten the stage, never darken it.
            // Аддитивный свет: футляр только высветляет сцену и никогда её не затемняет.
            let glassMaterial = TrainingStage.material(NSColor(white: isSelected ? 0.16 : 0.07, alpha: 1), lit: false)
            glassMaterial.blendMode = .add
            glassMaterial.writesToDepthBuffer = false
            glassMaterial.isDoubleSided = true
            glass.firstMaterial = glassMaterial
            let glassNode = SCNNode(geometry: glass)
            glassNode.simdPosition = SIMD3(0, Self.maxHeight / 2, 0)
            glassNode.castsShadow = false
            group.addChildNode(glassNode)
            // A thin lid marks 100 %. / Тонкая крышка отмечает 100 %.
            let lid = SCNBox(width: 0.74, height: 0.02, length: 0.74, chamferRadius: 0)
            lid.firstMaterial = TrainingStage.material(NSColor(white: isSelected ? 0.6 : 0.3, alpha: 1), lit: false)
            lid.firstMaterial?.blendMode = .add
            let lidNode = SCNNode(geometry: lid)
            lidNode.simdPosition = SIMD3(0, Self.maxHeight, 0)
            lidNode.castsShadow = false
            group.addChildNode(lidNode)

            let height = max(0.06, Float(bar.bar.fraction) * Self.maxHeight)
            let solid = SCNBox(width: 0.6, height: CGFloat(height), length: 0.6, chamferRadius: 0.03)
            let solidMaterial = TrainingStage.material(Self.color(forQuality: bar.bar.quality))
            if isSelected { solidMaterial.emission.contents = NSColor(white: 0.25, alpha: 1) }
            solid.firstMaterial = solidMaterial
            let solidNode = SCNNode(geometry: solid)
            solidNode.simdPosition = SIMD3(0, height / 2, 0)
            group.addChildNode(solidNode)

            let label = TrainingStage.label(bar.shortLabel, size: 0.34, color: isSelected ? .white : TrainingStage.text)
            label.simdPosition = SIMD3(0, 0.25, 0.95)
            group.addChildNode(label)

            if isSelected {
                let numbers = TrainingStage.label(bar.numbers, size: 0.36, color: .white, weight: .bold)
                numbers.simdPosition = SIMD3(0, Self.maxHeight + 0.45, 0)
                group.addChildNode(numbers)
            }
            content.addChildNode(group)
        }

        let skillboxXs = zip(bars, xs).filter { $0.0.isSkillbox }.map(\.1)
        if let first = skillboxXs.first, let last = skillboxXs.last {
            let caption = TrainingStage.label(skillboxLabel, size: 0.28, color: TrainingStage.dimText)
            caption.simdPosition = SIMD3((first + last) / 2, 0.25, 1.5)
            content.addChildNode(caption)
        }
    }
}
