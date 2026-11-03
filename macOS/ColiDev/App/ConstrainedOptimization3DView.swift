import SceneKit
import SwiftUI
import simd

/// Rotatable 3D view of the Lagrange lesson: the saddle z = xy, the constraint cylinder x² + y² = 1,
/// their intersection curve, the selected point, and the gradients ∇f and ∇g at that point.
/// Вращаемая 3D-сцена урока Лагранжа: седло z = xy, цилиндр ограничения, кривая пересечения и градиенты.
struct ConstrainedOptimizationSurfaceView: View {
    let x: Double
    let y: Double
    let accessibilityLabel: String
    let accessibilityValue: String

    var body: some View {
        ConstrainedOptimizationSceneView(x: x, y: y)
            .frame(minHeight: 320)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityValue(Text(accessibilityValue))
    }
}

private struct ConstrainedOptimizationSceneView: NSViewRepresentable {
    let x: Double
    let y: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = LagrangeSceneBuilder.makeScene()
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = !reduceMotion
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = AppPalette.canvas.nsColor
        LagrangeSceneBuilder.update(scene: view.scene!, x: x, y: y)
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        view.defaultCameraController.inertiaEnabled = !reduceMotion
        guard let scene = view.scene else { return }
        LagrangeSceneBuilder.update(scene: scene, x: x, y: y)
    }
}

enum LagrangeSceneBuilder {
    // Math (x, y, z) with z as height maps to SceneKit (x, z, −y), whose up axis is y.
    static func scenePoint(_ point: SIMD3<Double>) -> SCNVector3 {
        SCNVector3(Float(point.x), Float(point.z), Float(-point.y))
    }

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = AppPalette.canvas.nsColor

        if let mesh = LagrangeSurfaceModel.surfaceMesh(resolution: 48) {
            scene.rootNode.addChildNode(surfaceNode(mesh))
            scene.rootNode.addChildNode(gridNode(mesh))
        }
        scene.rootNode.addChildNode(constraintCylinderNode())
        scene.rootNode.addChildNode(constraintCurveNode())
        scene.rootNode.addChildNode(stationaryMarkersNode())
        scene.rootNode.addChildNode(axesNode())

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 420
        scene.rootNode.addChildNode(ambient)

        // Viewing along a diagonal makes the saddle collapse into a "V"; looking mostly along x from above
        // shows both the rising and the falling direction. / Ракурс почти вдоль x сверху показывает седло целиком.
        let camera = SCNCamera()
        camera.fieldOfView = 40
        camera.zNear = 0.05
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = scenePoint(SIMD3(5.1, -2.1, 3.4))
        cameraNode.look(at: SCNVector3(0, -0.1, 0))
        scene.rootNode.addChildNode(cameraNode)

