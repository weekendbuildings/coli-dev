import SceneKit
import SwiftUI
import simd

/// Lets the page keep scrolling over a 3D scene: the wheel goes to the page, a drag turns the scene, a pinch zooms it.
/// Колесо мыши листает страницу, перетаскивание крутит сцену, щипок приближает.
final class LabSceneView: SCNView {
    override func scrollWheel(with event: NSEvent) { nextResponder?.scrollWheel(with: event) }
}

/// Dark stage shared by the training scenes, so the colours read the same in light and dark mode.
enum TrainingStage {
    static let background = NSColor(red: 0.055, green: 0.065, blue: 0.11, alpha: 1)
    static let text = NSColor(white: 0.92, alpha: 1)
    static let dimText = NSColor(white: 0.66, alpha: 1)
    static let forwardSignal = NSColor(red: 0.35, green: 0.85, blue: 1, alpha: 1)
    static let errorSignal = NSColor(red: 1, green: 0.62, blue: 0.2, alpha: 1)

    static func material(_ color: NSColor, lit: Bool = true) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = lit ? .blinn : .constant
        return material
    }

    static func cylinder(from a: SIMD3<Float>, to b: SIMD3<Float>, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let distance = simd_distance(a, b)
        let geometry = SCNCylinder(radius: radius, height: CGFloat(max(distance, 1e-4)))
        geometry.radialSegmentCount = 10
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.simdPosition = (a + b) / 2
        if distance > 1e-6 {
            node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(b - a))
        }
        return node
    }

    static func label(_ string: String, size: Float, color: NSColor = text, weight: NSFont.Weight = .semibold) -> SCNNode {
        let geometry = SCNText(string: string, extrusionDepth: 0)
        geometry.font = .systemFont(ofSize: 1, weight: weight)
        geometry.flatness = 0.03
        geometry.firstMaterial = material(color, lit: false)
        let node = SCNNode(geometry: geometry)
        center(node)
        node.castsShadow = false
        node.scale = SCNVector3(size, size, size)
        node.constraints = [SCNBillboardConstraint()]
        return node
    }

    /// Replaces the text of a label and keeps it centred on its position.
    static func setLabel(_ node: SCNNode, _ string: String) {
        guard let geometry = node.geometry as? SCNText, geometry.string as? String != string else { return }
        geometry.string = string
        center(node)
    }

    private static func center(_ node: SCNNode) {
        let (minimum, maximum) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((minimum.x + maximum.x) / 2, (minimum.y + maximum.y) / 2, 0)
    }

    static func addLights(to scene: SCNScene, shadows: Bool) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 260
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 640
        key.eulerAngles = SCNVector3(-1.0, 0.7, 0)
        if shadows {
            key.light?.castsShadow = true
            key.light?.shadowMode = .forward
            key.light?.shadowSampleCount = 8
            key.light?.shadowRadius = 4
            key.light?.shadowColor = NSColor.black.withAlphaComponent(0.55)
            key.light?.orthographicScale = 7
            key.light?.zNear = 1
            key.light?.zFar = 40
            key.position = SCNVector3(4, 12, -8)
        }
        scene.rootNode.addChildNode(key)
    }
}

/// The true error surface of the XOR network with a ball at its current weights. Click the surface to choose a start.
/// Настоящий рельеф ошибки сети XOR и шарик на её текущих весах. Щелчок по рельефу ставит старт.
struct ErrorLandscapeSceneView: NSViewRepresentable {
    let model: ErrorLandscapeModel
    let learningRate: Double
    let language: AppLanguage
    let onPick: (ErrorLandscapeModel.Point) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One scene unit is two weight units, and an error of 0.5 stands 4.5 units high.
    static let horizontalScale = 0.5
    static let verticalScale = 9.0

    static func scenePoint(_ point: ErrorLandscapeModel.Point, lift: Double = 0) -> SIMD3<Float> {
        let height = ErrorLandscapeModel.loss(at: point) * verticalScale + lift
        return SIMD3(Float(point.w11 * horizontalScale), Float(height), Float(-point.w12 * horizontalScale))
    }

