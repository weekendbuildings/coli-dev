import SceneKit
import SwiftUI
import simd

/// A town of 1000 people as cubes. The sick are red and the healthy blue, and those who test positive rise above the town,
/// so the share of red among the raised cubes is the true chance of disease after a positive test.
/// Город из 1000 людей-кубиков. Больные красные, здоровые синие, положительные поднимаются над городом, поэтому доля красных
/// среди поднятых и есть настоящая вероятность болезни при положительном тесте.
struct BayesTownSceneView: NSViewRepresentable {
    let model: BayesTownModel
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    typealias Model = BayesTownModel

    private static let cell: Float = 0.3
    private static let lift: Float = 2.6
    private static let sickColor = NSColor(red: 0.95, green: 0.25, blue: 0.3, alpha: 1)
    private static let healthyColor = NSColor(red: 0.26, green: 0.48, blue: 0.95, alpha: 1)

    private static func position(_ index: Int) -> SIMD3<Float> {
        let column = index % Model.columns
        let row = index / Model.columns
        let x: Float = (Float(column) - Float(Model.columns - 1) / 2) * cell
        let z: Float = (Float(row) - Float(Model.rows - 1) / 2) * cell
        return SIMD3<Float>(x, 0.16, z)
    }

    final class Coordinator: NSObject {
        var drawn: (rate: Double, hit: Double, alarm: Double, second: Bool)?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        view.scene = Self.makeScene()
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        view.orbit(around: SIMD3(0, 1, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let root = view.scene?.rootNode else { return }
        let coordinator = context.coordinator
        let current = (model.diseaseRate, model.hitRate, model.falseAlarmRate, model.secondTest)
        if let drawn = coordinator.drawn, drawn == current {
            SCNTransaction.begin()
            SCNTransaction.disableActions = true
            Self.setLabel(root: root, model: model, language: language)
            SCNTransaction.commit()
            return
        }
        coordinator.drawn = current
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0 : 0.25
        for index in 0..<Model.population {
            guard let cube = root.childNode(withName: "person-\(index)", recursively: false) else { continue }
            let person = model.person(at: index)
            cube.geometry?.firstMaterial?.diffuse.contents = person.sick ? Self.sickColor : Self.healthyColor
            cube.simdPosition = Self.position(index) + SIMD3<Float>(0, person.positive ? Self.lift : 0, 0)
            cube.opacity = person.positive ? 1 : 0.55
        }
        SCNTransaction.commit()
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        Self.setLabel(root: root, model: model, language: language)
        SCNTransaction.commit()
    }

    private static func setLabel(root: SCNNode, model: Model, language: AppLanguage) {
        guard let label = root.childNode(withName: "share-label", recursively: false) else { return }
        TrainingStage.setPlatedLabel(label, String(format: L10n.text("lab.town.raised", language), String(model.positiveSick), String(model.positiveHealthy)))
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: false)

        let width = CGFloat(cell * Float(Model.columns) + 1.2)
        let length = CGFloat(cell * Float(Model.rows) + 1.2)
        let table = SCNBox(width: width, height: 0.2, length: length, chamferRadius: 0.09)
        table.materials = [TrainingStage.material(NSColor(red: 0.105, green: 0.12, blue: 0.18, alpha: 1))]
        let tableNode = SCNNode(geometry: table)
        tableNode.position = SCNVector3(0, -0.1, 0)
        scene.rootNode.addChildNode(tableNode)

        // A thin glass plane marks the level of those who test positive. / Тонкая плоскость отмечает уровень положительных.
        let glass = SCNBox(width: width - 0.3, height: 0.012, length: length - 0.3, chamferRadius: 0)
        let glassMaterial = TrainingStage.material(NSColor(white: 1, alpha: 0.05), lit: false)
        glassMaterial.writesToDepthBuffer = false
        glass.materials = [glassMaterial]
        let glassNode = SCNNode(geometry: glass)
        glassNode.position = SCNVector3(0, lift - 0.12, 0)
        scene.rootNode.addChildNode(glassNode)

        for index in 0..<Model.population {
            let box = SCNBox(width: CGFloat(cell * 0.8), height: CGFloat(cell * 0.8), length: CGFloat(cell * 0.8), chamferRadius: 0.025)
            let material = TrainingStage.material(healthyColor)
            material.specular.contents = NSColor(white: 0.5, alpha: 1)
            box.materials = [material]
            let node = SCNNode(geometry: box)
            node.name = "person-\(index)"
            node.simdPosition = position(index)
            scene.rootNode.addChildNode(node)
        }
        let label = TrainingStage.platedLabel(size: 0.5, color: TrainingStage.text)
        label.name = "share-label"
        label.position = SCNVector3(0, lift + 1.15, 0)
        scene.rootNode.addChildNode(label)

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 90
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(6.5, 17, 25)
        cameraNode.look(at: SCNVector3(0, 1, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }
}
