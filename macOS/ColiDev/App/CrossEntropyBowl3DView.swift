import SceneKit
import SwiftUI
import simd

/// True cross-entropy as a solid bowl over the triangle of beliefs, with a ball at the model's belief and a ring at the truth.
/// Настоящая кросс-энтропия как цельная чаша над треугольником вер: шарик стоит на вере модели, кольцо на настоящих частотах.
struct CrossEntropyBowlSceneView: NSViewRepresentable {
    let model: CrossEntropyBowlModel
    let language: AppLanguage
    let onPick: ([Double]) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Model = CrossEntropyBowlModel

    private static let corners = [SIMD3<Float>(-4.5, 0, 2.6), SIMD3<Float>(4.5, 0, 2.6), SIMD3<Float>(0, 0, -5.2)]
    private static let bitHeight: Float = 0.8
    private static let divisions = 72

    private static func plane(_ belief: [Double]) -> SIMD3<Float> {
        let first: SIMD3<Float> = corners[0] * Float(belief[0])
        let second: SIMD3<Float> = corners[1] * Float(belief[1])
        let third: SIMD3<Float> = corners[2] * Float(belief[2])
        return first + second + third
    }

    private static func height(truth: [Double], belief: [Double]) -> Float {
        Float(min(Model.crossEntropy(truth, belief), Model.heightLimit)) * bitHeight
    }

    private static func surfacePoint(truth: [Double], belief: [Double], lift: Float = 0) -> SIMD3<Float> {
        plane(belief) + SIMD3<Float>(0, height(truth: truth, belief: belief) + lift, 0)
    }

    /// The belief under a point of the plane, or nil outside the triangle. / Вера под точкой плоскости или nil вне треугольника.
    private static func belief(x: Float, z: Float) -> [Double]? {
        let c = (2.6 - z) / 7.8
        let a = (4.5 - x) / 9 - c / 2
        let b = 1 - a - c
        guard a >= 0, b >= 0, c >= 0 else { return nil }
        return [Double(a), Double(b), Double(c)]
    }

    /// Walks along the view ray until it drops below the true surface. / Идём вдоль луча, пока он не уйдёт под поверхность.
    private static func pickedBelief(truth: [Double], rayFrom near: SIMD3<Float>, to far: SIMD3<Float>) -> [Double]? {
        let length = simd_distance(near, far)
        guard length > 0 else { return nil }
        let direction = (far - near) / length
        var travelled: Float = 0
        while travelled < length {
            let point = near + direction * travelled
            if let found = belief(x: point.x, z: point.z), point.y <= height(truth: truth, belief: Model.placed(found)) {
                return found
            }
            travelled += 0.02
        }
        return nil
    }

    final class Coordinator: NSObject {
        var truth: [Double] = []
        var onPick: (([Double]) -> Void)?
        var drawnStart: [Double] = []
        var drawnCount = 0
        var language: AppLanguage = .ru
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        view.scene = Self.makeScene()
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        view.orbit(around: SIMD3(0, 1.2, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        let coordinator = context.coordinator
        view.onClick = { [weak coordinator, weak view] location in
            guard let coordinator, let view else { return }
            let near = view.unprojectPoint(SCNVector3(location.x, location.y, 0))
            let far = view.unprojectPoint(SCNVector3(location.x, location.y, 1))
            if let found = Self.pickedBelief(truth: coordinator.truth, rayFrom: SIMD3(near), to: SIMD3(far)) {
                coordinator.onPick?(found)
            }
        }
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let root = view.scene?.rootNode else { return }
        let coordinator = context.coordinator
        coordinator.onPick = onPick
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        if coordinator.truth != model.truth {
            coordinator.truth = model.truth
            Self.redrawBowl(truth: model.truth, root: root)
            coordinator.drawnStart = []
        }
        Self.setLabels(root: root, model: model, language: language)
        Self.updateTrail(root: root, model: model, coordinator: coordinator)
        SCNTransaction.commit()

        let ball = root.childNode(withName: "ball", recursively: false)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion || model.steps == 0 ? 0 : 0.05
        ball?.simdPosition = Self.surfacePoint(truth: model.truth, belief: model.belief, lift: 0.2)
        SCNTransaction.commit()
    }

    // MARK: - Fixed parts

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: true, shadowScale: 8, keyPosition: SCNVector3(4.9, 11.8, 5.8))

