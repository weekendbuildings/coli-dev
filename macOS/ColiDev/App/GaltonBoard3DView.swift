import SceneKit
import SwiftUI
import simd

/// A true Galton board in 3D. Balls fall through real pegs along the path their random choices give, columns grow in the bins,
/// and gold rings mark the exact expected height. / Настоящая доска Гальтона в 3D: шарики падают по пути, заданному их случайными
/// выборами, столбики растут в корзинах, а золотые кольца отмечают точную ожидаемую высоту.
struct GaltonBoardSceneView: NSViewRepresentable {
    let model: GaltonBoardModel
    let lastPaths: [[Bool]]
    let dropCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    typealias Model = GaltonBoardModel

    private static let spacing: Float = 0.56
    private static let rowHeight: Float = 0.48
    private static let binHeight: Float = 3
    private static let boardBottom: Float = binHeight + 0.2

    private static func peg(row: Int, index: Int, rows: Int) -> SIMD3<Float> {
        let x = (Float(index) - Float(row) / 2) * spacing
        let y = boardBottom + Float(rows - row) * rowHeight
        return SIMD3<Float>(x, y, 0)
    }

    private static func binX(_ bin: Int, rows: Int) -> Float { (Float(bin) - Float(rows) / 2) * spacing }

    final class Coordinator: NSObject {
        var drawnRows = 0
        var drawnDrops = 0
        var drawnMaximum = 0.0
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = LabSceneView()
        view.scene = Self.makeScene()
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        view.orbit(around: SIMD3(0, 3.8, 0))
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = TrainingStage.background
        view.rendersContinuously = true
        view.isPlaying = true
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let root = view.scene?.rootNode else { return }
        let coordinator = context.coordinator
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        if coordinator.drawnRows != model.rows {
            coordinator.drawnRows = model.rows
            Self.drawBoard(root: root, rows: model.rows)
        }
        SCNTransaction.commit()
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0 : 0.18
        Self.updateColumns(root: root, model: model)
        SCNTransaction.commit()
        if coordinator.drawnDrops != dropCount {
            coordinator.drawnDrops = dropCount
            if !reduceMotion { Self.animate(paths: lastPaths, root: root, rows: model.rows) }
        }
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = TrainingStage.background
        TrainingStage.addLights(to: scene, shadows: true, shadowScale: 9, keyPosition: SCNVector3(4.9, 11.8, 5.8))
        let table = SCNBox(width: 11, height: 0.2, length: 4, chamferRadius: 0.09)
        table.materials = [TrainingStage.material(NSColor(red: 0.105, green: 0.12, blue: 0.18, alpha: 1))]
        let tableNode = SCNNode(geometry: table)
        tableNode.position = SCNVector3(0, -0.1, 0)
        scene.rootNode.addChildNode(tableNode)
        let back = SCNBox(width: 10, height: 10.4, length: 0.12, chamferRadius: 0.05)
        back.materials = [TrainingStage.material(NSColor(red: 0.09, green: 0.1, blue: 0.16, alpha: 1))]
        let backNode = SCNNode(geometry: back)
        backNode.position = SCNVector3(0, 5.2, -0.55)
        scene.rootNode.addChildNode(backNode)
        for name in ["pegs", "columns", "balls"] {
            let node = SCNNode()
            node.name = name
            scene.rootNode.addChildNode(node)
        }
        let camera = SCNCamera()
        camera.projectionDirection = .horizontal
        camera.fieldOfView = 28
        camera.zNear = 1
        camera.zFar = 90
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(9, 8.5, 31)
        cameraNode.look(at: SCNVector3(0, 3.8, 0))
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    private static func drawBoard(root: SCNNode, rows: Int) {
        guard let pegs = root.childNode(withName: "pegs", recursively: false),
              let columns = root.childNode(withName: "columns", recursively: false) else { return }
        pegs.childNodes.forEach { $0.removeFromParentNode() }
        columns.childNodes.forEach { $0.removeFromParentNode() }
        let metal = TrainingStage.metal(NSColor(white: 0.62, alpha: 1))
        for row in 0..<rows {
            for index in 0...row {
                let cylinder = SCNCylinder(radius: 0.075, height: 0.9)
                cylinder.radialSegmentCount = 12
                cylinder.materials = [metal]
                let node = SCNNode(geometry: cylinder)
                node.simdPosition = peg(row: row, index: index, rows: rows)
                node.eulerAngles.x = .pi / 2
                pegs.addChildNode(node)
            }
        }
        for bin in 0...rows {
            let x = binX(bin, rows: rows)
            let box = SCNBox(width: CGFloat(spacing * 0.78), height: 1, length: 0.7, chamferRadius: 0.04)
            box.materials = [TrainingStage.metal(NSColor(red: 0.3, green: 0.55, blue: 1, alpha: 1))]
            let column = SCNNode(geometry: box)
            column.name = "column-\(bin)"
            column.pivot = SCNMatrix4MakeTranslation(0, -0.5, 0)
            column.position = SCNVector3(x, 0, 0)
            column.scale = SCNVector3(1, 0.001, 1)
            columns.addChildNode(column)
            let ring = SCNTorus(ringRadius: CGFloat(spacing * 0.5), pipeRadius: 0.03)
            ring.materials = [TrainingStage.material(TrainingStage.trainedWeight, lit: false)]
            let ringNode = SCNNode(geometry: ring)
            ringNode.name = "ring-\(bin)"
            ringNode.position = SCNVector3(x, 0, 0)
            columns.addChildNode(ringNode)
            if bin <= rows {
                let wall = SCNBox(width: 0.035, height: CGFloat(binHeight), length: 0.8, chamferRadius: 0.01)
                wall.materials = [TrainingStage.material(NSColor(white: 0.32, alpha: 1))]
                let wallNode = SCNNode(geometry: wall)
                wallNode.position = SCNVector3(x - spacing / 2, binHeight / 2, 0)
                columns.addChildNode(wallNode)
            }
        }
    }