    /// Walks along the view ray until it drops below the true surface, so a click lands where the error really is.
    /// Идём вдоль луча взгляда, пока он не уйдёт под настоящую поверхность: щелчок попадает точно в рельеф.
    static func terrainPoint(rayFrom near: SIMD3<Float>, to far: SIMD3<Float>) -> ErrorLandscapeModel.Point? {
        let length = simd_distance(near, far)
        guard length > 0 else { return nil }
        let direction = (far - near) / length
        var travelled: Float = 0
        while travelled < length {
            let point = near + direction * travelled
            let weights = ErrorLandscapeModel.Point(w11: Double(point.x) / horizontalScale, w12: -Double(point.z) / horizontalScale)
            if ErrorLandscapeModel.domain.contains(weights.w11), ErrorLandscapeModel.domain.contains(weights.w12),
               Double(point.y) <= ErrorLandscapeModel.loss(at: weights) * verticalScale {
                return weights
            }
            travelled += 0.02
        }
        return nil
    }

    final class Coordinator: NSObject {
        var onPick: ((ErrorLandscapeModel.Point) -> Void)?
        var language: AppLanguage?
        var drawnStart: ErrorLandscapeModel.Point?
        var drawnCount = 0
        var lastDrawn: ErrorLandscapeModel.Point?

        @objc func handleClick(_ recognizer: NSClickGestureRecognizer) {
            guard let view = recognizer.view as? SCNView else { return }
            let location = recognizer.location(in: view)
            let near = view.unprojectPoint(SCNVector3(location.x, location.y, 0))
            let far = view.unprojectPoint(SCNVector3(location.x, location.y, 1))
            if let point = ErrorLandscapeSceneView.terrainPoint(rayFrom: SIMD3(near), to: SIMD3(far)) { onPick?(point) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        view.scene = Self.makeScene(language: language)
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        context.coordinator.language = language
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.target = SCNVector3(0, 1.1, 0)
        view.defaultCameraController.inertiaEnabled = !reduceMotion
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        view.addGestureRecognizer(click)
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onPick = onPick
        if coordinator.language != language {
            // The terrace and axis labels are baked into the scene. / Подписи вшиты в сцену, поэтому пересобираем её.
            let camera = view.pointOfView?.simdTransform
            view.scene = Self.makeScene(language: language)
            view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
            if let camera { view.pointOfView?.simdTransform = camera }
            coordinator.language = language
            coordinator.drawnStart = nil
        }
        guard let scene = view.scene else { return }
        update(scene: scene, coordinator: coordinator)
    }

    // MARK: - Dynamic part

    private func update(scene: SCNScene, coordinator: Coordinator) {
        guard let root = scene.rootNode.childNode(withName: "dynamic", recursively: false),
              let trail = root.childNode(withName: "trail", recursively: false),
              let ball = root.childNode(withName: "ball", recursively: false),
              let startMarker = root.childNode(withName: "start", recursively: false),
              let arrow = root.childNode(withName: "arrow", recursively: false) else { return }

        let restarted = coordinator.drawnStart != model.start || coordinator.drawnCount > model.path.count
        if restarted {
            trail.childNodes.forEach { $0.removeFromParentNode() }
            coordinator.drawnStart = model.start
            coordinator.drawnCount = 1
            coordinator.lastDrawn = model.start
            startMarker.simdPosition = Self.scenePoint(model.start, lift: 0.04)
        }

        // Only new pieces of the path are added, so a long run stays cheap.
        let trailMaterial = TrainingStage.material(NSColor(white: 1, alpha: 0.9), lit: false)
        for index in coordinator.drawnCount..<max(coordinator.drawnCount, model.path.count) {
            let point = model.path[index]
            let inside = ErrorLandscapeModel.domain.contains(point.w11) && ErrorLandscapeModel.domain.contains(point.w12)
            guard inside, let last = coordinator.lastDrawn,
                  abs(point.w11 - last.w11) + abs(point.w12 - last.w12) > 0.05 else { continue }
            trail.addChildNode(TrainingStage.cylinder(
                from: Self.scenePoint(last, lift: 0.05),
                to: Self.scenePoint(point, lift: 0.05),
                radius: 0.022,
                material: trailMaterial
            ))
            coordinator.lastDrawn = point
        }
        coordinator.drawnCount = model.path.count

        let animate = !restarted && !reduceMotion && model.iterations > 0
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animate ? 0.05 : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .linear)
        ball.simdPosition = Self.scenePoint(model.ballPosition, lift: 0.24)
        SCNTransaction.commit()

        updateArrow(arrow)
    }

