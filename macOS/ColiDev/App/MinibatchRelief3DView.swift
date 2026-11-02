import SceneKit
import SwiftUI
import simd

/// The true error bowl of a line, with the ball at the current weights. The white arrow is the true direction of descent, and
/// the orange one is the step suggested by the last batch. / Настоящая чаша ошибки прямой. Белая стрелка это настоящее
/// направление спуска, оранжевая это шаг, подсказанный последним пакетом.
struct MinibatchReliefSceneView: NSViewRepresentable {
    let model: MinibatchLineModel
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    typealias Model = MinibatchLineModel

    private static let side: Float = 7.4
    private static let reliefHeight: Float = 3.8
    private static let plinthHeight: Float = 0.26
    private static let weightRange: ClosedRange<Double> = -3.4...4.6
    private static let shiftRange: ClosedRange<Double> = -3...4
    /// The drawing is cut at this error, to keep the bottom readable. / Рисунок обрезан на этой ошибке, чтобы дно читалось.
    private static let heightLimit = 18.0

    private static func w(_ unit: Double) -> Double { weightRange.lowerBound + (weightRange.upperBound - weightRange.lowerBound) * unit }
    private static func b(_ unit: Double) -> Double { shiftRange.lowerBound + (shiftRange.upperBound - shiftRange.lowerBound) * unit }

    private static func height(w: Double, b: Double) -> Double { min(Model.loss(w: w, b: b) / heightLimit, 1) }

    private static func scenePoint(w: Double, b: Double, lift: Float = 0) -> SIMD3<Float> {
        let u = (w - weightRange.lowerBound) / (weightRange.upperBound - weightRange.lowerBound)
        let v = (b - shiftRange.lowerBound) / (shiftRange.upperBound - shiftRange.lowerBound)
        let x: Float = (Float(u) - 0.5) * side
        let y: Float = plinthHeight + Float(height(w: w, b: b)) * reliefHeight + lift
        let z: Float = (0.5 - Float(v)) * side
        return SIMD3<Float>(x, y, z)
    }

