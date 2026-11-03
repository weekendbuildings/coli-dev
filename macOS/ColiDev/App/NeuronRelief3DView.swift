import SceneKit
import SwiftUI
import simd

/// A smooth curve in a 3D scene: wires run along it and signals travel on it.
/// Плавная кривая в 3D: по ней идут провода и бегут сигналы.
struct SceneCurve {
    let start: SIMD3<Float>
    let control1: SIMD3<Float>
    let control2: SIMD3<Float>
    let end: SIMD3<Float>

    func point(_ t: Float) -> SIMD3<Float> {
        let u = 1 - t
        let first = start * (u * u * u)
        let second = control1 * (3 * u * u * t)
        let third = control2 * (3 * u * t * t)
        let fourth = end * (t * t * t)
        return first + second + third + fourth
    }

    func tangent(_ t: Float) -> SIMD3<Float> {
        let u = 1 - t
        let first = (control1 - start) * (3 * u * u)
        let second = (control2 - control1) * (6 * u * t)
        let third = (end - control2) * (3 * t * t)
        return simd_normalize(first + second + third)
    }
}

/// Solid parts shared by the 3D scenes of the AI path. / Объёмные детали, общие для 3D-сцен пути ИИ.
extension TrainingStage {
    static let trainedWeight = NSColor(red: 1, green: 0.84, blue: 0.3, alpha: 1)

    static func metal(_ color: NSColor) -> SCNMaterial {
        let material = TrainingStage.material(color)
        material.specular.contents = NSColor(white: 0.75, alpha: 1)
        material.shininess = 0.6
        return material
    }

