import SceneKit
import SwiftUI
import simd

/// The valley as a solid block whose height is the real error, with one ball and trail for each rule.
/// Долина как цельный блок: высота это настоящая ошибка; у каждого правила свой шарик и след.
struct OptimizerValleySceneView: NSViewRepresentable {
    let paths: [OptimizerKind: [ValleyPoint]]
    let step: Int
    let revision: Int
    let minimumLabel: String
    let onPick: (ValleyPoint) -> Void

    private static let xScale = 0.5
    private static let zScale = 1.1
    private static let heightScale = 0.18
    private static let xLimit = 10.0
    private static let yLimit = 3.0
    private static let base: Float = -0.3

    static func color(_ kind: OptimizerKind) -> NSColor {
        switch kind {
        case .plain: return .systemOrange
        case .momentum: return .white
        case .adam: return .systemPink
        }
    }

    private static func scenePoint(_ point: ValleyPoint, lift: Double = 0) -> SIMD3<Float> {
        let height = OptimizerValley.loss(point) * heightScale + lift
        return SIMD3<Float>(Float(point.x * xScale), Float(height), Float(-point.y * zScale))
    }

    private static func isInside(_ point: ValleyPoint) -> Bool {
        abs(point.x) <= xLimit && abs(point.y) <= yLimit
    }

    final class Coordinator {
        var revision = -1
        var drawn: [OptimizerKind: Int] = [:]
        var balls: [OptimizerKind: SCNNode] = [:]
        var trails: [OptimizerKind: SCNNode] = [:]
        var materials: [OptimizerKind: SCNMaterial] = [:]
        var onPick: ((ValleyPoint) -> Void)?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        scene.rootNode.addChildNode(Self.surfaceNode())
        scene.rootNode.addChildNode(Self.skirtNode())
        TrainingStage.addLights(to: scene, shadows: false)

        let marker = TrainingStage.label(minimumLabel, size: 0.32)
        marker.simdPosition = SIMD3<Float>(0.15, 0.55, 0)
        scene.rootNode.addChildNode(marker)
        let pin = TrainingStage.cylinder(from: SIMD3<Float>(0, 0, 0), to: SIMD3<Float>(0, 0.5, 0), radius: 0.02, material: TrainingStage.material(.systemYellow, lit: false))
        scene.rootNode.addChildNode(pin)

        for kind in OptimizerKind.allCases {
            let material = TrainingStage.material(Self.color(kind))
            let ball = SCNNode(geometry: SCNSphere(radius: 0.15))
            ball.geometry?.materials = [material]
            let trail = SCNNode()
            scene.rootNode.addChildNode(ball)
            scene.rootNode.addChildNode(trail)
            context.coordinator.balls[kind] = ball
            context.coordinator.trails[kind] = trail
            context.coordinator.materials[kind] = TrainingStage.material(Self.color(kind), lit: false)
        }

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 80
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(8, 17, 20)
        cameraNode.look(at: SCNVector3(0, 0.7, 0))
        scene.rootNode.addChildNode(cameraNode)

