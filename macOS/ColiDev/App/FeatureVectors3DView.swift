import SceneKit
import SwiftUI
import simd

/// The feature vectors of the toy model as arrows from the centre; the figure they form is the result.
/// Векторы признаков игрушечной модели как стрелки из центра; фигура из них и есть результат.
struct FeatureVectorsSceneView: NSViewRepresentable {
    let vectors: [[Double]]

    private static let scale: Float = 2.2
    private static let colors: [NSColor] = [.systemOrange, .systemTeal, .systemPink, .systemGreen, .systemYellow, .systemPurple]

    final class Coordinator {
        var root = SCNNode()
        var materials: [SCNMaterial] = []
        var edgeMaterial = SCNMaterial()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: false)
        let coordinator = context.coordinator
        coordinator.materials = Self.colors.map { TrainingStage.material($0) }
        coordinator.edgeMaterial = TrainingStage.material(NSColor(white: 0.6, alpha: 1), lit: false)
        scene.rootNode.addChildNode(coordinator.root)
        let centre = SCNNode(geometry: SCNSphere(radius: 0.09))
        centre.geometry?.materials = [TrainingStage.material(.white)]
        scene.rootNode.addChildNode(centre)

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 80
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(7, 8, 12)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        view.scene = scene
        view.pointOfView = cameraNode
        view.orbit(around: SIMD3<Float>(0, 0, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.root.childNodes.forEach { $0.removeFromParentNode() }
        var tips: [SIMD3<Float>] = []
        for (index, vector) in vectors.enumerated() where vector.count == 3 {
            let tip = SIMD3<Float>(Float(vector[0]), Float(vector[2]), Float(-vector[1])) * Self.scale
            tips.append(tip)
            let material = coordinator.materials[index % coordinator.materials.count]
            coordinator.root.addChildNode(TrainingStage.cylinder(from: SIMD3<Float>(0, 0, 0), to: tip, radius: 0.045, material: material))
            let ball = SCNNode(geometry: SCNSphere(radius: 0.13))
            ball.geometry?.materials = [material]
            ball.simdPosition = tip
            coordinator.root.addChildNode(ball)
        }
        for first in 0..<tips.count {
            for second in (first + 1)..<max(tips.count, first + 1) {
                let distance: Float = simd_length(tips[first] - tips[second])
                if distance > 0.4, distance < Self.scale * 1.75 {
                    coordinator.root.addChildNode(TrainingStage.cylinder(from: tips[first], to: tips[second], radius: 0.012, material: coordinator.edgeMaterial))
                }
            }
        }
    }
}
