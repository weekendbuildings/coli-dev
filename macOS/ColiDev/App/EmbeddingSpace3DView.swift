import SceneKit
import SwiftUI
import simd

/// The true word vectors in their true three-dimensional space, inside a cube, each on a stem down to the floor so that its
/// height can be read. A click selects a word, and rays from the centre show its direction and its nearest neighbour's.
/// Настоящие векторы слов в настоящем трёхмерном пространстве: каждое слово стоит на стойке до пола, поэтому видна его
/// высота. Щелчок выбирает слово, а лучи из центра показывают его направление и направление ближайшего соседа.
struct EmbeddingSpaceSceneView: NSViewRepresentable {
    let model: WordEmbeddingModel
    let selected: Int
    let language: AppLanguage
    let onSelect: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    typealias Model = WordEmbeddingModel

    private static let half: Float = 4
    private static let wordRadius: CGFloat = 0.2

    static func color(_ group: Model.Group) -> NSColor {
        switch group {
        case .animal: return NSColor(red: 0.3, green: 0.6, blue: 1, alpha: 1)
        case .food: return NSColor(red: 0.25, green: 0.85, blue: 0.55, alpha: 1)
        case .vehicle: return NSColor(red: 1, green: 0.6, blue: 0.2, alpha: 1)
        case .verb: return NSColor(red: 0.78, green: 0.55, blue: 1, alpha: 1)
        case .other: return NSColor(white: 0.72, alpha: 1)
        }
    }

    /// The whole cloud is scaled to fit the cube, since only directions matter for similarity.
    /// Всё облако масштабируется под куб: для сходства важны только направления.
    private static func positions(_ model: Model) -> [SIMD3<Float>] {
        let vectors = model.wordVectors.map { SIMD3<Float>(Float($0[0]), Float($0[1]), Float($0[2])) }
        let longest = vectors.map { simd_length($0) }.max() ?? 1
        let scale = (half * 0.92) / max(longest, 0.001)
        return vectors.map { $0 * scale }
    }

    final class Coordinator: NSObject {
        var onSelect: ((Int) -> Void)?
        var points: [SIMD3<Float>] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        view.scene = Self.makeScene()
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        view.orbit(around: SIMD3(0, 0, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        let coordinator = context.coordinator
        view.onClick = { [weak coordinator, weak view] location in
            guard let coordinator, let view else { return }
            // The nearest word on screen, within a finger's reach. / Ближайшее слово на экране, если щелчок рядом с ним.
            var best: (index: Int, distance: CGFloat)?
            for (index, point) in coordinator.points.enumerated() {
                let projected = view.projectPoint(SCNVector3(point))
                let distance = hypot(projected.x - location.x, projected.y - location.y)
                if distance < 34, distance < (best?.distance ?? .infinity) { best = (index, distance) }
            }
            if let best { coordinator.onSelect?(best.index) }
        }
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let root = view.scene?.rootNode else { return }
        let coordinator = context.coordinator
        coordinator.onSelect = onSelect
        let points = Self.positions(model)
        coordinator.points = points
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0 : 0.06
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .linear)
        for index in points.indices {
            root.childNode(withName: "word-\(index)", recursively: false)?.simdPosition = points[index]
        }
        SCNTransaction.commit()

        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        Self.updateStemsAndLabels(root: root, points: points, selected: selected, language: language)
        Self.updateRays(root: root, model: model, points: points, selected: selected)
        SCNTransaction.commit()
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: true, shadowScale: 9, keyPosition: SCNVector3(4.9, 11.8, 5.8))

        // The floor of the space, and a metal frame around it. / Пол пространства и металлическая рама вокруг.
        let floor = SCNBox(width: CGFloat(2 * half + 0.5), height: 0.14, length: CGFloat(2 * half + 0.5), chamferRadius: 0.07)
        floor.materials = [TrainingStage.material(NSColor(red: 0.105, green: 0.12, blue: 0.18, alpha: 1))]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -half - 0.07, 0)
        scene.rootNode.addChildNode(floorNode)
        let lineMaterial = TrainingStage.material(NSColor(white: 1, alpha: 0.16), lit: false)
        for tick in stride(from: -half, through: half, by: half / 2) {
            scene.rootNode.addChildNode(TrainingStage.cylinder(from: SIMD3(tick, -half + 0.005, -half), to: SIMD3(tick, -half + 0.005, half), radius: 0.006, material: lineMaterial))
            scene.rootNode.addChildNode(TrainingStage.cylinder(from: SIMD3(-half, -half + 0.005, tick), to: SIMD3(half, -half + 0.005, tick), radius: 0.006, material: lineMaterial))
        }
        let frameMaterial = TrainingStage.metal(NSColor(white: 0.4, alpha: 1))
        for x in [-half, half] {
            for z in [-half, half] {
                scene.rootNode.addChildNode(TrainingStage.cylinder(from: SIMD3(x, -half, z), to: SIMD3(x, half, z), radius: 0.022, material: frameMaterial))
            }
        }
        for sign in [-half, half] {
            scene.rootNode.addChildNode(TrainingStage.cylinder(from: SIMD3(-half, half, sign), to: SIMD3(half, half, sign), radius: 0.022, material: frameMaterial))
            scene.rootNode.addChildNode(TrainingStage.cylinder(from: SIMD3(sign, half, -half), to: SIMD3(sign, half, half), radius: 0.022, material: frameMaterial))
        }