        let dynamic = SCNNode()
        dynamic.name = "dynamic"
        scene.rootNode.addChildNode(dynamic)
        return scene
    }

    static func update(scene: SCNScene, x: Double, y: Double) {
        guard let dynamic = scene.rootNode.childNode(withName: "dynamic", recursively: false) else { return }
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        dynamic.childNodes.forEach { $0.removeFromParentNode() }

        let surfacePoint = SIMD3(x, y, LagrangeSurfaceModel.objective(x, y))
        let point = SCNNode(geometry: SCNSphere(radius: 0.07))
        point.geometry?.firstMaterial = material(.controlAccentColor)
        point.position = scenePoint(surfacePoint)
        drawOnTop(point, order: 102)
        dynamic.addChildNode(point)

        // Stem from the circle in the plane z = 0 up or down to the surface.
        dynamic.addChildNode(segment(
            from: SIMD3(x, y, 0),
            to: surfacePoint,
            radius: 0.012,
            color: NSColor.controlAccentColor.withAlphaComponent(0.7)
        ))
        let footprint = SCNNode(geometry: SCNSphere(radius: 0.035))
        footprint.geometry?.firstMaterial = material(NSColor.controlAccentColor.withAlphaComponent(0.7))
        footprint.position = scenePoint(SIMD3(x, y, 0))
        dynamic.addChildNode(footprint)

        // Both gradients live in the xy-plane; draw them from the selected point at its height.
        // ∇f points uphill, so a horizontal arrow would sink under the surface: draw arrows on top.
        // Один масштаб для обеих стрелок, чтобы отношение длин было честным; рисуем поверх поверхности.
        let scale = 0.42
        let gradF = LagrangeSurfaceModel.objectiveGradient(x, y)
        let gradG = LagrangeSurfaceModel.constraintGradient(x, y)
        let gradFArrow = arrow(
            from: surfacePoint,
            to: surfacePoint + SIMD3(gradF.x * scale, gradF.y * scale, 0),
            color: .systemOrange,
            shaftRadius: 0.024,
            headRadius: 0.07
        )
        let gradGArrow = arrow(
            from: surfacePoint,
            to: surfacePoint + SIMD3(gradG.x * scale, gradG.y * scale, 0),
            color: .systemPurple,
            shaftRadius: 0.024,
            headRadius: 0.07
        )
        // At an extremum the arrows overlap; the shorter ∇f stays in front so both remain visible.
        drawOnTop(gradGArrow, order: 100)
        drawOnTop(gradFArrow, order: 101)
        dynamic.addChildNode(gradFArrow)
        dynamic.addChildNode(gradGArrow)
        SCNTransaction.commit()
    }

    /// Keeps markers readable through the translucent surface, like gizmos in 3D editors.
    private static func drawOnTop(_ node: SCNNode, order: Int = 100) {
        node.enumerateHierarchy { child, _ in
            child.renderingOrder = order
            child.geometry?.materials.forEach { $0.readsFromDepthBuffer = false }
        }
    }

    // MARK: - Static geometry

    private static func surfaceNode(_ mesh: SurfaceMesh) -> SCNNode {
        let vertices = mesh.positions.map(scenePoint)
        let normals = mesh.normals.map(scenePoint)
        var colorData = Data(capacity: mesh.normalizedHeights.count * 16)
        for height in mesh.normalizedHeights {
            var rgba = heightColor(height)
            withUnsafeBytes(of: &rgba) { colorData.append(contentsOf: $0) }
        }
        let colors = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: mesh.normalizedHeights.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals), colors],
            elements: [SCNGeometryElement(indices: mesh.triangleIndices, primitiveType: .triangles)]
        )
        let surfaceMaterial = SCNMaterial()
        surfaceMaterial.diffuse.contents = NSColor.white
        surfaceMaterial.lightingModel = .blinn
        surfaceMaterial.isDoubleSided = true
        surfaceMaterial.transparency = 0.82
        geometry.materials = [surfaceMaterial]
        let node = SCNNode(geometry: geometry)
        node.name = "surface"
        return node
    }

    private static func gridNode(_ mesh: SurfaceMesh) -> SCNNode {
        // Lift grid lines slightly along the normal so they do not flicker against the surface.
        let lifted = zip(mesh.positions, mesh.normals).map { scenePoint($0 + $1 * 0.006) }
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: lifted)],
            elements: [SCNGeometryElement(indices: mesh.gridLineIndices, primitiveType: .line)]
        )
        geometry.firstMaterial = material(NSColor.labelColor.withAlphaComponent(0.35), lit: false)
        let node = SCNNode(geometry: geometry)
        node.name = "surface-grid"
        return node
    }

    private static func constraintCylinderNode() -> SCNNode {
        let surfaceHeight = LagrangeSurfaceModel.domain.upperBound * LagrangeSurfaceModel.domain.upperBound
        let cylinder = SCNCylinder(radius: 1, height: CGFloat(2 * surfaceHeight + 0.2))
        let glass = material(NSColor.systemIndigo.withAlphaComponent(0.13), lit: false)
        glass.isDoubleSided = true
        glass.writesToDepthBuffer = false
        cylinder.materials = [glass]
        let node = SCNNode(geometry: cylinder)
        node.name = "constraint-cylinder"
        node.renderingOrder = 10
        return node
    }

    private static func constraintCurveNode() -> SCNNode {
        let node = SCNNode()
        node.name = "constraint-curve"
        let curve = LagrangeSurfaceModel.constraintCurve(samples: 120)
        for (start, end) in zip(curve, curve.dropFirst()) {
            node.addChildNode(segment(from: start, to: end, radius: 0.022, color: .systemIndigo))
        }
        // The same circle in the plane z = 0, where the 2D lab draws it.
        for (start, end) in zip(curve, curve.dropFirst()) {
            node.addChildNode(segment(
                from: SIMD3(start.x, start.y, 0),
                to: SIMD3(end.x, end.y, 0),
                radius: 0.008,
                color: NSColor.systemIndigo.withAlphaComponent(0.55)
            ))
        }
        return node
    }

    private static func stationaryMarkersNode() -> SCNNode {
        let node = SCNNode()
        node.name = "stationary-points"
        for (degrees, isMaximum) in [(45.0, true), (225.0, true), (135.0, false), (315.0, false)] {
            let angle = degrees * Double.pi / 180
            let point = SIMD3(cos(angle), sin(angle), cos(angle) * sin(angle))
            let marker = SCNNode(geometry: SCNSphere(radius: 0.05))
            marker.geometry?.firstMaterial = material(isMaximum ? .systemGreen : .systemRed)
            marker.position = scenePoint(point)
            node.addChildNode(marker)
        }
        return node
    }

    private static func axesNode() -> SCNNode {
        let node = SCNNode()
        node.name = "axes"
        let reach = 1.5
        let axes: [(SIMD3<Double>, String)] = [
            (SIMD3(reach, 0, 0), "x"),
            (SIMD3(0, reach, 0), "y"),
            (SIMD3(0, 0, reach), "z = xy"),
        ]
        for (direction, title) in axes {
            node.addChildNode(arrow(
                from: -direction,
                to: direction,
                color: NSColor.secondaryLabelColor,
                shaftRadius: 0.008,
                headRadius: 0.035
            ))
            let text = SCNText(string: title, extrusionDepth: 0)
            text.font = .systemFont(ofSize: 1, weight: .semibold)
            text.flatness = 0.1
            text.firstMaterial = material(.labelColor, lit: false)
            let label = SCNNode(geometry: text)
            let (minimum, maximum) = label.boundingBox
            label.pivot = SCNMatrix4MakeTranslation((minimum.x + maximum.x) / 2, 0, 0)
            label.scale = SCNVector3(0.16, 0.16, 0.16)
            label.position = scenePoint(direction * 1.1)
            label.constraints = [SCNBillboardConstraint()]
            node.addChildNode(label)
        }
        return node
    }

    // MARK: - Helpers

    /// Diverging scale: blue below zero, neutral at zero, orange above zero.
    static func heightColor(_ normalizedHeight: Double) -> SIMD4<Float> {
        let low = SIMD3<Float>(0.22, 0.47, 0.95)
        let middle = SIMD3<Float>(0.90, 0.90, 0.92)
        let high = SIMD3<Float>(0.97, 0.56, 0.16)
        let t = Float(max(0, min(1, normalizedHeight)))
        let rgb = t < 0.5
            ? low + (middle - low) * (t / 0.5)
            : middle + (high - middle) * ((t - 0.5) / 0.5)
        return SIMD4(rgb.x, rgb.y, rgb.z, 1)
    }

    private static func material(_ color: NSColor, lit: Bool = true) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = lit ? .blinn : .constant
        return material
    }

    private static func segment(from start: SIMD3<Double>, to end: SIMD3<Double>, radius: CGFloat, color: NSColor) -> SCNNode {
        let a = SIMD3<Float>(Float(start.x), Float(start.z), Float(-start.y))
        let b = SIMD3<Float>(Float(end.x), Float(end.z), Float(-end.y))
        let distance = simd_distance(a, b)
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(max(distance, 1e-4)))
        cylinder.radialSegmentCount = 12
        cylinder.firstMaterial = material(color)
        let node = SCNNode(geometry: cylinder)
        node.simdPosition = (a + b) / 2
        if distance > 1e-6 {
            node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(b - a))
        }
        return node
    }

    private static func arrow(
        from start: SIMD3<Double>,
        to end: SIMD3<Double>,
        color: NSColor,
        shaftRadius: CGFloat = 0.018,
        headRadius: CGFloat = 0.055
    ) -> SCNNode {
        let node = SCNNode()
        let delta = end - start
        let length = SurfacePlot3D.length(delta)
        guard length > 1e-6 else { return node }
        let headLength = min(0.16, length * 0.4)
        let shaftEnd = start + delta * ((length - headLength) / length)
        node.addChildNode(segment(from: start, to: shaftEnd, radius: shaftRadius, color: color))

        let cone = SCNCone(topRadius: 0, bottomRadius: headRadius, height: CGFloat(headLength))
        cone.firstMaterial = material(color)
        let head = SCNNode(geometry: cone)
        let a = SIMD3<Float>(Float(shaftEnd.x), Float(shaftEnd.z), Float(-shaftEnd.y))
        let b = SIMD3<Float>(Float(end.x), Float(end.z), Float(-end.y))
        head.simdPosition = (a + b) / 2
        head.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(b - a))
        node.addChildNode(head)
        return node
    }
}