    /// Shows the next step: the direction −∇L, with a length proportional to the step in weights.
    private func updateArrow(_ arrow: SCNNode) {
        arrow.childNodes.forEach { $0.removeFromParentNode() }
        guard model.isOnTerrain, !model.isFinished else { return }
        let slope = model.gradient
        let stepLength = learningRate * (slope.x * slope.x + slope.y * slope.y).squareRoot()
        let visibleLength = min(1.6, stepLength * 6 * Self.horizontalScale)
        guard visibleLength > 0.12 else { return }
        let direction = SIMD3<Float>(Float(-slope.x), 0, Float(slope.y))
        let unit = simd_normalize(direction)
        let origin = Self.scenePoint(model.ballPosition, lift: 0.24)
        let tip = origin + unit * Float(visibleLength)
        let headStart = origin + unit * Float(max(0, visibleLength - 0.22))
        let color = NSColor(red: 1, green: 0.95, blue: 0.4, alpha: 1)
        let shaft = TrainingStage.cylinder(from: origin, to: headStart, radius: 0.035, material: TrainingStage.material(color, lit: false))
        let head = SCNCone(topRadius: 0, bottomRadius: 0.1, height: 0.22)
        head.materials = [TrainingStage.material(color, lit: false)]
        let headNode = SCNNode(geometry: head)
        headNode.simdPosition = (headStart + tip) / 2
        headNode.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: unit)
        for node in [shaft, headNode] {
            node.renderingOrder = 110
            node.geometry?.materials.forEach { $0.readsFromDepthBuffer = false }
            arrow.addChildNode(node)
        }
    }

    // MARK: - Static part

    private static func makeScene(language: AppLanguage) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        if let mesh = meshCache {
            scene.rootNode.addChildNode(surfaceNode(mesh))
            scene.rootNode.addChildNode(gridNode(mesh))
        }
        scene.rootNode.addChildNode(floorNode(language: language))
        scene.rootNode.addChildNode(terraceLabels(language: language))
        TrainingStage.addLights(to: scene, shadows: true)

        let camera = SCNCamera()
        // The width is what must fit, so the view angle is set horizontally. From this corner the plateau is on the
        // left, the valley on the right, and one shelf in front. / С этого угла плато слева, долина справа, полка впереди.
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 43
        camera.zNear = 0.1
        camera.zFar = 60
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(10.2, 9.2, 10.2)
        cameraNode.look(at: SCNVector3(0, 1.1, 0))
        scene.rootNode.addChildNode(cameraNode)