    static func colorSource(_ colors: [SIMD4<Float>]) -> SCNGeometrySource {
        SCNGeometrySource(
            data: colors.withUnsafeBytes { Data($0) },
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
    }

    /// A label on a dark plate, readable over a bright relief and even behind a block.
    /// Подпись на тёмной плашке: читается и на ярком рельефе, и за блоком.
    static func platedLabel(size: Float, color: NSColor) -> SCNNode {
        let label = TrainingStage.label("", size: size, color: color)
        label.renderingOrder = 100
        label.geometry?.firstMaterial?.readsFromDepthBuffer = false
        let backing = TrainingStage.material(NSColor(red: 0.05, green: 0.06, blue: 0.1, alpha: 0.76), lit: false)
        backing.readsFromDepthBuffer = false
        backing.writesToDepthBuffer = false
        let shape = SCNPlane(width: 1, height: 1)
        shape.materials = [backing]
        let plate = SCNNode(geometry: shape)
        plate.name = "plate"
        plate.renderingOrder = 99
        plate.castsShadow = false
        label.addChildNode(plate)
        return label
    }

    static func setPlatedLabel(_ node: SCNNode, _ string: String) {
        setLabel(node, string)
        guard let text = node.geometry, let plate = node.childNode(withName: "plate", recursively: false),
              let shape = plate.geometry as? SCNPlane else { return }
        let (minimum, maximum) = text.boundingBox
        shape.width = (maximum.x - minimum.x) + 0.55
        shape.height = (maximum.y - minimum.y) + 0.22
        shape.cornerRadius = 0.22
        plate.position = SCNVector3((minimum.x + maximum.x) / 2, (minimum.y + maximum.y) / 2, -0.01)
    }

    /// A round tube along a curve, with real normals, so a wire looks like a cable and not like a line.
    static func tube(along curve: SceneCurve, radius: Float, segments: Int = 28, sides: Int = 12) -> SCNGeometry {
        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        positions.reserveCapacity((segments + 1) * sides)
        normals.reserveCapacity((segments + 1) * sides)
        for index in 0...segments {
            let t = Float(index) / Float(segments)
            let center = curve.point(t)
            let forward = curve.tangent(t)
            let across = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
            let up = simd_cross(across, forward)
            for corner in 0..<sides {
                let angle = Float(corner) / Float(sides) * 2 * Float.pi
                let sideways: SIMD3<Float> = across * cos(angle)
                let upward: SIMD3<Float> = up * sin(angle)
                let normal: SIMD3<Float> = sideways + upward
                normals.append(SCNVector3(normal))
                positions.append(SCNVector3(center + normal * radius))
            }
        }
        var indices: [Int32] = []
        indices.reserveCapacity(segments * sides * 6)
        for index in 0..<segments {
            for corner in 0..<sides {
                let a = Int32(index * sides + corner)
                let b = Int32(index * sides + (corner + 1) % sides)
                let c = a + Int32(sides)
                let d = b + Int32(sides)
                indices += [a, c, b, b, c, d]
            }
        }
        return SCNGeometry(
            sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
    }

    /// Answer 0 is deep indigo, 0.5 teal, and 1 warm yellow, in the same order for every neuron.
    static func answerColor(_ answer: Double) -> SIMD4<Float> {
        let low = SIMD3<Float>(0.17, 0.11, 0.46)
        let middle = SIMD3<Float>(0.07, 0.56, 0.60)
        let high = SIMD3<Float>(0.99, 0.84, 0.25)
        let share = Float(max(0, min(1, answer)))
        let rgb: SIMD3<Float>
        if share < 0.5 {
            rgb = low + (middle - low) * (share / 0.5)
        } else {
            rgb = middle + (high - middle) * ((share - 0.5) / 0.5)
        }
        return SIMD4(rgb.x, rgb.y, rgb.z, 1)
    }

    /// A height surface closed by walls down to height 0, so it stays a solid object from every side. The rows run from
    /// the front (+z) to the back (−z), and the columns from left to right.
    /// Поверхность, закрытая стенками до нулевой высоты: со всех сторон это цельный предмет.
    static func closedSurface(top: [SIMD3<Float>], normals topNormals: [SIMD3<Float>], colors topColors: [SIMD4<Float>],
                              triangles: [Int32], resolution: Int) -> SCNGeometry {
        var positions = top
        var normals = topNormals
        var colors = topColors
        var indices = triangles
        let count = resolution + 1
        let walls: [(vertices: [Int], outward: SIMD3<Float>)] = [
            (Array(0..<count), SIMD3(0, 0, 1)),
            ((0..<count).map { (count - 1) * count + $0 }, SIMD3(0, 0, -1)),
            ((0..<count).map { $0 * count }, SIMD3(-1, 0, 0)),
            ((0..<count).map { $0 * count + count - 1 }, SIMD3(1, 0, 0))
        ]
        for wall in walls {
            let base = Int32(positions.count)
            for vertex in wall.vertices {
                let point = top[vertex]
                let color = topColors[vertex]
                let upper = SIMD4<Float>(color.x * 0.62, color.y * 0.62, color.z * 0.62, 1)
                let lower = SIMD4<Float>(color.x * 0.28, color.y * 0.28, color.z * 0.28, 1)
                positions += [point, SIMD3(point.x, 0, point.z)]
                normals += [wall.outward, wall.outward]
                colors += [upper, lower]
            }
            for index in 0..<(wall.vertices.count - 1) {
                let a = base + Int32(index * 2)
                indices += [a, a + 1, a + 2, a + 2, a + 1, a + 3]
            }
        }
        return SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: positions.map { SCNVector3($0) }),
                SCNGeometrySource(normals: normals.map { SCNVector3($0) }),
                colorSource(colors)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
    }

    /// The answer of a neuron as a solid block, like a printed relief: the top is the true answer over the unit square,
    /// and the walls close it down to height 0. Its second geometry is the grid lines of the top.
    /// Ответ нейрона как цельный блок: верх это настоящий ответ над единичным квадратом, стенки закрывают его до нуля.
    static func reliefBlock(side: Float, height: Float, resolution: Int,
                            answer: (Double, Double) -> Double,
                            slope: (Double, Double) -> SIMD2<Double>,
                            color: ((Double, Double) -> SIMD4<Float>)? = nil) -> (solid: SCNGeometry, grid: SCNGeometry)? {
        let width = Double(side), tall = Double(height)
        guard let mesh = SurfacePlot3D.mesh(
            domain: 0...1,
            resolution: resolution,
            gridStride: max(1, resolution / 4),
            function: { tall * answer($0, $1) },
            gradient: { slope($0, $1) * (tall / width) }
        ) else { return nil }
        let top = mesh.positions.map { SIMD3<Float>(Float(($0.x - 0.5) * width), Float($0.z), Float((0.5 - $0.y) * width)) }
        let topNormals = mesh.normals.map { SIMD3<Float>(Float($0.x), Float($0.z), Float(-$0.y)) }
        let solid = closedSurface(
            top: top,
            normals: topNormals,
            colors: mesh.positions.map { color?($0.x, $0.y) ?? answerColor($0.z / tall) },
            triangles: mesh.triangleIndices,
            resolution: resolution
        )
        // Lifted a little along the normal so the lines do not flicker against the surface.
        let lifted = zip(top, topNormals).map { SCNVector3($0 + $1 * 0.012) }
        let grid = SCNGeometry(
            sources: [SCNGeometrySource(vertices: lifted)],
            elements: [SCNGeometryElement(indices: mesh.gridLineIndices, primitiveType: .line)]
        )
        return (solid, grid)
    }
}

/// The network of the lesson as a physical model. Each neuron is a block whose relief is its true answer for all inputs
/// (x₁, x₂), so training visibly turns the cliff of h₁ and reshapes the output. Everything shown is computed from the weights.
/// Сеть урока как объёмная модель. Каждый нейрон это блок, рельеф которого его настоящий ответ при всех входах (x₁, x₂),
/// поэтому при обучении видно, как поворачивается обрыв h₁ и меняется форма выхода. Всё считается из весов.
struct TrainingNetworkSceneView: NSViewRepresentable {
    let weights: [Double]
    let training: Bool
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let plinthHeight: Float = 0.42
    private static let reliefHeight: Float = 1.5
    private static let lip: Float = 0.12
    private static let forwardDuration: TimeInterval = 0.5
    private static let backwardDuration: TimeInterval = 0.32
    private static let cycle: TimeInterval = 1.9