        // A triangular table under the bowl, a little wider than it. / Треугольный стол под чашей, чуть шире её.
        let outline = NSBezierPath()
        for (index, corner) in corners.enumerated() {
            let point = NSPoint(x: CGFloat(corner.x * 1.28), y: CGFloat(-corner.z * 1.28))
            if index == 0 { outline.move(to: point) } else { outline.line(to: point) }
        }
        outline.close()
        let table = SCNShape(path: outline, extrusionDepth: 0.18)
        table.chamferRadius = 0.05
        table.materials = [TrainingStage.material(NSColor(red: 0.105, green: 0.12, blue: 0.18, alpha: 1))]
        let tableNode = SCNNode(geometry: table)
        tableNode.eulerAngles.x = -CGFloat.pi / 2
        tableNode.position = SCNVector3(0, -0.09, 0)
        scene.rootNode.addChildNode(tableNode)

        let bowl = SCNNode()
        bowl.name = "bowl"
        let grid = SCNNode()
        grid.name = "grid"
        bowl.addChildNode(grid)
        scene.rootNode.addChildNode(bowl)

        let sphere = SCNSphere(radius: 0.2)
        sphere.segmentCount = 28
        let ballMaterial = TrainingStage.material(.white)
        ballMaterial.emission.contents = NSColor(white: 0.35, alpha: 1)
        ballMaterial.specular.contents = NSColor.white
        sphere.materials = [ballMaterial]
        let ball = SCNNode(geometry: sphere)
        ball.name = "ball"
        scene.rootNode.addChildNode(ball)

        let ring = SCNTorus(ringRadius: 0.34, pipeRadius: 0.05)
        ring.materials = [TrainingStage.material(NSColor(red: 0.25, green: 0.95, blue: 0.55, alpha: 1), lit: false)]
        let ringNode = SCNNode(geometry: ring)
        ringNode.name = "truth-ring"
        scene.rootNode.addChildNode(ringNode)

        let trail = SCNNode()
        trail.name = "trail"
        scene.rootNode.addChildNode(trail)

        let names = ["A", "B", "C"]
        for (index, corner) in corners.enumerated() {
            let label = TrainingStage.platedLabel(size: 0.5, color: TrainingStage.text)
            label.name = "corner-\(index)"
            let outward = simd_normalize(corner) * 0.75
            label.simdPosition = corner + outward + SIMD3<Float>(0, Float(Model.heightLimit) * bitHeight + 0.3, 0)
            TrainingStage.setPlatedLabel(label, names[index])
            scene.rootNode.addChildNode(label)
        }
        let bottomLabel = TrainingStage.platedLabel(size: 0.4, color: NSColor(red: 0.45, green: 1, blue: 0.68, alpha: 1))
        bottomLabel.name = "bottom-label"
        scene.rootNode.addChildNode(bottomLabel)

        // The scale of heights stands behind the far corner. / Шкала высот стоит за дальним углом.
        let axisBase = corners[1] + SIMD3<Float>(1.1, 0, 0.3)
        let axisHeight = Float(Model.heightLimit) * bitHeight
        scene.rootNode.addChildNode(TrainingStage.cylinder(from: axisBase, to: axisBase + SIMD3(0, axisHeight, 0), radius: 0.018, material: TrainingStage.material(TrainingStage.dimText, lit: false)))
        for bits in 0...Int(Model.heightLimit) {
            let tick = TrainingStage.label(String(bits), size: 0.3, color: TrainingStage.dimText, weight: .regular)
            tick.simdPosition = axisBase + SIMD3(0.28, Float(bits) * bitHeight, 0)
            scene.rootNode.addChildNode(tick)
        }
        let axisTitle = TrainingStage.label("", size: 0.32, color: TrainingStage.dimText)
        axisTitle.name = "axis-title"
        axisTitle.simdPosition = axisBase + SIMD3(0, axisHeight + 0.45, 0)
        scene.rootNode.addChildNode(axisTitle)

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 70
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 24.6, 21.2)
        cameraNode.look(at: SCNVector3(0, 1.2, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    private static func setLabels(root: SCNNode, model: Model, language: AppLanguage) {
        if let title = root.childNode(withName: "axis-title", recursively: false) {
            TrainingStage.setLabel(title, L10n.text("lab.bowl.axis", language))
        }
        if let label = root.childNode(withName: "bottom-label", recursively: false) {
            TrainingStage.setPlatedLabel(label, String(format: L10n.text("lab.bowl.bottom", language), L10n.number(model.bottom, fractionDigits: 2, language)))
            label.simdPosition = surfacePoint(truth: model.truth, belief: model.truth, lift: 0.85)
        }
    }

    // MARK: - The bowl for a given truth

    private static func redrawBowl(truth: [Double], root: SCNNode) {
        guard let bowl = root.childNode(withName: "bowl", recursively: false) else { return }
        // Vertices by rows of the triangle: row r holds the beliefs with C at r / divisions.
        // Вершины идут рядами треугольника: в ряду r вера в C равна r / divisions.
        let count = divisions
        var top: [SIMD3<Float>] = []
        var colors: [SIMD4<Float>] = []
        var rows: [Int] = []
        let bottom = Model.entropy(truth)
        for row in 0...count {
            rows.append(top.count)
            for column in 0...(count - row) {
                let c = Double(row) / Double(count)
                let b = Double(column) / Double(count)
                let belief = Model.placed([1 - c - b, b, c])
                let error = Model.crossEntropy(truth, belief)
                top.append(surfacePoint(truth: truth, belief: belief))
                let share = max(0, min(1, (error - bottom) / 2.2))
                colors.append(ErrorLandscapeSceneView.errorColor(share * 0.5))
            }
        }
        var indices: [Int32] = []
        var grid: [Int32] = []
        for row in 0..<count {
            for column in 0..<(count - row) {
                let a = Int32(rows[row] + column)
                let b = a + 1
                let c = Int32(rows[row + 1] + column)
                indices += [a, b, c]
                if column < count - row - 1 { indices += [b, c + 1, c] }
                if row % 9 == 0 { grid += [a, b] }
                if column % 9 == 0 { grid += [a, c] }
                if (row + column) % 9 == 8 { grid += [b, c] }
            }
        }
        var normals = [SIMD3<Float>](repeating: .zero, count: top.count)
        for index in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[index]), b = Int(indices[index + 1]), c = Int(indices[index + 2])
            let face = simd_cross(top[b] - top[a], top[c] - top[a])
            normals[a] += face
            normals[b] += face
            normals[c] += face
        }
        normals = normals.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3<Float>(0, 1, 0) }