    final class Coordinator: NSObject {
        var drawnCount = 0
        var didDrawBowl = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        view.scene = Self.makeScene()
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        view.orbit(around: SIMD3(0, 1.2, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let root = view.scene?.rootNode else { return }
        let coordinator = context.coordinator
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        if !coordinator.didDrawBowl {
            coordinator.didDrawBowl = true
            Self.drawBowl(root: root)
        }
        Self.updateTrail(root: root, model: model, coordinator: coordinator)
        Self.updateArrows(root: root, model: model)
        if let title = root.childNode(withName: "best-label", recursively: false) {
            TrainingStage.setPlatedLabel(title, L10n.text("lab.batch.bestLabel", language))
        }
        SCNTransaction.commit()
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion || model.reads == 0 ? 0 : 0.05
        root.childNode(withName: "ball", recursively: false)?.simdPosition = Self.scenePoint(w: model.w, b: model.b, lift: 0.2)
        SCNTransaction.commit()
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: true, shadowScale: 9, keyPosition: SCNVector3(4.9, 11.8, 5.8))
        let table = SCNBox(width: 9.8, height: 0.18, length: 9.8, chamferRadius: 0.09)
        table.materials = [TrainingStage.material(NSColor(red: 0.105, green: 0.12, blue: 0.18, alpha: 1))]
        let tableNode = SCNNode(geometry: table)
        tableNode.position = SCNVector3(0, -0.09, 0)
        scene.rootNode.addChildNode(tableNode)
        let plinth = SCNBox(width: CGFloat(side + 0.3), height: CGFloat(plinthHeight), length: CGFloat(side + 0.3), chamferRadius: 0.05)
        plinth.materials = [TrainingStage.metal(NSColor(red: 0.2, green: 0.22, blue: 0.29, alpha: 1))]
        let plinthNode = SCNNode(geometry: plinth)
        plinthNode.position = SCNVector3(0, plinthHeight / 2, 0)
        scene.rootNode.addChildNode(plinthNode)

        let bowl = SCNNode()
        bowl.name = "bowl"
        bowl.position = SCNVector3(0, plinthHeight, 0)
        let grid = SCNNode()
        grid.name = "grid"
        bowl.addChildNode(grid)
        scene.rootNode.addChildNode(bowl)

        let sphere = SCNSphere(radius: 0.2)
        sphere.segmentCount = 24
        let material = TrainingStage.material(.white)
        material.emission.contents = NSColor(white: 0.35, alpha: 1)
        material.specular.contents = NSColor.white
        sphere.materials = [material]
        let ball = SCNNode(geometry: sphere)
        ball.name = "ball"
        scene.rootNode.addChildNode(ball)

        let ring = SCNTorus(ringRadius: 0.3, pipeRadius: 0.045)
        ring.materials = [TrainingStage.material(NSColor(red: 0.25, green: 0.95, blue: 0.55, alpha: 1), lit: false)]
        let ringNode = SCNNode(geometry: ring)
        ringNode.simdPosition = scenePoint(w: Model.best.w, b: Model.best.b, lift: 0.04)
        scene.rootNode.addChildNode(ringNode)
        let label = TrainingStage.platedLabel(size: 0.34, color: NSColor(red: 0.45, green: 1, blue: 0.68, alpha: 1))
        label.name = "best-label"
        label.simdPosition = scenePoint(w: Model.best.w, b: Model.best.b, lift: 0.75)
        scene.rootNode.addChildNode(label)

        for (text, position, turn) in [("w", SCNVector3(0, 0.012, 4.45), CGFloat(0)), ("b", SCNVector3(4.45, 0.012, 0), CGFloat.pi / 2)] {
            let axis = TrainingStage.label(text, size: 0.46, color: TrainingStage.dimText)
            axis.constraints = nil
            axis.eulerAngles = SCNVector3(-CGFloat.pi / 2, turn, 0)
            axis.position = position
            scene.rootNode.addChildNode(axis)
        }
        for name in ["trail", "arrows"] {
            let node = SCNNode()
            node.name = name
            scene.rootNode.addChildNode(node)
        }

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 80
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(8.2, 22, 19)
        cameraNode.look(at: SCNVector3(0, 1.2, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    private static func drawBowl(root: SCNNode) {
        let spanW = weightRange.upperBound - weightRange.lowerBound
        let spanB = shiftRange.upperBound - shiftRange.lowerBound
        let lowest = Model.loss(w: Model.best.w, b: Model.best.b)
        guard let node = root.childNode(withName: "bowl", recursively: false),
              let block = TrainingStage.reliefBlock(
                side: side,
                height: reliefHeight,
                resolution: 72,
                answer: { height(w: w($0), b: b($1)) },
                slope: {
                    let loss = Model.loss(w: w($0), b: b($1))
                    guard loss < heightLimit else { return SIMD2<Double>(0, 0) }
                    let slope = Model.slope(w: w($0), b: b($1))
                    return SIMD2<Double>(slope.x * spanW, slope.y * spanB) / heightLimit
                },
                color: {
                    let loss = Model.loss(w: w($0), b: b($1))
                    return ErrorLandscapeSceneView.errorColor(max(0, min(1, (loss - lowest) / (heightLimit - lowest))) * 0.5)
                }
              ) else { return }
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.white
        material.lightingModel = .blinn
        material.specular.contents = NSColor(white: 0.22, alpha: 1)
        material.isDoubleSided = true
        block.solid.materials = [material]
        node.geometry = block.solid
        block.grid.firstMaterial = TrainingStage.material(NSColor(white: 0, alpha: 0.26), lit: false)
        node.childNode(withName: "grid", recursively: false)?.geometry = block.grid
    }

    private static func updateTrail(root: SCNNode, model: Model, coordinator: Coordinator) {
        guard let trail = root.childNode(withName: "trail", recursively: false) else { return }
        if coordinator.drawnCount > model.path.count || model.path.count == 1 {
            trail.childNodes.forEach { $0.removeFromParentNode() }
            coordinator.drawnCount = 1
        }
        let material = TrainingStage.material(NSColor(white: 1, alpha: 0.9), lit: false)
        for index in coordinator.drawnCount..<max(coordinator.drawnCount, model.path.count) {
            let from = model.path[index - 1], to = model.path[index]
            trail.addChildNode(TrainingStage.cylinder(
                from: scenePoint(w: from.w, b: from.b, lift: 0.05),
                to: scenePoint(w: to.w, b: to.b, lift: 0.05),
                radius: 0.018,
                material: material
            ))
        }
        coordinator.drawnCount = model.path.count
    }

    private static func updateArrows(root: SCNNode, model: Model) {
        guard let arrows = root.childNode(withName: "arrows", recursively: false) else { return }
        arrows.childNodes.forEach { $0.removeFromParentNode() }
        let origin = scenePoint(w: model.w, b: model.b, lift: 0.2)
        func add(_ slope: SIMD2<Double>, color: NSColor, radius: CGFloat) {
            let size = (slope.x * slope.x + slope.y * slope.y).squareRoot()
            guard size > 1e-6 else { return }
            let direction = simd_normalize(SIMD3<Float>(Float(-slope.x), 0, Float(slope.y)))
            let length = Float(min(2.4, 0.18 + size * 0.45))
            let material = TrainingStage.material(color, lit: false)
            material.readsFromDepthBuffer = false
            let shaft = TrainingStage.cylinder(from: origin, to: origin + direction * length, radius: radius, material: material)
            shaft.renderingOrder = 110
            arrows.addChildNode(shaft)
            let cone = SCNCone(topRadius: 0, bottomRadius: radius * 3, height: 0.26)
            cone.materials = [material]
            let head = SCNNode(geometry: cone)
            head.simdPosition = origin + direction * (length + 0.13)
            head.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: direction)
            head.renderingOrder = 110
            arrows.addChildNode(head)
        }
        add(model.trueSlope, color: .white, radius: 0.03)
        if let batch = model.batchSlope { add(batch, color: TrainingStage.errorSignal, radius: 0.04) }
    }
}