    private static func center(_ neuron: NeuronRelief) -> SIMD3<Float> {
        switch neuron {
        case .x1: return SIMD3(-5.74, 0, -1.9)
        case .x2: return SIMD3(-5.74, 0, 1.9)
        case .h1: return SIMD3(-0.6, 0, -2.4)
        case .h2: return SIMD3(-0.6, 0, 2.4)
        case .y: return SIMD3(5.14, 0, 0)
        }
    }

    private static func side(_ neuron: NeuronRelief) -> Float {
        switch neuron {
        case .x1, .x2: return 2
        case .h1, .h2: return 2.6
        case .y: return 3.2
        }
    }

    private static func title(_ neuron: NeuronRelief) -> String {
        switch neuron {
        case .x1: return "x₁"
        case .x2: return "x₂"
        case .h1: return "h₁"
        case .h2: return "h₂"
        case .y: return "y"
        }
    }

    private struct Wire {
        let from: NeuronRelief
        let to: NeuronRelief
        let weightIndex: Int
        let curve: SceneCurve
        var trainable: Bool { weightIndex < 2 }
    }

    private static func wire(_ from: NeuronRelief, _ to: NeuronRelief, weight: Int, out: Float, into: Float, lift: Float) -> Wire {
        let a = center(from) + SIMD3<Float>(side(from) / 2 + lip, plinthHeight / 2, out)
        let b = center(to) + SIMD3<Float>(-side(to) / 2 - lip, plinthHeight / 2, into)
        let reach = (b.x - a.x) * 0.42
        return Wire(from: from, to: to, weightIndex: weight, curve: SceneCurve(
            start: a,
            control1: a + SIMD3<Float>(reach, lift, 0),
            control2: b + SIMD3<Float>(-reach, lift, 0),
            end: b
        ))
    }

    /// The two crossing wires pass one above the other. / Два пересекающихся провода идут один над другим.
    private static let wires: [Wire] = [
        wire(.x1, .h1, weight: 0, out: -0.4, into: -0.5, lift: 0.5),
        wire(.x2, .h1, weight: 1, out: -0.4, into: 0.5, lift: 1.5),
        wire(.x1, .h2, weight: 3, out: 0.4, into: -0.5, lift: 0.15),
        wire(.x2, .h2, weight: 4, out: 0.4, into: 0.5, lift: 0.5),
        wire(.h1, .y, weight: 6, out: 0, into: -0.65, lift: 0.5),
        wire(.h2, .y, weight: 7, out: 0, into: 0.65, lift: 0.5)
    ]

