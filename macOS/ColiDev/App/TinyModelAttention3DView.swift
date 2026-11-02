import SceneKit
import SwiftUI
import simd

/// The trained model at work. A board of towers shows its true attention over the last characters it read, and tall pillars
/// show its true probabilities for the next character. / Обученная модель за работой: доска башен показывает её настоящее
/// внимание к последним прочитанным символам, а столбы показывают настоящие вероятности следующего символа.
struct TinyModelAttentionSceneView: NSViewRepresentable {
    /// One row per place, with weights for the shown places only. / По строке на место, с весами только показанных мест.
    let rows: [[Double]]
    let characters: [String]
    let candidates: [(letter: String, probability: Double)]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let shownPlaces = 14
    static let shownCandidates = 6
    private static let cell: Float = 0.74
    private static let fullHeight: Float = 3.4
    private static var boardHalf: Float { cell * Float(shownPlaces) / 2 }

    private static func cellCenter(row: Int, column: Int) -> SIMD3<Float> {
        SIMD3<Float>(cell * (Float(column) + 0.5) - boardHalf - 1.8, 0, cell * (Float(row) + 0.5) - boardHalf)
    }

    private static func pillarCenter(_ index: Int) -> SIMD3<Float> {
        SIMD3<Float>(boardHalf - 1.8 + 1.4 + Float(index) * 0.82, 0, boardHalf - 0.6)
    }

    /// A readable mark for characters with no shape of their own. / Заметный знак для символов без своей формы.
    static func shown(_ letter: String) -> String {
        switch letter {
        case " ": return "␣"
        case "\n": return "⏎"
        default: return letter
        }
    }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        view.scene = Self.makeScene()
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        view.orbit(around: SIMD3(0, 0.8, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let root = view.scene?.rootNode else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0 : 0.14
        let closed = NSColor(red: 0.16, green: 0.17, blue: 0.23, alpha: 1)
        for row in 0..<Self.shownPlaces {
            for column in 0..<Self.shownPlaces {
                guard let tower = root.childNode(withName: "tower-\(row)-\(column)", recursively: false) else { continue }
                let weight: Double? = row < rows.count && column < rows[row].count && column <= row ? rows[row][column] : nil
                tower.scale = SCNVector3(1, weight.map { max(0.05, Float($0) * Self.fullHeight) } ?? 0.02, 1)
                let rgba = TrainingStage.answerColor(weight ?? 0)
                tower.geometry?.firstMaterial?.diffuse.contents = weight == nil ? closed : NSColor(red: CGFloat(rgba.x), green: CGFloat(rgba.y), blue: CGFloat(rgba.z), alpha: 1)
            }
        }
        for index in 0..<Self.shownCandidates {
            guard let pillar = root.childNode(withName: "pillar-\(index)", recursively: false) else { continue }
            let probability = index < candidates.count ? candidates[index].probability : 0
            pillar.scale = SCNVector3(1, max(0.03, Float(probability) * Self.fullHeight * 1.4), 1)
        }
        SCNTransaction.commit()
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        for index in 0..<Self.shownPlaces {
            let letter = index < characters.count ? Self.shown(characters[index]) : ""
            if let label = root.childNode(withName: "row-\(index)", recursively: false) { TrainingStage.setLabel(label, letter) }
            if let label = root.childNode(withName: "column-\(index)", recursively: false) { TrainingStage.setLabel(label, letter) }
        }
        for index in 0..<Self.shownCandidates {
            guard let label = root.childNode(withName: "pillar-label-\(index)", recursively: false) else { continue }
            let present = index < candidates.count
            TrainingStage.setPlatedLabel(label, present ? Self.shown(candidates[index].letter) : "")
            label.isHidden = !present
            let probability = present ? candidates[index].probability : 0
            label.simdPosition = Self.pillarCenter(index) + SIMD3<Float>(0, max(0.03, Float(probability) * Self.fullHeight * 1.4) + 0.42, 0)
        }
        SCNTransaction.commit()
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: true, shadowScale: 10, keyPosition: SCNVector3(4.9, 11.8, 5.8))
        let table = SCNBox(width: CGFloat(cell * Float(shownPlaces) + 7.4), height: 0.2, length: CGFloat(cell * Float(shownPlaces) + 2), chamferRadius: 0.09)
        table.materials = [TrainingStage.material(NSColor(red: 0.105, green: 0.12, blue: 0.18, alpha: 1))]
        let tableNode = SCNNode(geometry: table)
        tableNode.position = SCNVector3(0.5, -0.1, 0)
        scene.rootNode.addChildNode(tableNode)
        for row in 0..<shownPlaces {
            for column in 0..<shownPlaces {
                let box = SCNBox(width: CGFloat(cell * 0.82), height: 1, length: CGFloat(cell * 0.82), chamferRadius: 0.04)
                let material = TrainingStage.metal(.gray)
                material.specular.contents = NSColor(white: 0.35, alpha: 1)
                box.materials = [material]
                let tower = SCNNode(geometry: box)
                tower.name = "tower-\(row)-\(column)"
                tower.pivot = SCNMatrix4MakeTranslation(0, -0.5, 0)
                tower.simdPosition = cellCenter(row: row, column: column)
                scene.rootNode.addChildNode(tower)
            }
            let rowLabel = TrainingStage.label("", size: 0.36, color: TrainingStage.dimText)
            rowLabel.name = "row-\(row)"
            rowLabel.simdPosition = cellCenter(row: row, column: 0) + SIMD3<Float>(-0.7, 0.1, 0)
            scene.rootNode.addChildNode(rowLabel)
            let columnLabel = TrainingStage.label("", size: 0.36, color: TrainingStage.dimText)
            columnLabel.name = "column-\(row)"
            columnLabel.simdPosition = cellCenter(row: shownPlaces - 1, column: row) + SIMD3<Float>(0, 0.1, 0.7)
            scene.rootNode.addChildNode(columnLabel)
        }
        for index in 0..<shownCandidates {
            let box = SCNBox(width: 0.6, height: 1, length: 0.6, chamferRadius: 0.05)
            let material = TrainingStage.metal(TrainingStage.trainedWeight)
            material.emission.contents = NSColor(red: 0.25, green: 0.18, blue: 0.02, alpha: 1)
            box.materials = [material]
            let pillar = SCNNode(geometry: box)
            pillar.name = "pillar-\(index)"
            pillar.pivot = SCNMatrix4MakeTranslation(0, -0.5, 0)
            pillar.simdPosition = pillarCenter(index)
            scene.rootNode.addChildNode(pillar)
            let label = TrainingStage.platedLabel(size: 0.38, color: TrainingStage.text)
            label.name = "pillar-label-\(index)"
            scene.rootNode.addChildNode(label)
        }
        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 90
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(-8, 22, 27)
        cameraNode.look(at: SCNVector3(0, 0.8, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }
}