        view.scene = scene
        view.pointOfView = cameraNode
        view.orbit(around: SIMD3<Float>(0, 0.7, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        let coordinator = context.coordinator
        view.onClick = { [weak coordinator, weak view] location in
            guard let coordinator, let view else { return }
            let hits = view.hitTest(location, options: nil)
            guard let hit = hits.first(where: { $0.node.name == "valley" }) else { return }
            let world = hit.worldCoordinates
            coordinator.onPick?(ValleyPoint(x: Double(world.x) / Self.xScale, y: -Double(world.z) / Self.zScale))
        }
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onPick = onPick
        if coordinator.revision != revision {
            coordinator.revision = revision
            coordinator.drawn = [:]
            for trail in coordinator.trails.values {
                trail.childNodes.forEach { $0.removeFromParentNode() }
            }
        }
        for kind in OptimizerKind.allCases {
            guard let path = paths[kind], !path.isEmpty, let ball = coordinator.balls[kind], let trail = coordinator.trails[kind], let material = coordinator.materials[kind] else { continue }
            let index = min(step, path.count - 1)
            let point = path[index]
            let inside = Self.isInside(point)
            ball.isHidden = !inside
            if inside { ball.simdPosition = Self.scenePoint(point, lift: 0.17) }
            var from = coordinator.drawn[kind] ?? 0
            while from < index {
                let first = path[from]
                let second = path[from + 1]
                if Self.isInside(first), Self.isInside(second) {
                    trail.addChildNode(TrainingStage.cylinder(from: Self.scenePoint(first, lift: 0.05), to: Self.scenePoint(second, lift: 0.05), radius: 0.028, material: material))
                }
                from += 1
            }
            coordinator.drawn[kind] = index
        }
    }

    private static let resolution = 61

    private static func gridPoint(_ i: Int, _ j: Int) -> ValleyPoint {
        let share = Double(resolution - 1)
        return ValleyPoint(x: -xLimit + 2 * xLimit * Double(i) / share, y: -yLimit + 2 * yLimit * Double(j) / share)
    }

    private static func surfaceColor(_ height: Double) -> SIMD4<Float> {
        let t = Float(min(height / (9.5 * heightScale), 1))
        let red: Float = 0.08 + 0.87 * t * t
        let green: Float = 0.2 + 0.72 * t
        let blue: Float = 0.5 + 0.1 * t - 0.45 * t * t
        return SIMD4<Float>(red, green, blue, 1)
    }

    private static func surfaceNode() -> SCNNode {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [SIMD4<Float>] = []
        var indices: [Int32] = []
        for j in 0..<resolution {
            for i in 0..<resolution {
                let point = gridPoint(i, j)
                let position = scenePoint(point)
                vertices.append(SCNVector3(position))
                let slopeX: Double = heightScale * 0.01 * point.x / xScale
                let slopeZ: Double = heightScale * 2 * point.y / -zScale
                let normal = simd_normalize(SIMD3<Double>(-slopeX, 1, -slopeZ))
                normals.append(SCNVector3(normal.x, normal.y, normal.z))
                colors.append(surfaceColor(OptimizerValley.loss(point) * heightScale))
            }
        }
        for j in 0..<(resolution - 1) {
            for i in 0..<(resolution - 1) {
                let corner = Int32(j * resolution + i)
                let right = corner + 1
                let up = corner + Int32(resolution)
                indices.append(contentsOf: [corner, up, right, right, up, up + 1])
            }
        }
        let data = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let colorSource = SCNGeometrySource(data: data, semantic: .color, vectorCount: colors.count, usesFloatComponents: true,
                                            componentsPerVector: 4, bytesPerComponent: 4, dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride)
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals), colorSource],
                                   elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.white
        material.lightingModel = .blinn
        material.specular.contents = NSColor(white: 0.15, alpha: 1)
        material.isDoubleSided = true
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = "valley"
        return node
    }

    /// Walls and a floor, so the valley reads as a solid block. / Стенки и дно: долина выглядит цельным блоком.
    private static func skirtNode() -> SCNNode {
        var edge: [ValleyPoint] = []
        for i in 0..<resolution { edge.append(gridPoint(i, 0)) }
        for j in 1..<resolution { edge.append(gridPoint(resolution - 1, j)) }
        for i in stride(from: resolution - 2, through: 0, by: -1) { edge.append(gridPoint(i, resolution - 1)) }
        for j in stride(from: resolution - 2, through: 1, by: -1) { edge.append(gridPoint(0, j)) }
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        for point in edge {
            let top = scenePoint(point)
            vertices.append(SCNVector3(top))
            vertices.append(SCNVector3(top.x, base, top.z))
        }
        let count = Int32(edge.count)
        for k in 0..<count {
            let next = (k + 1) % count
            indices.append(contentsOf: [k * 2, k * 2 + 1, next * 2, next * 2, k * 2 + 1, next * 2 + 1])
        }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)], elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let material = TrainingStage.material(NSColor(red: 0.13, green: 0.17, blue: 0.3, alpha: 1), lit: false)
        material.isDoubleSided = true
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        let floor = SCNBox(width: CGFloat(2 * xLimit * xScale), height: 0.02, length: CGFloat(2 * yLimit * zScale), chamferRadius: 0)
        floor.materials = [TrainingStage.material(NSColor(red: 0.09, green: 0.12, blue: 0.22, alpha: 1), lit: false)]
        let floorNode = SCNNode(geometry: floor)
        floorNode.simdPosition = SIMD3<Float>(0, base, 0)
        node.addChildNode(floorNode)
        return node
    }
}