    private static func updateColumns(root: SCNNode, model: Model) {
        guard let columns = root.childNode(withName: "columns", recursively: false) else { return }
        // The tallest of the columns and rings just fills the bin. / Самый высокий столбик или кольцо как раз заполняет корзину.
        let balls = Double(model.balls)
        let tallestRing = (0...model.rows).map { model.theoryChance(bin: $0) * balls }.max() ?? 0
        let tallest = max(Double(model.bins.max() ?? 0), tallestRing, 1)
        let unit = Float(Double(binHeight - 0.1) / tallest)
        for bin in 0...model.rows {
            columns.childNode(withName: "column-\(bin)", recursively: false)?.scale = SCNVector3(1, max(0.001, Float(model.bins[bin]) * unit), 1)
            let ring = columns.childNode(withName: "ring-\(bin)", recursively: false)
            ring?.position = SCNVector3(binX(bin, rows: model.rows), Float(model.theoryChance(bin: bin) * balls) * unit, 0)
            ring?.isHidden = model.balls == 0
        }
    }

    /// Each ball follows its own true path past the pegs. / Каждый шарик идёт своим настоящим путём мимо штырей.
    private static func animate(paths: [[Bool]], root: SCNNode, rows: Int) {
        guard let balls = root.childNode(withName: "balls", recursively: false) else { return }
        let material = TrainingStage.material(.white)
        material.emission.contents = NSColor(white: 0.3, alpha: 1)
        material.specular.contents = NSColor.white
        for (index, path) in paths.prefix(24).enumerated() {
            let sphere = SCNSphere(radius: 0.13)
            sphere.segmentCount = 16
            sphere.materials = [material]
            let ball = SCNNode(geometry: sphere)
            ball.simdPosition = peg(row: 0, index: 0, rows: rows) + SIMD3<Float>(0, rowHeight, 0.3)
            ball.opacity = 0
            var actions: [SCNAction] = [.wait(duration: Double(index) * 0.05), .fadeIn(duration: 0.03)]
            var rights = 0
            for (row, right) in path.enumerated() {
                let at = peg(row: row, index: rights, rows: rows)
                actions.append(.move(to: SCNVector3(at.x, at.y + 0.13, 0.3), duration: 0.045))
                if right { rights += 1 }
            }
            actions.append(.move(to: SCNVector3(binX(rights, rows: rows), binHeight * 0.5, 0.3), duration: 0.12))
            actions.append(.removeFromParentNode())
            ball.runAction(.sequence(actions))
            balls.addChildNode(ball)
        }
    }
}
