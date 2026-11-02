import SceneKit
import SwiftUI
import simd

/// A real classifier as a solid relief: the base is every possible input, the colour is the chosen class, and the height is
/// the model's confidence. Balls are the data, and a click adds a point of the chosen class.
/// Настоящий классификатор как цельный рельеф: основание это все возможные входы, цвет это выбранный класс, высота это
/// уверенность модели. Шарики это данные, а щелчок добавляет точку выбранного класса.
struct SoftmaxReliefSceneView: NSViewRepresentable {
    let model: SoftmaxClassifierModel
    let language: AppLanguage
    let onPick: (Double, Double) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    typealias Model = SoftmaxClassifierModel

    private static let side: Float = 7
    private static let reliefHeight: Float = 3.4
    private static let plinthHeight: Float = 0.3

    /// The same three colours as the lab's legend. / Те же три цвета, что в подписях тренажёра.
    static let classColors: [SIMD3<Float>] = [SIMD3(0.25, 0.55, 1), SIMD3(1, 0.58, 0.18), SIMD3(0.2, 0.85, 0.55)]

    static func classColor(_ index: Int) -> NSColor {
        let color = classColors[index]
        return NSColor(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: 1)
    }

    private static var span: Double { Model.domain.upperBound - Model.domain.lowerBound }

    private static func input(_ unit: Double) -> Double { Model.domain.lowerBound + span * unit }

    private static func scenePoint(model: Model, x1: Double, x2: Double, lift: Float = 0) -> SIMD3<Float> {
        let u = Float((x1 - Model.domain.lowerBound) / span) - 0.5
        let v = Float((x2 - Model.domain.lowerBound) / span) - 0.5
        return SIMD3<Float>(u * side, plinthHeight + Float(model.confidence(x1: x1, x2: x2)) * reliefHeight + lift, -v * side)
    }

    /// Walks along the view ray until it drops below the true surface. / Идём вдоль луча, пока он не уйдёт под поверхность.
    private static func pickedInput(model: Model, rayFrom near: SIMD3<Float>, to far: SIMD3<Float>) -> (Double, Double)? {
        let length = simd_distance(near, far)
        guard length > 0 else { return nil }
        let direction = (far - near) / length
        var travelled: Float = 0
        while travelled < length {
            let point = near + direction * travelled
            let u = Double(point.x / side) + 0.5
            let v = Double(-point.z / side) + 0.5
            if (0...1).contains(u), (0...1).contains(v) {
                let x1 = input(u), x2 = input(v)
                if point.y <= plinthHeight + Float(model.confidence(x1: x1, x2: x2)) * reliefHeight { return (x1, x2) }
            }
            travelled += 0.02
        }
        return nil
    }