        let dynamic = SCNNode()
        dynamic.name = "dynamic"
        let trail = SCNNode()
        trail.name = "trail"
        dynamic.addChildNode(trail)
        let ballGeometry = SCNSphere(radius: 0.24)
        let ballMaterial = TrainingStage.material(.white)
        ballMaterial.emission.contents = NSColor(white: 0.35, alpha: 1)
        ballMaterial.specular.contents = NSColor.white
        ballGeometry.materials = [ballMaterial]
        let ball = SCNNode(geometry: ballGeometry)
        ball.name = "ball"
        ball.castsShadow = true
        dynamic.addChildNode(ball)
        let marker = SCNTorus(ringRadius: 0.24, pipeRadius: 0.035)
        marker.materials = [TrainingStage.material(NSColor(white: 1, alpha: 0.85), lit: false)]
        let start = SCNNode(geometry: marker)
        start.name = "start"
        dynamic.addChildNode(start)
        let arrow = SCNNode()
        arrow.name = "arrow"
        dynamic.addChildNode(arrow)
        scene.rootNode.addChildNode(dynamic)
        return scene
    }

    /// The mesh takes about 20 000 network evaluations, so it is built once.
    private static let meshCache = ErrorLandscapeModel.surfaceMesh(
        resolution: 96,
        heightScale: verticalScale / horizontalScale
    )

    private static func toScene(_ point: SIMD3<Double>) -> SCNVector3 {
        SCNVector3(Float(point.x * horizontalScale), Float(point.z * horizontalScale), Float(-point.y * horizontalScale))
    }

    /// Green in the valley of right answers, amber on the shelf with one wrong answer, red on the plateau with two.
    static func errorColor(_ error: Double) -> SIMD4<Float> {
        let valley = SIMD3<Float>(0.05, 0.72, 0.56)
        let shelf = SIMD3<Float>(0.96, 0.72, 0.20)
        let plateau = SIMD3<Float>(0.82, 0.20, 0.32)
        let share = Float(max(0, min(1, error / 0.5)))
        let rgb = share < 0.5 ? valley + (shelf - valley) * (share / 0.5) : shelf + (plateau - shelf) * ((share - 0.5) / 0.5)
        return SIMD4(rgb.x, rgb.y, rgb.z, 1)
    }

    private static func surfaceNode(_ mesh: SurfaceMesh) -> SCNNode {
        var colorData = Data(capacity: mesh.positions.count * 16)
        let heightScale = verticalScale / horizontalScale
        for position in mesh.positions {
            var rgba = errorColor(position.z / heightScale)
            withUnsafeBytes(of: &rgba) { colorData.append(contentsOf: $0) }
        }
        let colors = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: mesh.positions.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        let normals = mesh.normals.map { SCNVector3(Float($0.x), Float($0.z), Float(-$0.y)) }
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: mesh.positions.map(toScene)), SCNGeometrySource(normals: normals), colors],
            elements: [SCNGeometryElement(indices: mesh.triangleIndices, primitiveType: .triangles)]
        )
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.white
        material.lightingModel = .blinn
        material.specular.contents = NSColor(white: 0.18, alpha: 1)
        material.isDoubleSided = true
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = "landscape-surface"
        return node
    }

    private static func gridNode(_ mesh: SurfaceMesh) -> SCNNode {
        // Lifted a little along the normal so the lines do not flicker against the surface.
        let lifted = zip(mesh.positions, mesh.normals).map { toScene($0 + $1 * 0.03) }
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: lifted)],
            elements: [SCNGeometryElement(indices: mesh.gridLineIndices, primitiveType: .line)]
        )
        geometry.firstMaterial = TrainingStage.material(NSColor(white: 0, alpha: 0.28), lit: false)
        return SCNNode(geometry: geometry)
    }

    private static func floorNode(language: AppLanguage) -> SCNNode {
        let node = SCNNode()
        let lineMaterial = TrainingStage.material(NSColor(white: 1, alpha: 0.22), lit: false)
        let reach = Float(ErrorLandscapeModel.domain.upperBound * horizontalScale)
        let ticks = [-8.0, -4.0, 0.0, 4.0, 8.0]
        for tick in ticks {
            let t = Float(tick * horizontalScale)
            node.addChildNode(TrainingStage.cylinder(from: SIMD3(t, -0.03, -reach), to: SIMD3(t, -0.03, reach), radius: 0.006, material: lineMaterial))
            node.addChildNode(TrainingStage.cylinder(from: SIMD3(-reach, -0.03, t), to: SIMD3(reach, -0.03, t), radius: 0.006, material: lineMaterial))
            let text = L10n.number(tick, fractionDigits: 0, language)
            let alongFirst = TrainingStage.label(text, size: 0.27, color: TrainingStage.dimText, weight: .regular)
            alongFirst.position = SCNVector3(t, 0.02, reach + 0.38)
            node.addChildNode(alongFirst)
            let alongSecond = TrainingStage.label(text, size: 0.27, color: TrainingStage.dimText, weight: .regular)
            alongSecond.position = SCNVector3(reach + 0.35, 0.02, -t)
            node.addChildNode(alongSecond)
        }
        let firstAxis = TrainingStage.label("w₁₁", size: 0.38)
        firstAxis.position = SCNVector3(0, 0.02, reach + 0.85)
        node.addChildNode(firstAxis)
        let secondAxis = TrainingStage.label("w₁₂", size: 0.38)
        secondAxis.position = SCNVector3(reach + 0.85, 0.02, 0)
        node.addChildNode(secondAxis)

        // The height axis stands at the valley corner, where nothing hides it. / Ось высоты в углу долины: её ничто не закрывает.
        let axisBase = SIMD3<Float>(reach, 0, -reach)
        let axisHeight = Float(0.5 * verticalScale)
        node.addChildNode(TrainingStage.cylinder(from: axisBase, to: axisBase + SIMD3(0, axisHeight, 0), radius: 0.012, material: TrainingStage.material(TrainingStage.dimText, lit: false)))
        for error in [0.0, 0.25, 0.5] {
            let height = Float(error * verticalScale)
            let text = L10n.number(error, fractionDigits: error == 0 ? 0 : 2, language)
            let label = TrainingStage.label(text, size: 0.27, color: TrainingStage.dimText, weight: .regular)
            label.simdPosition = axisBase + SIMD3(-0.4, height, -0.1)
            node.addChildNode(label)
        }
        let title = TrainingStage.label(L10n.text("lab.landscape.axisError", language), size: 0.33)
        title.simdPosition = axisBase + SIMD3(-0.75, axisHeight + 0.38, 0)
        node.addChildNode(title)
        return node
    }

    private static func terraceLabels(language: AppLanguage) -> SCNNode {
        let node = SCNNode()
        for terrace in ErrorLandscapeModel.terraces {
            let key: String
            switch terrace.wrongAnswers {
            case 0: key = "lab.landscape.terraceValley"
            case 1: key = "lab.landscape.terraceShelf"
            default: key = "lab.landscape.terracePlateau"
            }
            let label = TrainingStage.label(L10n.text(key, language), size: 0.34)
            label.simdPosition = scenePoint(terrace.point, lift: 0.45)
            // Stay readable even behind a cliff. / Видны и за обрывом.
            label.renderingOrder = 100
            label.geometry?.firstMaterial?.readsFromDepthBuffer = false
            node.addChildNode(label)
        }
        return node
    }
}

