import SceneKit
import SwiftUI
import simd

/// A true stack of layers as a tower of plates. The error starts at the top and goes down: each plate's brightness and scale
/// show how much of it arrived, and a ball carries it down, along the gold bypass pipes when they are on.
/// Настоящая стопка слоёв как башня плит. Ошибка начинается сверху и идёт вниз: яркость и шкала плиты показывают, сколько её
/// дошло, а шарик несёт её вниз, по золотым обходным трубам, если они включены.
struct GradientTowerSceneView: NSViewRepresentable {
    let model: GradientStackModel
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    typealias Model = GradientStackModel

    private static let plateWidth: CGFloat = 5.2
    private static let plateLength: CGFloat = 3.4
    private static let plateThickness: CGFloat = 0.2
    private static let towerHeight: Float = 9.2
    private static let scaleLength: Float = 3.6
    private static let lowestLog = -7.0
    private static let highestLog = 1.0

    private static func spacing(_ depth: Int) -> Float { towerHeight / Float(max(depth, 6)) }

    /// Where plate number `index` from the bottom stands. / Где стоит плита номер `index` снизу.
    private static func plateCenter(_ index: Int, depth: Int) -> SIMD3<Float> {
        SIMD3<Float>(-1.4, 0.3 + Float(index) * spacing(depth), 0)
    }

    /// The share of the scale for a signal size, on a logarithmic scale. / Доля шкалы для размера сигнала, по логарифму.
    private static func share(_ signal: Double) -> Double {
        let logarithm = log10(max(signal, 1e-12))
        return max(0.02, min(1, (logarithm - lowestLog) / (highestLog - lowestLog)))
    }

    private static func color(_ signal: Double) -> NSColor {
        // A faded signal is a cold dark plate, and a live one glows warm. / Угасший сигнал это холодная тёмная плита, живой светится тепло.
        let t = CGFloat(share(signal))
        let glow: CGFloat = t * t
        let red: CGFloat = 0.13 + 0.87 * glow
        let green: CGFloat = 0.16 + 0.5 * glow
        let blue: CGFloat = 0.3 - 0.12 * t
        return NSColor(red: red, green: green, blue: blue, alpha: 1)
    }

    final class Coordinator: NSObject {
        var model = Model()
        var timer: Timer?
        var reduceMotion = false
        var drawn: (depth: Int, bypass: Bool)?
        weak var scene: SCNScene?

        deinit { timer?.invalidate() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        let scene = Self.makeScene()
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: false)
        view.orbit(around: SIMD3(0.6, 4.6, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        view.rendersContinuously = true
        view.isPlaying = true
        let coordinator = context.coordinator
        coordinator.scene = scene
        coordinator.model = model
        coordinator.reduceMotion = reduceMotion
        let timer = Timer(timeInterval: 2.6, repeats: true) { [weak coordinator] _ in
            guard let coordinator else { return }
            Self.sendError(coordinator: coordinator)
        }
        RunLoop.main.add(timer, forMode: .common)
        coordinator.timer = timer
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let root = view.scene?.rootNode else { return }
        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.reduceMotion = reduceMotion
        if coordinator.drawn?.depth != model.depth || coordinator.drawn?.bypass != model.bypass {
            coordinator.drawn = (model.depth, model.bypass)
            SCNTransaction.begin()
            SCNTransaction.disableActions = true
            Self.redraw(root: root, model: model, language: language)
            SCNTransaction.commit()
            Self.sendError(coordinator: coordinator)
        } else {
            SCNTransaction.begin()
            SCNTransaction.disableActions = true
            Self.setLabels(root: root, model: model, language: language)
            SCNTransaction.commit()
        }
    }

    static func dismantleNSView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.timer?.invalidate()
        coordinator.timer = nil
        view.isPlaying = false
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: true, shadowScale: 9, keyPosition: SCNVector3(4.9, 11.8, 5.8))
        let table = SCNBox(width: 11, height: 0.18, length: 6.2, chamferRadius: 0.09)
        table.materials = [TrainingStage.material(NSColor(red: 0.105, green: 0.12, blue: 0.18, alpha: 1))]
        let tableNode = SCNNode(geometry: table)
        tableNode.position = SCNVector3(0.3, -0.09, 0)
        scene.rootNode.addChildNode(tableNode)

