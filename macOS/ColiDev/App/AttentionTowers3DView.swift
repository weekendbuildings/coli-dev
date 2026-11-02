import SceneKit
import SwiftUI
import simd

/// The true attention weights as a board of towers: a row is the current place, a column is the place looked at, and the
/// height is the weight. Future places are closed by the mask. Gold arcs run from a selected row to the answer's towers.
/// Настоящие веса внимания как доска башен: строка это текущее место, столбец это место, куда смотрит модель, высота это
/// вес. Будущие места закрыты маской. От выбранной строки золотые дуги идут к башням ответа.
struct AttentionTowersSceneView: NSViewRepresentable {
    let model: PatternAttentionModel
    let example: [Int]
    let selectedRow: Int
    let language: AppLanguage
    let onSelectRow: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    typealias Model = PatternAttentionModel

    private static let rows = Model.length - 1
    private static let cell: Float = 1.15
    private static let towerSide: CGFloat = 0.86
    private static let fullHeight: Float = 3.4
    private static var boardHalf: Float { cell * Float(rows) / 2 }

    /// Rows run from the back to the front, and columns from left to right. / Строки идут от дальнего края к ближнему, столбцы слева направо.
    private static func cellCenter(row: Int, column: Int) -> SIMD3<Float> {
        SIMD3<Float>(cell * (Float(column) + 0.5) - boardHalf - 1.5, 0, cell * (Float(row) + 0.5) - boardHalf)
    }

    private static func answerCenter(row: Int, symbol: Int) -> SIMD3<Float> {
        let start = boardHalf - 1.5 + 0.9
        return SIMD3<Float>(start + Float(symbol) * 0.72, 0, cell * (Float(row) + 0.5) - boardHalf)
    }