/// The same network as a 3D graph: signals run forward through it, and while it trains the error runs back along the
/// two trainable weights. Everything shown is computed from the current weights.
/// Та же сеть в 3D: сигналы бегут вперёд, а при обучении ошибка бежит назад по двум обучаемым весам.
struct TrainingNetworkSceneView: NSViewRepresentable {
    let weights: [Double]
    let training: Bool
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let inputs = [SIMD3<Float>(-3.1, 1.25, 0), SIMD3<Float>(-3.1, -1.25, 0)]
    private static let hidden = [SIMD3<Float>(0, 1.7, 0.7), SIMD3<Float>(0, -1.7, -0.7)]
    private static let output = SIMD3<Float>(3.1, 0, 0)
    private static let forwardDuration: TimeInterval = 0.5
    private static let backwardDuration: TimeInterval = 0.32
    private static let cycle: TimeInterval = 1.9

    final class Coordinator: NSObject {
        var weights: [Double] = []
        var training = false
        var reduceMotion = false
        var language: AppLanguage = .ru
        var example = 0
        var timer: Timer?
        weak var scene: SCNScene?

        deinit { timer?.invalidate() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        let scene = Self.makeScene()
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: false)
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.target = SCNVector3(0, 0, 0)
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        view.rendersContinuously = true
        view.isPlaying = true

        let coordinator = context.coordinator
        coordinator.scene = scene
        coordinator.weights = weights
        coordinator.training = training
        coordinator.reduceMotion = reduceMotion
        coordinator.language = language
        Self.updateEdges(scene: scene, weights: weights, language: language)
        Self.showExample(coordinator: coordinator)
        let timer = Timer(timeInterval: Self.cycle, repeats: true) { [weak coordinator] _ in
            guard let coordinator else { return }
            coordinator.example = (coordinator.example + 1) % XORNetworkModel.examples.count
            Self.showExample(coordinator: coordinator)
        }
        RunLoop.main.add(timer, forMode: .common)
        coordinator.timer = timer
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.training = training
        coordinator.reduceMotion = reduceMotion
        guard let scene = view.scene else { return }
        if coordinator.weights != weights || coordinator.language != language {
            coordinator.weights = weights
            coordinator.language = language
            Self.updateEdges(scene: scene, weights: weights, language: language)
            Self.updateActivations(coordinator: coordinator)
        }
    }