        for name in ["plates", "pipes", "pulses"] {
            let node = SCNNode()
            node.name = name
            scene.rootNode.addChildNode(node)
        }
        for name in ["top-label", "bottom-label"] {
            let label = TrainingStage.platedLabel(size: 0.36, color: TrainingStage.text)
            label.name = name
            scene.rootNode.addChildNode(label)
        }

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 90
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(14, 15.5, 31)
        cameraNode.look(at: SCNVector3(0.6, 4.6, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    private static func redraw(root: SCNNode, model: Model, language: AppLanguage) {
        guard let plates = root.childNode(withName: "plates", recursively: false),
              let pipes = root.childNode(withName: "pipes", recursively: false) else { return }
        plates.childNodes.forEach { $0.removeFromParentNode() }
        pipes.childNodes.forEach { $0.removeFromParentNode() }
        let depth = model.depth
        let metal = TrainingStage.metal(NSColor(white: 0.42, alpha: 1))
        for index in 0..<depth {
            // sizes[0] is the top layer, and the last one is the bottom layer. / sizes[0] это верхний слой, последний это нижний.
            let signal = model.signalSizes[depth - 1 - index]
            let center = plateCenter(index, depth: depth)
            let box = SCNBox(width: plateWidth, height: plateThickness, length: plateLength, chamferRadius: 0.06)
            let material = TrainingStage.metal(color(signal))
            material.emission.contents = color(signal).blended(withFraction: 0.72, of: .black)
            box.materials = [material]
            let plate = SCNNode(geometry: box)
            plate.simdPosition = center
            plates.addChildNode(plate)
            // The scale beside the plate: its length is the size of the signal, in powers of ten.
            // Шкала рядом с плитой: её длина это размер сигнала в степенях десяти.
            let length = Float(share(signal)) * scaleLength
            let bar = SCNBox(width: CGFloat(length), height: plateThickness * 0.8, length: 0.46, chamferRadius: 0.04)
            bar.materials = [material]
            let barNode = SCNNode(geometry: bar)
            barNode.simdPosition = center + SIMD3<Float>(Float(plateWidth) / 2 + 0.12 + length / 2, 0, 0.9)
            plates.addChildNode(barNode)
            if index < depth - 1 {
                let next = plateCenter(index + 1, depth: depth)
                plates.addChildNode(TrainingStage.cylinder(from: center, to: next, radius: 0.13, material: metal))
                if model.bypass { pipes.addChildNode(bypassPipe(from: next, to: center)) }
            }
        }
        setLabels(root: root, model: model, language: language)
    }

    private static func bypassCurve(from top: SIMD3<Float>, to bottom: SIMD3<Float>) -> SceneCurve {
        // On the front side, where the default view sees them. / На передней стороне, которую видно с начального ракурса.
        let front = SIMD3<Float>(-1.2, 0, Float(plateLength) / 2 - 0.1)
        let a = top + front
        let b = bottom + front
        return SceneCurve(start: a, control1: a + SIMD3<Float>(0, 0, 1), control2: b + SIMD3<Float>(0, 0, 1), end: b)
    }

    private static func bypassPipe(from top: SIMD3<Float>, to bottom: SIMD3<Float>) -> SCNNode {
        let geometry = TrainingStage.tube(along: bypassCurve(from: top, to: bottom), radius: 0.075, segments: 20, sides: 10)
        let material = TrainingStage.metal(TrainingStage.trainedWeight)
        material.isDoubleSided = true
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    private static func setLabels(root: SCNNode, model: Model, language: AppLanguage) {
        let depth = model.depth
        if let top = root.childNode(withName: "top-label", recursively: false) {
            TrainingStage.setPlatedLabel(top, L10n.text("lab.tower.topLabel", language))
            top.simdPosition = plateCenter(depth - 1, depth: depth) + SIMD3<Float>(0, 0.72, 0)
        }
        if let bottom = root.childNode(withName: "bottom-label", recursively: false) {
            TrainingStage.setPlatedLabel(bottom, String(format: L10n.text("lab.tower.bottomLabel", language), scientific(model.bottomSignal, language: language)))
            bottom.simdPosition = plateCenter(0, depth: depth) + SIMD3<Float>(Float(plateWidth) / 2 + 2.2, 0.5, 1.8)
        }
    }

    /// A number like 4.6·10⁻⁶, for reading at a glance. / Число вида 4,6·10⁻⁶, чтобы читалось сразу.
    static func scientific(_ value: Double, language: AppLanguage) -> String {
        guard value > 0 else { return "0" }
        if value >= 0.01 && value < 1000 { return L10n.number(value, fractionDigits: 2, language) }
        let power = Int(floor(log10(value)))
        let digits = L10n.number(value / pow(10, Double(power)), fractionDigits: 1, language)
        let superscripts: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"]
        return "\(digits)·10" + String(String(power).map { superscripts[$0] ?? $0 })
    }

    /// The error travels from the top plate to the bottom one, shrinking to the true size at each plate.
    /// Ошибка идёт от верхней плиты к нижней и на каждой плите сжимается до настоящего размера.
    private static func sendError(coordinator: Coordinator) {
        guard !coordinator.reduceMotion, let pulses = coordinator.scene?.rootNode.childNode(withName: "pulses", recursively: false) else { return }
        let model = coordinator.model
        pulses.childNodes.forEach { $0.removeFromParentNode() }
        let sphere = SCNSphere(radius: 0.26)
        sphere.segmentCount = 18
        sphere.materials = [TrainingStage.material(TrainingStage.errorSignal, lit: false)]
        let ball = SCNNode(geometry: sphere)
        ball.castsShadow = false
        let depth = model.depth
        let top = plateCenter(depth - 1, depth: depth) + SIMD3<Float>(0, 0.3, 0)
        ball.simdPosition = top
        var actions: [SCNAction] = []
        let each = 1.9 / Double(max(depth, 1))
        var start = top
        for k in 0..<(depth - 1) {
            let lower = plateCenter(depth - 2 - k, depth: depth)
            let upper = plateCenter(depth - 1 - k, depth: depth)
            let scale = max(0.05, share(model.signalSizes[k + 1]))
            let from = start
            let curve = model.bypass ? bypassCurve(from: upper, to: lower) : nil
            actions.append(.customAction(duration: each) { node, elapsed in
                let t = Float(elapsed / CGFloat(each))
                node.simdPosition = curve?.point(t) ?? from + (lower - from) * t
                let size = CGFloat(scale)
                node.scale = SCNVector3(size, size, size)
            })
            start = lower
        }
        actions.append(.fadeOut(duration: 0.25))
        actions.append(.removeFromParentNode())
        ball.runAction(.sequence(actions))
        pulses.addChildNode(ball)
    }
}