    final class Coordinator: NSObject {
        var onSelectRow: ((Int) -> Void)?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        view.scene = Self.makeScene()
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        view.orbit(around: SIMD3(0, 0.8, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        let coordinator = context.coordinator
        view.onClick = { [weak coordinator, weak view] location in
            guard let coordinator, let view else { return }
            for hit in view.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue]) {
                let parts = (hit.node.name ?? "").split(separator: "-")
                if parts.count == 3, parts[0] == "tower", let row = Int(parts[1]) {
                    coordinator.onSelectRow?(row)
                    return
                }
            }
        }
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let root = view.scene?.rootNode else { return }
        context.coordinator.onSelectRow = onSelectRow
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0 : 0.07
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .linear)
        Self.updateTowers(root: root, model: model, example: example, selectedRow: selectedRow)
        SCNTransaction.commit()
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        Self.updateAnswer(root: root, model: model, example: example, selectedRow: selectedRow, language: language)
        Self.updateLetters(root: root, example: example, language: language)
        SCNTransaction.commit()
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: true, shadowScale: 9, keyPosition: SCNVector3(4.9, 11.8, 5.8))

        let table = SCNBox(width: CGFloat(cell * Float(rows) + 5.6), height: 0.2, length: CGFloat(cell * Float(rows) + 1.9), chamferRadius: 0.09)
        table.materials = [TrainingStage.material(NSColor(red: 0.105, green: 0.12, blue: 0.18, alpha: 1))]
        let tableNode = SCNNode(geometry: table)
        tableNode.position = SCNVector3(0.1, -0.1, 0)
        scene.rootNode.addChildNode(tableNode)

        // A chamfered tower per cell, grown by scale, so that its form stays solid. / Башня на клетку растёт через масштаб и остаётся цельной.
        for row in 0..<rows {
            for column in 0..<rows {
                let box = SCNBox(width: towerSide, height: 1, length: towerSide, chamferRadius: 0.05)
                let material = TrainingStage.metal(.gray)
                material.specular.contents = NSColor(white: 0.4, alpha: 1)
                box.materials = [material]
                let tower = SCNNode(geometry: box)
                tower.name = "tower-\(row)-\(column)"
                tower.pivot = SCNMatrix4MakeTranslation(0, -0.5, 0)
                tower.simdPosition = cellCenter(row: row, column: column)
                scene.rootNode.addChildNode(tower)
            }
            let label = TrainingStage.label("", size: 0.42, color: TrainingStage.dimText)
            label.name = "row-letter-\(row)"
            label.simdPosition = cellCenter(row: row, column: 0) + SIMD3<Float>(-0.95, 0.1, 0)
            scene.rootNode.addChildNode(label)
        }
        for column in 0..<rows {
            let label = TrainingStage.label("", size: 0.42, color: TrainingStage.dimText)
            label.name = "column-letter-\(column)"
            label.simdPosition = cellCenter(row: rows - 1, column: column) + SIMD3<Float>(0, 0.1, 0.92)
            scene.rootNode.addChildNode(label)
        }

        // The answer's four small towers stand to the right of the selected row. / Четыре башни ответа стоят справа от выбранной строки.
        for symbol in 0..<Model.symbols {
            let box = SCNBox(width: 0.56, height: 1, length: 0.56, chamferRadius: 0.05)
            box.materials = [TrainingStage.metal(.gray)]
            let node = SCNNode(geometry: box)
            node.name = "answer-\(symbol)"
            node.pivot = SCNMatrix4MakeTranslation(0, -0.5, 0)
            scene.rootNode.addChildNode(node)
            let label = TrainingStage.platedLabel(size: 0.34, color: TrainingStage.text)
            label.name = "answer-label-\(symbol)"
            TrainingStage.setPlatedLabel(label, Model.letters[symbol])
            scene.rootNode.addChildNode(label)
        }
        let arcs = SCNNode()
        arcs.name = "arcs"
        scene.rootNode.addChildNode(arcs)
        let rail = SCNBox(width: CGFloat(cell * Float(rows)), height: 0.04, length: CGFloat(cell), chamferRadius: 0.02)
        rail.materials = [TrainingStage.material(TrainingStage.trainedWeight.withAlphaComponent(0.5), lit: false)]
        let railNode = SCNNode(geometry: rail)
        railNode.name = "rail"
        scene.rootNode.addChildNode(railNode)
        let title = TrainingStage.platedLabel(size: 0.36, color: TrainingStage.trainedWeight)
        title.name = "answer-title"
        scene.rootNode.addChildNode(title)

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 90
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(-8.2, 21.2, 25.8)
        cameraNode.look(at: SCNVector3(0, 0.8, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    private static func color(_ answer: Double) -> NSColor {
        let rgba = TrainingStage.answerColor(answer)
        return NSColor(red: CGFloat(rgba.x), green: CGFloat(rgba.y), blue: CGFloat(rgba.z), alpha: 1)
    }

    private static func updateTowers(root: SCNNode, model: Model, example: [Int], selectedRow: Int) {
        let closed = NSColor(red: 0.16, green: 0.17, blue: 0.23, alpha: 1)
        for row in 0..<rows {
            let weights = model.weights(example, at: row)
            for column in 0..<rows {
                guard let tower = root.childNode(withName: "tower-\(row)-\(column)", recursively: false) else { continue }
                let open = column <= row
                let weight = open ? weights[column] : 0
                // A closed cell stays a low tile, and a row without a target stays dim. / Закрытая клетка остаётся низкой плиткой.
                let height = open ? max(0.06, Float(weight) * fullHeight) : 0.03
                tower.scale = SCNVector3(1, height, 1)
                let live = open && model.hasTarget(row: row)
                let shade = live ? color(weight) : (open ? NSColor(white: 0.34, alpha: 1) : closed)
                tower.geometry?.firstMaterial?.diffuse.contents = shade
            }
        }
    }

    private static func updateLetters(root: SCNNode, example: [Int], language: AppLanguage) {
        for index in 0..<rows {
            let letter = Model.letters[example[index]]
            if let label = root.childNode(withName: "row-letter-\(index)", recursively: false) { TrainingStage.setLabel(label, letter) }
            if let label = root.childNode(withName: "column-letter-\(index)", recursively: false) { TrainingStage.setLabel(label, letter) }
        }
    }

    /// The answer at the selected row, and the arcs that carry the weights to it. Arc thickness is the true weight.
    /// Ответ выбранной строки и дуги, несущие к нему веса. Толщина дуги это настоящий вес.
    private static func updateAnswer(root: SCNNode, model: Model, example: [Int], selectedRow: Int, language: AppLanguage) {
        let answer = model.answer(example, at: selectedRow)
        let weights = model.weights(example, at: selectedRow)
        for symbol in 0..<Model.symbols {
            let spot = answerCenter(row: selectedRow, symbol: symbol)
            if let node = root.childNode(withName: "answer-\(symbol)", recursively: false) {
                node.simdPosition = spot
                node.scale = SCNVector3(1, max(0.06, Float(answer[symbol]) * fullHeight), 1)
                node.geometry?.firstMaterial?.diffuse.contents = color(answer[symbol])
            }
            root.childNode(withName: "answer-label-\(symbol)", recursively: false)?.simdPosition = spot + SIMD3<Float>(0, max(0.06, Float(answer[symbol]) * fullHeight) + 0.42, 0)
        }
        root.childNode(withName: "rail", recursively: false)?.simdPosition = SIMD3<Float>(-1.5, 0.02, cellCenter(row: selectedRow, column: 0).z)
        if let title = root.childNode(withName: "answer-title", recursively: false) {
            TrainingStage.setPlatedLabel(title, L10n.text("lab.attention.answerLabel", language))
            title.simdPosition = answerCenter(row: selectedRow, symbol: 1) + SIMD3<Float>(0.36, 0.3, 0.75)
        }
        guard let arcs = root.childNode(withName: "arcs", recursively: false) else { return }
        arcs.childNodes.forEach { $0.removeFromParentNode() }
        let gold = TrainingStage.metal(TrainingStage.trainedWeight)
        gold.isDoubleSided = true
        let chosen = answer.indices.max { answer[$0] < answer[$1] } ?? 0
        for (column, weight) in weights.enumerated() where weight > 0.06 {
            let top = cellCenter(row: selectedRow, column: column) + SIMD3<Float>(0, max(0.06, Float(weight) * fullHeight), 0)
            let end = answerCenter(row: selectedRow, symbol: chosen) + SIMD3<Float>(0, max(0.06, Float(answer[chosen]) * fullHeight), 0)
            let rise: Float = 0.8 + 1.2 * Float(selectedRow - column + 1) / Float(rows)
            let curve = SceneCurve(start: top, control1: top + SIMD3<Float>(0.4, rise, 0), control2: end + SIMD3<Float>(-0.4, rise, 0), end: end)
            let tube = SCNNode(geometry: TrainingStage.tube(along: curve, radius: 0.015 + 0.06 * Float(weight), segments: 24, sides: 8))
            tube.geometry?.materials = [gold]
            tube.castsShadow = false
            arcs.addChildNode(tube)
        }
    }
}