    static func dismantleNSView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.timer?.invalidate()
        coordinator.timer = nil
        view.isPlaying = false
    }

    private static func network(_ weights: [Double]) -> XORNetworkModel {
        var network = XORNetworkModel(architecture: .hiddenLayer, start: .first)
        network.weights = weights
        return network
    }

    // MARK: - Scene

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: false)

        let edges = SCNNode()
        edges.name = "edges"
        scene.rootNode.addChildNode(edges)

        let names = ["x1", "x2", "h1", "h2", "y"]
        for (name, position) in zip(names, inputs + hidden + [output]) {
            let sphere = SCNSphere(radius: 0.46)
            sphere.segmentCount = 32
            sphere.materials = [TrainingStage.material(.darkGray)]
            let node = SCNNode(geometry: sphere)
            node.name = name
            node.simdPosition = position
            scene.rootNode.addChildNode(node)
            let label = TrainingStage.label("", size: 0.36)
            label.name = name + "-label"
            // x₂ and h₂ are labelled below, so that the labels do not meet the upper edges. / Подписи снизу, чтобы не лечь на рёбра.
            let below = name == "x2" || name == "h2"
            label.simdPosition = position + SIMD3(name == "x1" ? -0.4 : 0, below ? -0.78 : 0.78, 0)
            scene.rootNode.addChildNode(label)
        }
        for name in ["w11", "w12"] {
            let label = TrainingStage.label("", size: 0.34, color: NSColor(red: 1, green: 0.95, blue: 0.4, alpha: 1))
            label.name = name + "-label"
            scene.rootNode.addChildNode(label)
        }
        let target = TrainingStage.label("", size: 0.32)
        target.name = "target-label"
        target.simdPosition = output + SIMD3(0, -0.78, 0)
        scene.rootNode.addChildNode(target)

        let pulses = SCNNode()
        pulses.name = "pulses"
        scene.rootNode.addChildNode(pulses)

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 37
        camera.zNear = 0.1
        camera.zFar = 60
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(1.7, 1.2, 12.2)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    /// Thickness shows the size of a weight and colour its sign, as in the lab above: blue is positive, red negative.
    private static func updateEdges(scene: SCNScene, weights w: [Double], language: AppLanguage) {
        guard let edges = scene.rootNode.childNode(withName: "edges", recursively: false) else { return }
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        edges.childNodes.forEach { $0.removeFromParentNode() }
        let connections: [(SIMD3<Float>, SIMD3<Float>, Double, Bool)] = [
            (inputs[0], hidden[0], w[0], true), (inputs[1], hidden[0], w[1], true),
            (inputs[0], hidden[1], w[3], false), (inputs[1], hidden[1], w[4], false),
            (hidden[0], output, w[6], false), (hidden[1], output, w[7], false)
        ]
        for (start, end, weight, trainable) in connections {
            let alpha: CGFloat = trainable ? 1 : 0.42
            let color = weight >= 0
                ? NSColor(red: 0.3, green: 0.55, blue: 1, alpha: alpha)
                : NSColor(red: 1, green: 0.32, blue: 0.32, alpha: alpha)
            let radius = CGFloat(0.018 + 0.012 * min(abs(weight), 10))
            edges.addChildNode(TrainingStage.cylinder(from: start, to: end, radius: radius, material: TrainingStage.material(color)))
            if trainable {
                // Bright rings mark the two weights that are being trained. / Яркие кольца выделяют два обучаемых веса.
                let bright = NSColor(red: 1, green: 0.95, blue: 0.4, alpha: 1)
                for share: Float in [0.3, 0.5, 0.7] {
                    let ring = SCNTorus(ringRadius: radius + 0.05, pipeRadius: 0.026)
                    ring.materials = [TrainingStage.material(bright, lit: false)]
                    let node = SCNNode(geometry: ring)
                    node.simdPosition = start + (end - start) * share
                    node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(end - start))
                    edges.addChildNode(node)
                }
            }
        }
        for (index, name) in ["w11", "w12"].enumerated() {
            guard let label = scene.rootNode.childNode(withName: name + "-label", recursively: false) else { continue }
            let title = index == 0 ? "w₁₁" : "w₁₂"
            TrainingStage.setLabel(label, "\(title) = " + L10n.number(w[index], fractionDigits: 1, language))
            label.simdPosition = index == 0 ? SIMD3(-1.85, 2.25, 0.5) : SIMD3(0.35, 0.55, 0.5)
        }
        SCNTransaction.commit()
    }

    /// Glow shows how strongly a neuron fires on the current example.
    private static func setActivation(_ name: String, value: Double, scene: SCNScene) {
        guard let material = scene.rootNode.childNode(withName: name, recursively: false)?.geometry?.firstMaterial else { return }
        let share = CGFloat(max(0, min(1, value)))
        material.diffuse.contents = NSColor(red: 0.16 + 0.8 * share, green: 0.2 + 0.68 * share, blue: 0.36 - 0.1 * share, alpha: 1)
        material.emission.contents = NSColor(white: 0.38 * share, alpha: 1)
    }

    private static func updateActivations(coordinator: Coordinator) {
        guard let scene = coordinator.scene else { return }
        let example = XORNetworkModel.examples[coordinator.example]
        let result = network(coordinator.weights).forward(example.x1, example.x2)
        let language = coordinator.language
        func number(_ value: Double) -> String { L10n.number(value, fractionDigits: 2, language) }
        let values: [(String, String, Double)] = [
            ("x1", "x₁ = \(Int(example.x1))", example.x1),
            ("x2", "x₂ = \(Int(example.x2))", example.x2),
            ("h1", "h₁ = " + number(result.firstHidden), result.firstHidden),
            ("h2", "h₂ = " + number(result.secondHidden), result.secondHidden),
            ("y", "y = " + number(result.answer), result.answer)
        ]
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        for (name, text, value) in values {
            setActivation(name, value: value, scene: scene)
            if let label = scene.rootNode.childNode(withName: name + "-label", recursively: false) { TrainingStage.setLabel(label, text) }
        }
        if let target = scene.rootNode.childNode(withName: "target-label", recursively: false) {
            TrainingStage.setLabel(target, String(format: L10n.text("lab.landscape.target", language), String(Int(example.target))))
        }
        SCNTransaction.commit()
    }

    // MARK: - Signals

    private static func showExample(coordinator: Coordinator) {
        updateActivations(coordinator: coordinator)
        guard !coordinator.reduceMotion, let scene = coordinator.scene,
              let pulses = scene.rootNode.childNode(withName: "pulses", recursively: false) else { return }
        let example = XORNetworkModel.examples[coordinator.example]
        let w = coordinator.weights
        let result = network(w).forward(example.x1, example.x2)
        let x = [example.x1, example.x2]

        // Forward: a signal is as strong as the neuron that sends it, so an input of 0 sends nothing.
        for input in 0..<2 {
            for target in 0..<2 {
                pulse(in: pulses, from: inputs[input], to: hidden[target], color: TrainingStage.forwardSignal, strength: x[input], delay: 0, duration: forwardDuration)
            }
        }
        pulse(in: pulses, from: hidden[0], to: output, color: TrainingStage.forwardSignal, strength: result.firstHidden, delay: forwardDuration, duration: forwardDuration)
        pulse(in: pulses, from: hidden[1], to: output, color: TrainingStage.forwardSignal, strength: result.secondHidden, delay: forwardDuration, duration: forwardDuration)

        guard coordinator.training else { return }
        // Backward, by the chain rule: out = 2(y − t) · y(1 − y), then out · v₁ · h₁(1 − h₁) reaches the trainable weights.
        // On a plateau these numbers are almost zero, so no pulse appears: the gradient has vanished.
        let y = result.answer, h = result.firstHidden
        let out = 2 * (y - example.target) * y * (1 - y)
        let back = out * w[6] * h * (1 - h)
        let backDelay = 2 * forwardDuration + 0.02
        pulse(in: pulses, from: output, to: hidden[0], color: TrainingStage.errorSignal, strength: min(1, abs(back) * 12), delay: backDelay, duration: backwardDuration)
        for input in 0..<2 {
            pulse(in: pulses, from: hidden[0], to: inputs[input], color: TrainingStage.errorSignal, strength: min(1, abs(back * x[input]) * 12), delay: backDelay + backwardDuration, duration: backwardDuration)
        }
    }

    private static func pulse(in parent: SCNNode, from start: SIMD3<Float>, to end: SIMD3<Float>, color: NSColor,
                              strength: Double, delay: TimeInterval, duration: TimeInterval) {
        guard strength > 0.04 else { return }
        let sphere = SCNSphere(radius: CGFloat(0.07 + 0.1 * strength))
        sphere.segmentCount = 16
        let material = TrainingStage.material(color, lit: false)
        sphere.materials = [material]
        let node = SCNNode(geometry: sphere)
        node.simdPosition = start
        node.opacity = 0
        node.runAction(.sequence([
            .wait(duration: delay),
            .fadeIn(duration: 0.03),
            .move(to: SCNVector3(end), duration: duration),
            .removeFromParentNode()
        ]))
        parent.addChildNode(node)
    }
}