        // The centre of the space: all rays start here. / Центр пространства: все лучи начинаются здесь.
        let center = SCNSphere(radius: 0.11)
        center.materials = [TrainingStage.material(.white, lit: false)]
        scene.rootNode.addChildNode(SCNNode(geometry: center))

        for index in 0..<Model.count {
            let sphere = SCNSphere(radius: wordRadius)
            sphere.segmentCount = 24
            let material = TrainingStage.material(color(Model.group(index)))
            material.specular.contents = NSColor.white
            sphere.materials = [material]
            let node = SCNNode(geometry: sphere)
            node.name = "word-\(index)"
            scene.rootNode.addChildNode(node)
            let stem = SCNNode()
            stem.name = "stem-\(index)"
            scene.rootNode.addChildNode(stem)
            let label = TrainingStage.platedLabel(size: 0.32, color: TrainingStage.text)
            label.name = "label-\(index)"
            scene.rootNode.addChildNode(label)
        }
        let rays = SCNNode()
        rays.name = "rays"
        scene.rootNode.addChildNode(rays)

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 90
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(16.4, 11.6, 28.2)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    /// Words that stand at one point stack their labels above it, so that they do not cover each other.
    /// Слова в одной точке складывают подписи стопкой над ней, чтобы не закрывать друг друга.
    private static func labelOffset(_ index: Int, points: [SIMD3<Float>]) -> SIMD3<Float> {
        let rank = (0..<index).filter { simd_distance(points[$0], points[index]) < 0.75 }.count
        return SIMD3<Float>(0, 0.42 + Float(rank) * 0.46, 0)
    }

    private static func updateStemsAndLabels(root: SCNNode, points: [SIMD3<Float>], selected: Int, language: AppLanguage) {
        let stemMaterial = TrainingStage.material(NSColor(white: 1, alpha: 0.22), lit: false)
        for (index, point) in points.enumerated() {
            if let stem = root.childNode(withName: "stem-\(index)", recursively: false) {
                let floorPoint = SIMD3<Float>(point.x, -half, point.z)
                let drawn = TrainingStage.cylinder(from: point, to: floorPoint, radius: 0.012, material: stemMaterial)
                stem.geometry = drawn.geometry
                stem.simdPosition = drawn.simdPosition
                stem.simdOrientation = drawn.simdOrientation
            }
            if let label = root.childNode(withName: "label-\(index)", recursively: false) {
                TrainingStage.setPlatedLabel(label, Model.word(index, language: language))
                label.simdPosition = point + labelOffset(index, points: points)
                label.geometry?.firstMaterial?.diffuse.contents = index == selected ? TrainingStage.trainedWeight : TrainingStage.text
            }
            let ball = root.childNode(withName: "word-\(index)", recursively: false)
            ball?.geometry?.firstMaterial?.emission.contents = index == selected ? NSColor(white: 0.55, alpha: 1) : NSColor(white: 0.08, alpha: 1)
            ball?.scale = index == selected ? SCNVector3(1.35, 1.35, 1.35) : SCNVector3(1, 1, 1)
        }
    }

    private static func updateRays(root: SCNNode, model: Model, points: [SIMD3<Float>], selected: Int) {
        guard let rays = root.childNode(withName: "rays", recursively: false) else { return }
        rays.childNodes.forEach { $0.removeFromParentNode() }
        rays.addChildNode(TrainingStage.cylinder(from: .zero, to: points[selected], radius: 0.045, material: TrainingStage.material(TrainingStage.trainedWeight, lit: false)))
        if let nearest = model.neighbours(of: selected).first {
            rays.addChildNode(TrainingStage.cylinder(from: .zero, to: points[nearest], radius: 0.03, material: TrainingStage.material(NSColor(white: 1, alpha: 0.75), lit: false)))
        }
    }
}
