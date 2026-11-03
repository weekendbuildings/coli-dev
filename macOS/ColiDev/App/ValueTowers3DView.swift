import SceneKit
import SwiftUI
import simd

/// The value of each cell as a tower: its height is the real value, cones are the policy, the white line is the route.
/// Ценность каждой клетки как башня: высота это настоящая ценность, конусы это политика, белая линия это маршрут.
struct ValueTowersSceneView: NSViewRepresentable {
    let values: [Double]
    let arrows: [Int?]
    let route: [Int]
    let startLabel: String
    let goalLabel: String
    let pitLabel: String

    private static func height(_ value: Double) -> CGFloat {
        CGFloat((max(-1, min(1, value)) + 1) * 1.5 + 0.12)
    }

    private static func position(_ cell: Int) -> (x: Float, z: Float) {
        (Float(cell % GridWorld.columns) - 2.5, Float(cell / GridWorld.columns) - 2)
    }

    private static func color(_ value: Double) -> NSColor {
        let t: CGFloat = CGFloat(max(-1, min(1, value)))
        if t < 0 {
            return NSColor(calibratedRed: 0.93, green: 0.76 + 0.62 * t, blue: 0.2 + 0.05 * t, alpha: 1)
        }
        return NSColor(calibratedRed: 0.93 - 0.75 * t, green: 0.76 - 0.04 * t, blue: 0.2 + 0.2 * t, alpha: 1)
    }

    final class Coordinator {
        var towers: [SCNNode] = []
        var boxes: [SCNBox] = []
        var cones: [SCNNode] = []
        var labels: [Int: SCNNode] = [:]
        var routeRoot = SCNNode()
        var routeMaterial = SCNMaterial()
        var drawnRoute: [Int] = []
        var drawnHeights: [CGFloat] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: false)
        let coordinator = context.coordinator
        coordinator.routeMaterial = TrainingStage.material(.white, lit: false)
        let ground = SCNBox(width: 6.4, height: 0.1, length: 5.4, chamferRadius: 0.03)
        ground.materials = [TrainingStage.material(NSColor(white: 0.3, alpha: 1))]
        let groundNode = SCNNode(geometry: ground)
        groundNode.simdPosition = SIMD3<Float>(0, -0.05, 0)
        scene.rootNode.addChildNode(groundNode)
        for cell in 0..<GridWorld.cellCount {
            let box = SCNBox(width: 0.92, height: 0.12, length: 0.92, chamferRadius: 0.03)
            box.materials = [TrainingStage.material(Self.color(0))]
            let tower = SCNNode(geometry: box)
            let place = Self.position(cell)
            tower.simdPosition = SIMD3<Float>(place.x, 0.06, place.z)
            scene.rootNode.addChildNode(tower)
            coordinator.towers.append(tower)
            coordinator.boxes.append(box)
            let coneGeometry = SCNCone(topRadius: 0, bottomRadius: 0.17, height: 0.42)
            coneGeometry.materials = [TrainingStage.material(NSColor(white: 0.12, alpha: 1), lit: false)]
            let cone = SCNNode(geometry: coneGeometry)
            cone.isHidden = true
            scene.rootNode.addChildNode(cone)
            coordinator.cones.append(cone)
        }
        for (cell, text) in [(GridWorld.start, startLabel), (GridWorld.goal, goalLabel), (26, pitLabel)] {
            let label = TrainingStage.label(text, size: 0.3)
            scene.rootNode.addChildNode(label)
            coordinator.labels[cell] = label
        }
        scene.rootNode.addChildNode(coordinator.routeRoot)

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 80
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(-5, 13, 15)
        cameraNode.look(at: SCNVector3(0, 0.8, 0))
        scene.rootNode.addChildNode(cameraNode)
        view.scene = scene
        view.pointOfView = cameraNode
        view.orbit(around: SIMD3<Float>(0, 0.8, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        guard values.count == GridWorld.cellCount, coordinator.towers.count == GridWorld.cellCount else { return }
        let heights: [CGFloat] = values.map { Self.height($0) }
        if heights != coordinator.drawnHeights {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.3
            for cell in 0..<GridWorld.cellCount {
                let height = heights[cell]
                coordinator.boxes[cell].height = height
                coordinator.boxes[cell].firstMaterial?.diffuse.contents = Self.color(values[cell])
                let place = Self.position(cell)
                coordinator.towers[cell].simdPosition = SIMD3<Float>(place.x, Float(height) / 2, place.z)
                if let label = coordinator.labels[cell] {
                    label.simdPosition = SIMD3<Float>(place.x, Float(height) + 0.35, place.z)
                }
            }
            SCNTransaction.commit()
            coordinator.drawnHeights = heights
        }
        for cell in 0..<GridWorld.cellCount {
            let cone = coordinator.cones[cell]
            guard let action = arrows[cell] else {
                cone.isHidden = true
                continue
            }
            cone.isHidden = false
            let place = Self.position(cell)
            cone.simdPosition = SIMD3<Float>(place.x, Float(heights[cell]) + 0.13, place.z)
            switch action {
            case 0: cone.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
            case 1: cone.eulerAngles = SCNVector3(0, 0, -CGFloat.pi / 2)
            case 2: cone.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)
            default: cone.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2)
            }
        }
        coordinator.routeRoot.childNodes.forEach { $0.removeFromParentNode() }
        for index in 0..<max(route.count - 1, 0) {
            let first = Self.position(route[index])
            let second = Self.position(route[index + 1])
            let lift: Float = 0.34
            let from = SIMD3<Float>(first.x, Float(heights[route[index]]) + lift, first.z)
            let to = SIMD3<Float>(second.x, Float(heights[route[index + 1]]) + lift, second.z)
            coordinator.routeRoot.addChildNode(TrainingStage.cylinder(from: from, to: to, radius: 0.05, material: coordinator.routeMaterial))
        }
    }
}
