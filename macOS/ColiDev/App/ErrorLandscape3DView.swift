import SceneKit
import SwiftUI
import simd

/// A 3D scene inside a lesson page. A drag turns it around its centre, a pinch brings it closer, a click stays a click,
/// and the wheel goes to the page, so the lesson keeps scrolling.
/// 3D-сцена на странице урока. Перетаскивание крутит её вокруг центра, щипок приближает, щелчок остаётся щелчком,
/// а колесо листает страницу.
final class LabSceneView: SCNView {
    var onClick: ((CGPoint) -> Void)?
    private var target = SIMD3<Float>(repeating: 0)
    private var yaw: Float = 0
    private var pitch: Float = 0
    private var distance: Float = 10
    private var homeDistance: Float = 10
    private var lastPoint: CGPoint?
    private var pressPoint: CGPoint?
    private var dragged = false

    /// Starts turning around `target` from where the camera stands now. / Начинает вращение вокруг цели с текущего места камеры.
    func orbit(around target: SIMD3<Float>) {
        self.target = target
        guard let camera = pointOfView else { return }
        let offset = camera.simdPosition - target
        distance = simd_length(offset)
        homeDistance = distance
        yaw = atan2(offset.x, offset.z)
        pitch = asin(offset.y / distance)
    }

    private func applyOrbit() {
        guard let camera = pointOfView else { return }
        let height = sin(pitch)
        let around = SIMD3<Float>(sin(yaw) * cos(pitch), height, cos(yaw) * cos(pitch))
        camera.simdPosition = target + around * distance
        camera.simdLook(at: target)
    }

    override func scrollWheel(with event: NSEvent) { nextResponder?.scrollWheel(with: event) }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        pressPoint = point
        lastPoint = point
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pressPoint, let lastPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        if !dragged {
            // A small shake of the hand is still a click. / Лёгкое дрожание руки это ещё щелчок.
            guard hypot(point.x - pressPoint.x, point.y - pressPoint.y) > 3 else { return }
            dragged = true
        }
        // The view is not flipped: y grows upwards, so a drag down raises the camera.
        yaw -= Float(point.x - lastPoint.x) * 0.005
        pitch = min(1.45, max(0.08, pitch - Float(point.y - lastPoint.y) * 0.004))
        self.lastPoint = point
        applyOrbit()
    }

    override func mouseUp(with event: NSEvent) {
        if pressPoint != nil, !dragged { onClick?(convert(event.locationInWindow, from: nil)) }
        pressPoint = nil
        lastPoint = nil
    }

    override func magnify(with event: NSEvent) {
        distance = min(homeDistance * 1.5, max(homeDistance * 0.45, distance * (1 - Float(event.magnification))))
        applyOrbit()
    }
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
        let (minimum, maximum) = node.geometry?.boundingBox ?? node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((minimum.x + maximum.x) / 2, (minimum.y + maximum.y) / 2, 0)
    }

    static func addLights(to scene: SCNScene, shadows: Bool, shadowScale: CGFloat = 7, keyPosition: SCNVector3 = SCNVector3(4, 12, -8)) {
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
            key.light?.orthographicScale = shadowScale
            key.light?.zNear = 1
            key.light?.zFar = 40
            key.position = keyPosition
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

        func pick(at location: CGPoint, in view: SCNView) {
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
        view.orbit(around: SIMD3(0, 1.1, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        let coordinator = context.coordinator
        view.onClick = { [weak coordinator, weak view] location in
            guard let coordinator, let view else { return }
            coordinator.pick(at: location, in: view)
        }
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
        camera.fieldOfView = 30
        camera.zNear = 1
        camera.zFar = 70
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(17, 14.6, 17)
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
        let heightScale = verticalScale / horizontalScale
        let geometry = TrainingStage.closedSurface(
            top: mesh.positions.map { SIMD3<Float>(toScene($0)) },
            normals: mesh.normals.map { SIMD3<Float>(Float($0.x), Float($0.z), Float(-$0.y)) },
            colors: mesh.positions.map { errorColor($0.z / heightScale) },
            triangles: mesh.triangleIndices,
            resolution: mesh.resolution
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