    final class Coordinator: NSObject {
        var model = Model()
        var onPick: ((Double, Double) -> Void)?
        var drawnWeights: [[Double]] = []
        var drawnSamples: [Model.Sample] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        view.scene = Self.makeScene()
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        view.orbit(around: SIMD3(0, 1, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        let coordinator = context.coordinator
        view.onClick = { [weak coordinator, weak view] location in
            guard let coordinator, let view else { return }
            let near = view.unprojectPoint(SCNVector3(location.x, location.y, 0))
            let far = view.unprojectPoint(SCNVector3(location.x, location.y, 1))
            if let found = Self.pickedInput(model: coordinator.model, rayFrom: SIMD3(near), to: SIMD3(far)) {
                coordinator.onPick?(found.0, found.1)
            }
        }
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let root = view.scene?.rootNode else { return }
        let coordinator = context.coordinator
        coordinator.onPick = onPick
        coordinator.model = model
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        if coordinator.drawnWeights != model.weights {
            coordinator.drawnWeights = model.weights
            Self.redrawRelief(model: model, root: root)
        }
        Self.placeSamples(model: model, root: root, coordinator: coordinator)
        if let title = root.childNode(withName: "axis-title", recursively: false) {
            TrainingStage.setLabel(title, L10n.text("lab.softmax.axis", language))
        }
        SCNTransaction.commit()
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: true, shadowScale: 9, keyPosition: SCNVector3(4.9, 11.8, 5.8))

        let table = SCNBox(width: 9.2, height: 0.18, length: 9.2, chamferRadius: 0.09)
        table.materials = [TrainingStage.material(NSColor(red: 0.105, green: 0.12, blue: 0.18, alpha: 1))]
        let tableNode = SCNNode(geometry: table)
        tableNode.position = SCNVector3(0, -0.09, 0)
        scene.rootNode.addChildNode(tableNode)

        let plinth = SCNBox(width: CGFloat(side + 0.3), height: CGFloat(plinthHeight), length: CGFloat(side + 0.3), chamferRadius: 0.05)
        plinth.materials = [TrainingStage.metal(NSColor(red: 0.2, green: 0.22, blue: 0.29, alpha: 1))]
        let plinthNode = SCNNode(geometry: plinth)
        plinthNode.position = SCNVector3(0, plinthHeight / 2, 0)
        scene.rootNode.addChildNode(plinthNode)

        let relief = SCNNode()
        relief.name = "relief"
        relief.position = SCNVector3(0, plinthHeight, 0)
        let grid = SCNNode()
        grid.name = "grid"
        relief.addChildNode(grid)
        scene.rootNode.addChildNode(relief)

        let samples = SCNNode()
        samples.name = "samples"
        scene.rootNode.addChildNode(samples)

        // The inputs along two edges, printed on the table. / Входы вдоль двух краёв, напечатаны на столе.
        for (text, position, turn) in [("x₁", SCNVector3(0, 0.012, 4.2), CGFloat(0)), ("x₂", SCNVector3(4.2, 0.012, 0), CGFloat.pi / 2)] {
            let label = TrainingStage.label(text, size: 0.46, color: TrainingStage.dimText)
            label.constraints = nil
            label.eulerAngles = SCNVector3(-CGFloat.pi / 2, turn, 0)
            label.position = position
            scene.rootNode.addChildNode(label)
        }

        // The scale of confidence stands at the back corner. / Шкала уверенности стоит в дальнем углу.
        let axisBase = SIMD3<Float>(-side / 2 - 0.5, plinthHeight, -side / 2 - 0.5)
        scene.rootNode.addChildNode(TrainingStage.cylinder(from: axisBase, to: axisBase + SIMD3(0, reliefHeight, 0), radius: 0.018, material: TrainingStage.material(TrainingStage.dimText, lit: false)))
        for (value, text) in [(0.0, "0"), (1.0 / 3, "⅓"), (1.0, "1")] {
            let tick = TrainingStage.label(text, size: 0.32, color: TrainingStage.dimText, weight: .regular)
            tick.simdPosition = axisBase + SIMD3(-0.3, Float(value) * reliefHeight, 0)
            scene.rootNode.addChildNode(tick)
        }
        let title = TrainingStage.label("", size: 0.32, color: TrainingStage.dimText)
        title.name = "axis-title"
        title.simdPosition = axisBase + SIMD3(0, reliefHeight + 0.45, 0)
        scene.rootNode.addChildNode(title)

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 80
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(8.3, 21.5, 18)
        cameraNode.look(at: SCNVector3(0, 1, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    private static func redrawRelief(model: Model, root: SCNNode) {
        guard let node = root.childNode(withName: "relief", recursively: false),
              let block = TrainingStage.reliefBlock(
                side: side,
                height: reliefHeight,
                resolution: 72,
                answer: { model.confidence(x1: input($0), x2: input($1)) },
                slope: { model.confidenceSlope(x1: input($0), x2: input($1)) * span },
                color: { u, v in
                    // Each class gives its colour in proportion to its probability, so low ground between plateaus blends them.
                    // Каждый класс даёт цвет по своей вероятности, поэтому низины между плато смешивают цвета.
                    let q = model.probabilities(x1: input(u), x2: input(v))
                    var mixed = SIMD3<Float>(repeating: 0)
                    for k in q.indices { mixed += classColors[k] * Float(q[k]) }
                    return SIMD4(mixed.x, mixed.y, mixed.z, 1)
                }
              ) else { return }
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.white
        material.lightingModel = .blinn
        material.specular.contents = NSColor(white: 0.25, alpha: 1)
        material.isDoubleSided = true
        block.solid.materials = [material]
        node.geometry = block.solid
        block.grid.firstMaterial = TrainingStage.material(NSColor(white: 0, alpha: 0.26), lit: false)
        node.childNode(withName: "grid", recursively: false)?.geometry = block.grid
    }

    private static func placeSamples(model: Model, root: SCNNode, coordinator: Coordinator) {
        guard let parent = root.childNode(withName: "samples", recursively: false) else { return }
        if coordinator.drawnSamples != model.samples {
            coordinator.drawnSamples = model.samples
            parent.childNodes.forEach { $0.removeFromParentNode() }
            for sample in model.samples {
                let sphere = SCNSphere(radius: 0.17)
                sphere.segmentCount = 20
                let material = TrainingStage.material(classColor(sample.label))
                material.specular.contents = NSColor.white
                material.emission.contents = classColor(sample.label).withAlphaComponent(1).blended(withFraction: 0.75, of: .black)
                sphere.materials = [material]
                let ball = SCNNode(geometry: sphere)
                // A white rim keeps the ball visible on a plateau of its own colour. / Белый обод виден и на плато своего цвета.
                let rim = SCNTorus(ringRadius: 0.19, pipeRadius: 0.028)
                rim.materials = [TrainingStage.material(.white, lit: false)]
                let rimNode = SCNNode(geometry: rim)
                rimNode.name = "rim"
                ball.addChildNode(rimNode)
                parent.addChildNode(ball)
            }
        }
        for (ball, sample) in zip(parent.childNodes, model.samples) {
            ball.simdPosition = scenePoint(model: model, x1: sample.x1, x2: sample.x2, lift: 0.17)
            let wrong = NSColor(red: 1, green: 0.25, blue: 0.3, alpha: 1)
            ball.childNode(withName: "rim", recursively: false)?.geometry?.firstMaterial?.diffuse.contents = model.isCorrect(sample) ? NSColor.white : wrong
        }
    }
}