    private static func wireRadius(_ weight: Double) -> Float { 0.035 + 0.011 * Float(min(abs(weight), 10)) }

    final class Coordinator: NSObject {
        var weights: [Double] = []
        var drawnWeights: [Double] = []
        var training = false
        var reduceMotion = false
        var language: AppLanguage = .ru
        var example = 0
        /// Each neuron shows the example the signal has already reached. / Нейрон показывает пример, до которого дошёл сигнал.
        var shownExample = [Int](repeating: 0, count: NeuronRelief.allCases.count)
        var timer: Timer?
        var labelTimer: Timer?
        weak var scene: SCNScene?

        deinit {
            timer?.invalidate()
            labelTimer?.invalidate()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        let scene = Self.makeScene()
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: false)
        view.orbit(around: SIMD3(0, 0.6, 0))
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
        Self.applyWeights(coordinator: coordinator)
        Self.showExample(coordinator: coordinator)
        let timer = Timer(timeInterval: Self.cycle, repeats: true) { [weak coordinator] _ in
            guard let coordinator else { return }
            coordinator.example = (coordinator.example + 1) % XORNetworkModel.examples.count
            Self.showExample(coordinator: coordinator)
        }
        RunLoop.main.add(timer, forMode: .common)
        coordinator.timer = timer
        let labelTimer = Timer(timeInterval: 0.12, repeats: true) { [weak view] _ in
            guard let view, let root = view.scene?.rootNode else { return }
            let names = NeuronRelief.allCases.map { "label-\($0.rawValue)" }
                + ["w11-label", "w12-label", "column-inputs", "column-hidden", "column-output"]
            TrainingStage.declutter(names.compactMap { root.childNode(withName: $0, recursively: false) }, in: view)
        }
        RunLoop.main.add(labelTimer, forMode: .common)
        coordinator.labelTimer = labelTimer
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.training = training
        coordinator.reduceMotion = reduceMotion
        if coordinator.weights != weights || coordinator.language != language {
            coordinator.weights = weights
            coordinator.language = language
            Self.applyWeights(coordinator: coordinator)
        }
    }

    static func dismantleNSView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.timer?.invalidate()
        coordinator.timer = nil
        coordinator.labelTimer?.invalidate()
        coordinator.labelTimer = nil
        view.isPlaying = false
    }