        // Walls down the three sides, so that the bowl is a solid object. / Стенки по трём сторонам: чаша это цельный предмет.
        var positions = top
        var allNormals = normals
        var allColors = colors
        let sides: [[Int]] = [
            Array(rows[0]...(rows[1] - 1)),
            (0...count).map { rows[$0] },
            (0...count).map { rows[$0] + count - $0 }
        ]
        let centers = sides.map { side in (top[side[0]] + top[side[side.count - 1]]) / 2 }
        for (side, center) in zip(sides, centers) {
            let outward = simd_normalize(SIMD3<Float>(center.x, 0, center.z))
            let base = Int32(positions.count)
            for vertex in side {
                let point = top[vertex]
                let color = colors[vertex]
                positions += [point, SIMD3(point.x, 0, point.z)]
                allNormals += [outward, outward]
                allColors += [SIMD4(color.x * 0.6, color.y * 0.6, color.z * 0.6, 1), SIMD4(color.x * 0.28, color.y * 0.28, color.z * 0.28, 1)]
            }
            for index in 0..<(side.count - 1) {
                let a = base + Int32(index * 2)
                indices += [a, a + 1, a + 2, a + 2, a + 1, a + 3]
            }
        }
        let solid = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: positions.map { SCNVector3($0) }),
                SCNGeometrySource(normals: allNormals.map { SCNVector3($0) }),
                TrainingStage.colorSource(allColors)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.white
        material.lightingModel = .blinn
        material.specular.contents = NSColor(white: 0.22, alpha: 1)
        material.isDoubleSided = true
        solid.materials = [material]
        bowl.geometry = solid

        let lifted = zip(top, normals).map { SCNVector3($0 + $1 * 0.015) }
        let lines = SCNGeometry(
            sources: [SCNGeometrySource(vertices: lifted)],
            elements: [SCNGeometryElement(indices: grid, primitiveType: .line)]
        )
        lines.firstMaterial = TrainingStage.material(NSColor(white: 0, alpha: 0.3), lit: false)
        bowl.childNode(withName: "grid", recursively: false)?.geometry = lines

        root.childNode(withName: "truth-ring", recursively: false)?.simdPosition = surfacePoint(truth: truth, belief: truth, lift: 0.03)
    }

    private static func updateTrail(root: SCNNode, model: Model, coordinator: Coordinator) {
        guard let trail = root.childNode(withName: "trail", recursively: false) else { return }
        if coordinator.drawnStart != model.start || coordinator.drawnCount > model.path.count {
            trail.childNodes.forEach { $0.removeFromParentNode() }
            coordinator.drawnStart = model.start
            coordinator.drawnCount = 1
        }
        let material = TrainingStage.material(NSColor(white: 1, alpha: 0.9), lit: false)
        for index in coordinator.drawnCount..<max(coordinator.drawnCount, model.path.count) {
            trail.addChildNode(TrainingStage.cylinder(
                from: surfacePoint(truth: model.truth, belief: model.path[index - 1], lift: 0.05),
                to: surfacePoint(truth: model.truth, belief: model.path[index], lift: 0.05),
                radius: 0.024,
                material: material
            ))
        }
        coordinator.drawnCount = model.path.count
    }
}