    // MARK: - Fixed parts

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: true, shadowScale: 11, keyPosition: SCNVector3(4.9, 11.8, 5.8))
        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 240
        rim.light?.color = NSColor(red: 0.62, green: 0.74, blue: 1, alpha: 1)
        rim.eulerAngles = SCNVector3(-0.5, 3.6, 0)
        scene.rootNode.addChildNode(rim)

        let table = SCNBox(width: 14.9, height: 0.18, length: 9.8, chamferRadius: 0.09)
        table.materials = [TrainingStage.material(NSColor(red: 0.105, green: 0.12, blue: 0.18, alpha: 1))]
        let tableNode = SCNNode(geometry: table)
        tableNode.position = SCNVector3(0, -0.09, 0)
        scene.rootNode.addChildNode(tableNode)

        let wiresNode = SCNNode()
        wiresNode.name = "wires"
        for (index, wire) in wires.enumerated() {
            let node = SCNNode()
            node.name = "wire-\(index)"
            wiresNode.addChildNode(node)
            if wire.trainable { addCollar(to: node, curve: wire.curve) }
            for share: Float in [0, 1] {
                let socket = SCNCylinder(radius: 0.2, height: 0.1)
                socket.radialSegmentCount = 24
                socket.materials = [TrainingStage.metal(NSColor(white: 0.42, alpha: 1))]
                let socketNode = SCNNode(geometry: socket)
                socketNode.simdPosition = wire.curve.point(share)
                socketNode.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: SIMD3<Float>(1, 0, 0))
                scene.rootNode.addChildNode(socketNode)
            }
        }
        scene.rootNode.addChildNode(wiresNode)

        for neuron in NeuronRelief.allCases { addNeuron(neuron, to: scene.rootNode) }
        addTargetRings(to: scene.rootNode)

        for (name, x) in [("column-inputs", center(.x1).x), ("column-hidden", center(.h1).x), ("column-output", center(.y).x)] {
            // Printed on the table, they turn with the model and never cover it. / Напечатаны на столе: поворачиваются с моделью и не закрывают её.
            let label = TrainingStage.label("", size: 0.46, color: TrainingStage.dimText)
            label.name = name
            label.constraints = nil
            label.eulerAngles.x = -CGFloat.pi / 2
            label.simdPosition = SIMD3(x, 0.012, 4.2)
            scene.rootNode.addChildNode(label)
        }
        for name in ["w11", "w12"] {
            let label = TrainingStage.platedLabel(size: 0.36, color: TrainingStage.trainedWeight)
            label.name = name + "-label"
            scene.rootNode.addChildNode(label)
        }

        let pulses = SCNNode()
        pulses.name = "pulses"
        scene.rootNode.addChildNode(pulses)

        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        // A long lens from far away: the model keeps its proportions and stays in frame from every side.
        // Длинный объектив издалека: модель не искажается и со всех сторон остаётся в кадре.
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 90
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 19.4, 25.9)
        cameraNode.look(at: SCNVector3(0, 0.6, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    private static func addNeuron(_ neuron: NeuronRelief, to root: SCNNode) {
        let spot = center(neuron)
        let width = side(neuron)
        let plinth = SCNBox(width: CGFloat(width + 2 * lip), height: CGFloat(plinthHeight), length: CGFloat(width + 2 * lip), chamferRadius: 0.05)
        plinth.materials = [TrainingStage.metal(NSColor(red: 0.2, green: 0.22, blue: 0.29, alpha: 1))]
        let plinthNode = SCNNode(geometry: plinth)
        plinthNode.simdPosition = spot + SIMD3<Float>(0, plinthHeight / 2, 0)
        root.addChildNode(plinthNode)

        // A light strip on the front of the plinth glows with the neuron's answer. / Полоска на цоколе светится ответом нейрона.
        let strip = SCNBox(width: CGFloat(width * 0.7), height: 0.07, length: 0.02, chamferRadius: 0.01)
        strip.materials = [TrainingStage.material(.darkGray, lit: false)]
        let stripNode = SCNNode(geometry: strip)
        stripNode.name = "strip-\(neuron.rawValue)"
        stripNode.simdPosition = spot + SIMD3<Float>(0, plinthHeight / 2, width / 2 + lip + 0.005)
        root.addChildNode(stripNode)

        let relief = SCNNode()
        relief.name = "relief-\(neuron.rawValue)"
        relief.simdPosition = spot + SIMD3<Float>(0, plinthHeight, 0)
        let grid = SCNNode()
        grid.name = "grid"
        relief.addChildNode(grid)
        root.addChildNode(relief)

        let sphere = SCNSphere(radius: neuron == .y ? 0.2 : 0.16)
        sphere.segmentCount = 28
        let ballMaterial = TrainingStage.material(.white)
        ballMaterial.emission.contents = NSColor(white: 0.4, alpha: 1)
        ballMaterial.specular.contents = NSColor.white
        sphere.materials = [ballMaterial]
        let ball = SCNNode(geometry: sphere)
        ball.name = "ball-\(neuron.rawValue)"
        root.addChildNode(ball)

        let label = TrainingStage.platedLabel(size: neuron == .y ? 0.46 : 0.42, color: TrainingStage.text)
        label.name = "label-\(neuron.rawValue)"
        label.simdPosition = spot + SIMD3<Float>(0, plinthHeight + reliefHeight + 0.62, 0)
        root.addChildNode(label)
    }

    /// Where the example puts a point on the top of a neuron's block. / Где пример ставит точку на верху блока нейрона.
    private static func topPoint(_ neuron: NeuronRelief, x1: Double, x2: Double, height: Double) -> SIMD3<Float> {
        let spot = center(neuron)
        let width = side(neuron)
        let x: Float = (Float(x1) - 0.5) * width
        let y: Float = plinthHeight + Float(height) * reliefHeight
        let z: Float = (0.5 - Float(x2)) * width
        return spot + SIMD3<Float>(x, y, z)
    }

    /// One hoop per example at the height of the right answer: the output is right where its corner reaches the hoop.
    /// По кольцу на пример на высоте нужного ответа: выход верен там, где его угол достаёт до кольца.
    private static func addTargetRings(to root: SCNNode) {
        for (index, example) in XORNetworkModel.examples.enumerated() {
            let position = topPoint(.y, x1: example.x1, x2: example.x2, height: example.target)
            let ring = SCNTorus(ringRadius: 0.27, pipeRadius: 0.032)
            ring.materials = [TrainingStage.material(.white, lit: false)]
            let node = SCNNode(geometry: ring)
            node.name = "ring-\(index)"
            node.simdPosition = position + SIMD3<Float>(0, 0.02, 0)
            root.addChildNode(node)
            if example.target > 0 {
                let base = topPoint(.y, x1: example.x1, x2: example.x2, height: 0)
                root.addChildNode(TrainingStage.cylinder(from: base, to: position, radius: 0.016, material: TrainingStage.material(TrainingStage.dimText, lit: false)))
            }
        }
    }

    private static func addCollar(to node: SCNNode, curve: SceneCurve) {
        // A gold sleeve with two bands marks a weight that is being trained. / Золотая муфта отмечает обучаемый вес.
        for (share, length) in [(Float(0.5), CGFloat(0.5)), (Float(0.37), CGFloat(0.07)), (Float(0.63), CGFloat(0.07))] {
            let sleeve = SCNCylinder(radius: 0.2, height: length)
            sleeve.radialSegmentCount = 24
            let material = TrainingStage.metal(TrainingStage.trainedWeight)
            material.emission.contents = NSColor(red: 0.3, green: 0.22, blue: 0.02, alpha: 1)
            sleeve.materials = [material]
            let part = SCNNode(geometry: sleeve)
            part.name = "collar"
            part.simdPosition = curve.point(share)
            part.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: curve.tangent(share))
            node.addChildNode(part)
        }
    }

    // MARK: - What the weights change

    private static func applyWeights(coordinator: Coordinator) {
        guard let scene = coordinator.scene else { return }
        let w = coordinator.weights
        let drawn = coordinator.drawnWeights
        let root = scene.rootNode
        func changed(_ indices: ClosedRange<Int>) -> Bool { drawn.isEmpty || indices.contains { drawn[$0] != w[$0] } }

        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        if drawn.isEmpty {
            redrawRelief(.x1, weights: w, root: root)
            redrawRelief(.x2, weights: w, root: root)
        }
        if changed(0...2) { redrawRelief(.h1, weights: w, root: root) }
        if changed(3...5) { redrawRelief(.h2, weights: w, root: root) }
        if changed(0...8) { redrawRelief(.y, weights: w, root: root) }

        for (index, wire) in wires.enumerated() where drawn.isEmpty || drawn[wire.weightIndex] != w[wire.weightIndex] {
            redrawWire(index, wire: wire, weight: w[wire.weightIndex], root: root)
        }
        for (index, name) in ["w11", "w12"].enumerated() {
            guard let label = root.childNode(withName: name + "-label", recursively: false) else { continue }
            let title = index == 0 ? "w₁₁" : "w₁₂"
            TrainingStage.setPlatedLabel(label, "\(title) = " + L10n.number(w[index], fractionDigits: 1, coordinator.language))
            // Beside the sleeve, so that gold does not cover gold. / Рядом с муфтой, чтобы золото не легло на золото.
            label.simdPosition = wires[index].curve.point(index == 0 ? 0.5 : 0.28) + SIMD3<Float>(0, 0.55, 0)
        }
        for (name, key) in [("column-inputs", "lab.landscape.columnInputs"), ("column-hidden", "lab.landscape.columnHidden"), ("column-output", "lab.landscape.columnOutput")] {
            if let label = root.childNode(withName: name, recursively: false) { TrainingStage.setLabel(label, L10n.text(key, coordinator.language)) }
        }
        for (index, example) in XORNetworkModel.examples.enumerated() {
            let answer = NeuronRelief.y.answer(weights: w, x1: example.x1, x2: example.x2)
            let correct = XORNetworkModel.isCorrect(answer: answer, target: example.target)
            root.childNode(withName: "ring-\(index)", recursively: false)?.geometry?.firstMaterial?.diffuse.contents =
                correct ? NSColor(red: 0.25, green: 0.95, blue: 0.55, alpha: 1) : NSColor(red: 1, green: 0.42, blue: 0.28, alpha: 1)
        }
        for neuron in NeuronRelief.allCases { place(neuron, coordinator: coordinator) }
        SCNTransaction.commit()
        coordinator.drawnWeights = w
    }

    private static func redrawRelief(_ neuron: NeuronRelief, weights: [Double], root: SCNNode) {
        guard let node = root.childNode(withName: "relief-\(neuron.rawValue)", recursively: false),
              let block = TrainingStage.reliefBlock(
                side: side(neuron),
                height: reliefHeight,
                resolution: neuron == .y ? 36 : 24,
                answer: { neuron.answer(weights: weights, x1: $0, x2: $1) },
                slope: { neuron.slope(weights: weights, x1: $0, x2: $1) }
              ) else { return }
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.white
        material.lightingModel = .blinn
        material.specular.contents = NSColor(white: 0.3, alpha: 1)
        material.isDoubleSided = true
        block.solid.materials = [material]
        node.geometry = block.solid
        block.grid.firstMaterial = TrainingStage.material(NSColor(white: 1, alpha: 0.24), lit: false)
        node.childNode(withName: "grid", recursively: false)?.geometry = block.grid
    }

    /// Thickness shows the size of a weight and colour its sign: blue is positive, red negative, as in the lab above.
    private static func redrawWire(_ index: Int, wire: Wire, weight: Double, root: SCNNode) {
        guard let node = root.childNode(withName: "wires", recursively: false)?.childNode(withName: "wire-\(index)", recursively: false) else { return }
        let radius = wireRadius(weight)
        let geometry = TrainingStage.tube(along: wire.curve, radius: radius)
        let dim: CGFloat = wire.trainable ? 1 : 0.68
        let color = weight >= 0
            ? NSColor(red: 0.3 * dim, green: 0.55 * dim, blue: 1 * dim, alpha: 1)
            : NSColor(red: 1 * dim, green: 0.32 * dim, blue: 0.32 * dim, alpha: 1)
        let material = TrainingStage.metal(color)
        material.isDoubleSided = true
        geometry.materials = [material]
        node.geometry = geometry
        for part in node.childNodes where part.name == "collar" {
            (part.geometry as? SCNCylinder)?.radius = CGFloat(radius + 0.045)
        }
    }

    /// Puts the ball of a neuron on its relief at the example it shows, and updates its label and light strip.
    private static func place(_ neuron: NeuronRelief, coordinator: Coordinator) {
        guard let root = coordinator.scene?.rootNode else { return }
        let example = XORNetworkModel.examples[coordinator.shownExample[neuron.rawValue]]
        let answer = neuron.answer(weights: coordinator.weights, x1: example.x1, x2: example.x2)
        root.childNode(withName: "ball-\(neuron.rawValue)", recursively: false)?.simdPosition =
            topPoint(neuron, x1: example.x1, x2: example.x2, height: answer) + SIMD3<Float>(0, neuron == .y ? 0.2 : 0.16, 0)
        let color = TrainingStage.answerColor(answer)
        root.childNode(withName: "strip-\(neuron.rawValue)", recursively: false)?.geometry?.firstMaterial?.diffuse.contents =
            NSColor(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: 1)
        guard let label = root.childNode(withName: "label-\(neuron.rawValue)", recursively: false) else { return }
        let language = coordinator.language
        let digits = neuron == .x1 || neuron == .x2 ? 0 : 2
        var text = "\(title(neuron)) = " + L10n.number(answer, fractionDigits: digits, language)
        if neuron == .y {
            text += " · " + String(format: L10n.text("lab.landscape.target", language), String(Int(example.target)))
        }
        TrainingStage.setPlatedLabel(label, text)
    }

    // MARK: - Signals

    private static func arrive(_ neurons: [NeuronRelief], example: Int, coordinator: Coordinator) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = coordinator.reduceMotion ? 0 : 0.22
        for neuron in neurons {
            coordinator.shownExample[neuron.rawValue] = example
            place(neuron, coordinator: coordinator)
        }
        SCNTransaction.commit()
    }

    private static func showExample(coordinator: Coordinator) {
        let index = coordinator.example
        guard !coordinator.reduceMotion, let scene = coordinator.scene,
              let pulses = scene.rootNode.childNode(withName: "pulses", recursively: false) else {
            arrive(NeuronRelief.allCases, example: index, coordinator: coordinator)
            return
        }
        let example = XORNetworkModel.examples[index]
        let w = coordinator.weights

        // Forward: a signal is as strong as the neuron that sends it, so an input of 0 sends nothing.
        // Each block shows the new example when the signal reaches it. / Блок показывает пример, когда до него дошёл сигнал.
        arrive([.x1, .x2], example: index, coordinator: coordinator)
        for wire in wires {
            let isInput = wire.from == .x1 || wire.from == .x2
            let strength = wire.from.answer(weights: w, x1: example.x1, x2: example.x2)
            pulse(in: pulses, along: wire.curve, reversed: false, color: TrainingStage.forwardSignal, strength: strength,
                  delay: isInput ? 0 : forwardDuration, duration: forwardDuration)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + forwardDuration) { [weak coordinator] in
            guard let coordinator else { return }
            arrive([.h1, .h2], example: index, coordinator: coordinator)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2 * forwardDuration) { [weak coordinator] in
            guard let coordinator else { return }
            arrive([.y], example: index, coordinator: coordinator)
        }

        guard coordinator.training else { return }
        // Backward, by the chain rule: out = 2(y − t) · y(1 − y), then out · v₁ · h₁(1 − h₁) reaches the trainable weights.
        // On a plateau these numbers are almost zero, so no pulse appears: the gradient has vanished.
        let y = NeuronRelief.y.answer(weights: w, x1: example.x1, x2: example.x2)
        let h = NeuronRelief.h1.answer(weights: w, x1: example.x1, x2: example.x2)
        let out = 2 * (y - example.target) * y * (1 - y)
        let back = out * w[6] * h * (1 - h)
        let backDelay = 2 * forwardDuration + 0.02
        pulse(in: pulses, along: wires[4].curve, reversed: true, color: TrainingStage.errorSignal, strength: min(1, abs(back) * 12), delay: backDelay, duration: backwardDuration)
        for (wireIndex, input) in [example.x1, example.x2].enumerated() {
            pulse(in: pulses, along: wires[wireIndex].curve, reversed: true, color: TrainingStage.errorSignal,
                  strength: min(1, abs(back * input) * 12), delay: backDelay + backwardDuration, duration: backwardDuration)
        }
    }

    private static func pulse(in parent: SCNNode, along curve: SceneCurve, reversed: Bool, color: NSColor,
                              strength: Double, delay: TimeInterval, duration: TimeInterval) {
        guard strength > 0.04 else { return }
        let radius = CGFloat(0.1 + 0.13 * strength)
        let core = SCNSphere(radius: radius)
        core.segmentCount = 16
        core.materials = [TrainingStage.material(color, lit: false)]
        let node = SCNNode(geometry: core)
        let halo = SCNSphere(radius: radius * 2)
        halo.segmentCount = 16
        let glow = TrainingStage.material(color.withAlphaComponent(0.3), lit: false)
        glow.blendMode = .add
        glow.writesToDepthBuffer = false
        halo.materials = [glow]
        let haloNode = SCNNode(geometry: halo)
        haloNode.castsShadow = false
        node.addChildNode(haloNode)
        node.castsShadow = false
        node.simdPosition = curve.point(reversed ? 1 : 0)
        node.opacity = 0
        let travel = SCNAction.customAction(duration: duration) { moving, elapsed in
            let share = Float(elapsed / CGFloat(duration))
            moving.simdPosition = curve.point(reversed ? 1 - share : share)
        }
        node.runAction(.sequence([
            .wait(duration: delay),
            .fadeIn(duration: 0.03),
            travel,
            .removeFromParentNode()
        ]))
        parent.addChildNode(node)
    }
}
