import SwiftUI
import SceneKit

/// Interactive 3D circuit map: the real track centerline extruded into a
/// ribbon, with a glowing racing line, corner markers, and a start gate.
/// Slowly auto-rotates; drag to orbit, pinch to zoom, tap a corner number to
/// fly in on that turn.
struct Track3DView: UIViewRepresentable {
    let map: TrackMap
    /// Incrementing this rebuilds the scene, snapping camera and rotation
    /// back to the initial framing.
    var resetToken: Int = 0
    /// Corner to highlight and zoom in on; nil shows the whole circuit.
    var selectedCorner: Int? = nil
    /// A corner number was tapped on the map (nil when tapped again).
    var onSelectCorner: ((Int?) -> Void)? = nil

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.scene = TrackSceneBuilder.build(map: map)
        context.coordinator.circuitName = map.circuitName
        context.coordinator.resetToken = resetToken
        context.coordinator.onSelectCorner = onSelectCorner
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:))))
        // Our own pinch replaces the built-in one, which zooms toward the
        // middle of the whole view (down behind the stats).
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinched(_:)))
        view.addGestureRecognizer(pinch)
        context.coordinator.pinch = pinch
        Self.disableBuiltInPinch(in: view, keeping: pinch)
        Self.highlight(selectedCorner, in: view)
        Self.focus(selectedCorner, in: view, animated: false)
        context.coordinator.selectedCorner = selectedCorner
        return view
    }

    /// Flies the camera in on a corner (and pauses the slow spin so it stays
    /// put), or back out to the whole circuit for nil. Pinch and drag then
    /// work around the turn.
    static func focus(_ number: Int?, in view: SCNView, animated: Bool = true) {
        guard let root = view.scene?.rootNode,
              let cameraNode = root.childNode(withName: "camera", recursively: false),
              let target = root.childNode(withName: "focus", recursively: false),
              let spinner = root.childNode(withName: "spinner", recursively: false) else { return }
        // Back to the scene camera if the user's gestures made a free one.
        view.pointOfView = cameraNode
        let corner = number.flatMap { root.childNode(withName: "corner-\($0)", recursively: true) }

        let look: SCNVector3
        let position: SCNVector3
        if let corner {
            spinner.removeAction(forKey: TrackSceneBuilder.spinKey)
            // The marker floats above the track; aim a little below it, and
            // come in from the side the camera is already on.
            // Where the marker is drawn (its stored transform can differ
            // under the billboard constraint and pivot).
            let c = corner.presentation.worldPosition
            var dx = cameraNode.position.x - c.x, dz = cameraNode.position.z - c.z
            let length = max(sqrt(dx * dx + dz * dz), 0.001)
            dx /= length
            dz /= length
            look = SCNVector3(c.x, c.y - 0.3, c.z)
            position = SCNVector3(c.x + dx * 2.8, c.y + 2.2, c.z + dz * 2.8)
        } else {
            if spinner.action(forKey: TrackSceneBuilder.spinKey) == nil {
                spinner.runAction(TrackSceneBuilder.spin, forKey: TrackSceneBuilder.spinKey)
            }
            look = SCNVector3(0, 0, 0)
            position = TrackSceneBuilder.homeCamera
        }

        // Fly by transform: bake the current (constrained) view in, drop the
        // look-at constraint, then animate to an exact pose facing the turn.
        let pose = SCNNode()
        pose.position = position
        pose.look(at: look, up: SCNVector3(0, 1, 0), localFront: TrackSceneBuilder.front)
        cameraNode.transform = cameraNode.presentation.transform
        cameraNode.constraints = nil
        target.position = look

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.9 : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        SCNTransaction.completionBlock = {
            // Back home: hand the camera to the centre constraint again.
            if corner == nil { cameraNode.constraints = [TrackSceneBuilder.lookAt(target)] }
        }
        cameraNode.transform = pose.transform
        SCNTransaction.commit()
        view.defaultCameraController.target = look
    }

    /// Switches off the pinch SceneKit adds for camera control.
    static func disableBuiltInPinch(in view: SCNView, keeping ours: UIGestureRecognizer?) {
        for recognizer in view.gestureRecognizers ?? [] where recognizer is UIPinchGestureRecognizer && recognizer !== ours {
            recognizer.isEnabled = false
        }
    }

    /// Selected corner: bigger and cyan; the others dim back.
    static func highlight(_ number: Int?, in view: SCNView) {
        view.scene?.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name, name.hasPrefix("corner-"), let n = Int(name.dropFirst(7)) else { return }
            let on = number == n
            let color: UIColor = on ? UIColor(red: 0.15, green: 0.82, blue: 1, alpha: 1)
                : UIColor(white: number == nil ? 0.85 : 0.45, alpha: 1)
            node.geometry?.firstMaterial?.diffuse.contents = color
            let s: Float = on ? 0.1 : 0.055
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.25
            node.scale = SCNVector3(s, s, s)
            SCNTransaction.commit()
        }
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onSelectCorner = onSelectCorner
        // SceneKit may add its recognizers after the view is made.
        Self.disableBuiltInPinch(in: view, keeping: context.coordinator.pinch)
        if context.coordinator.circuitName != map.circuitName || context.coordinator.resetToken != resetToken {
            context.coordinator.circuitName = map.circuitName
            context.coordinator.resetToken = resetToken
            view.scene = TrackSceneBuilder.build(map: map)
            // Drop any free camera the user's gestures created.
            view.pointOfView = view.scene?.rootNode.childNodes.first { $0.camera != nil }
            context.coordinator.selectedCorner = selectedCorner
            Self.highlight(selectedCorner, in: view)
            Self.focus(selectedCorner, in: view, animated: false)
        } else if context.coordinator.selectedCorner != selectedCorner {
            context.coordinator.selectedCorner = selectedCorner
            Self.highlight(selectedCorner, in: view)
            Self.focus(selectedCorner, in: view)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var circuitName: String?
        var resetToken = 0
        var selectedCorner: Int?
        var onSelectCorner: ((Int?) -> Void)?

        /// The corner number nearest the tap on screen (generous radius, the
        /// digits are small); tapping the selected one again zooms back out.
        /// Measured where each number is drawn (`presentation`): the stored
        /// position doesn't follow the spin and sat 100–140 pt away on screen,
        /// so taps missed or picked the wrong turn.
        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView, let root = view.scene?.rootNode else { return }
            let point = gesture.location(in: view)
            var best: (number: Int, distance: CGFloat)?
            root.enumerateChildNodes { node, _ in
                guard let name = node.name, name.hasPrefix("corner-"), let n = Int(name.dropFirst(7)) else { return }
                let p = view.projectPoint(node.presentation.worldPosition)
                guard p.z > 0, p.z < 1 else { return }
                let d = hypot(CGFloat(p.x) - point.x, CGFloat(p.y) - point.y)
                if d < 40, d < (best?.distance ?? .infinity) { best = (n, d) }
            }
            guard let best else { return }
            onSelectCorner?(best.number == selectedCorner ? nil : best.number)
        }

        weak var pinch: UIPinchGestureRecognizer?
        private var lastScale: CGFloat = 1

        /// Pinch moves the camera straight toward (or away from) the point
        /// it looks at: the circuit's centre or the chosen turn, which sits
        /// in the middle of the visible map. That point stays put on screen
        /// and everything grows around it.
        @objc func pinched(_ gesture: UIPinchGestureRecognizer) {
            pinch = gesture
            guard let view = gesture.view as? SCNView, let camera = view.pointOfView else { return }
            switch gesture.state {
            case .began:
                lastScale = 1
            case .changed:
                let step = Float(gesture.scale / lastScale)
                lastScale = gesture.scale
                guard step > 0 else { return }
                let target = view.defaultCameraController.target
                let p = camera.worldPosition
                let d = SCNVector3(p.x - target.x, p.y - target.y, p.z - target.z)
                let length = sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
                guard length > 0.001 else { return }
                let newLength = min(max(length / step, 1.2), 30)
                let k = newLength / length
                camera.worldPosition = SCNVector3(target.x + d.x * k, target.y + d.y * k, target.z + d.z * k)
            default:
                break
            }
        }
    }
}

enum TrackSceneBuilder {
    static let spinKey = "spin"
    static var spin: SCNAction { .repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 45)) }
    static let homeCamera = SCNVector3(0, 7.5, 10.5)

    /// The scene runs behind the whole circuit card and fades out at the
    /// bottom: `framed` points of it are the map proper, `bleed` more run
    /// under the stats. The camera looks a little low (`tilt`) so the
    /// circuit, or the turn it flies to, stays centred in the framed part.
    static let framed: CGFloat = 300
    static let bleed: CGFloat = 170
    /// Horizontal field of view: the circuit keeps its width however tall
    /// the view is.
    static let fieldOfView: CGFloat = 75
    private static let tilt = atan(Float(bleed / 390) * tan(Float(fieldOfView / 2 * .pi / 180)))
    /// The camera's "front" for look-at, pitched up by `tilt`, so the real
    /// view axis points that much below the target.
    static let front = SCNVector3(0, sin(tilt), -cos(tilt))

    static func lookAt(_ target: SCNNode) -> SCNLookAtConstraint {
        let constraint = SCNLookAtConstraint(target: target)
        constraint.localFront = front
        return constraint
    }

    static func build(map: TrackMap) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let points = normalizedPoints(map: map)
        guard points.count > 2 else { return scene }

        // Spinner carries the slow auto-rotation; the flat track node inside it
        // holds everything positioned in the 2D map plane.
        let spinner = SCNNode()
        spinner.name = "spinner"
        let flat = SCNNode()
        flat.eulerAngles.x = -.pi / 2
        spinner.addChildNode(flat)
        scene.rootNode.addChildNode(spinner)

        // Asphalt ribbon with a hint of thickness (top face + slightly lower
        // shadow face reads as a slab from shallow angles).
        let asphalt = SCNMaterial()
        asphalt.lightingModel = .constant
        asphalt.diffuse.contents = UIColor(white: 0.16, alpha: 1)
        asphalt.isDoubleSided = true
        // Wide ribbons use a strided centerline: fewer points means fewer
        // folded slivers at hairpins, and the width hides the difference.
        let roadPoints = stride(from: 0, to: points.count, by: 2).map { points[$0] }
        let ribbon = SCNNode(geometry: ribbonGeometry(points: roadPoints, halfWidth: 0.15, material: asphalt))
        flat.addChildNode(ribbon)

        let edge = SCNMaterial()
        edge.lightingModel = .constant
        edge.diffuse.contents = UIColor(white: 0.32, alpha: 1)
        edge.isDoubleSided = true
        let underlay = SCNNode(geometry: ribbonGeometry(points: roadPoints, halfWidth: 0.18, material: edge))
        underlay.position.z = -0.03
        flat.addChildNode(underlay)

        // Glowing racing line in the three timing-sector colors.
        // Saturated sector trio (blue / violet / red) — emissions stay deep
        // in hue so bloom can't wash the line out to white at map scale.
        let sectorColors: [(UIColor, UIColor)] = [
            (UIColor(red: 0.08, green: 0.72, blue: 1.0, alpha: 1),
             UIColor(red: 0.14, green: 0.80, blue: 1.0, alpha: 1)),   // S1 icy cyan
            (UIColor(red: 0.46, green: 0.32, blue: 1.0, alpha: 1),
             UIColor(red: 0.52, green: 0.38, blue: 1.0, alpha: 1)),   // S2 violet
            (UIColor(red: 0.95, green: 0.22, blue: 0.09, alpha: 1),
             UIColor(red: 1.0, green: 0.3, blue: 0.13, alpha: 1)),    // S3 red
        ]
        let third = points.count / 3
        for s in 0..<3 {
            // Each sector runs past its boundary so the next one's start
            // covers the seam — no torn line ends at any zoom.
            var arc: [(x: Float, y: Float, h: Float)] = []
            for i in 0..<(third + 14) {
                arc.append(points[(s * third + i) % points.count])
            }
            let glow = SCNMaterial()
            glow.lightingModel = .constant
            glow.diffuse.contents = sectorColors[s].0
            glow.emission.contents = sectorColors[s].1
            glow.isDoubleSided = true
            let line = SCNNode(geometry: ribbonGeometry(points: arc, halfWidth: 0.042, material: glow, closed: false))
            // Each sector sits a hair above the previous so overlaps stack
            // cleanly instead of z-fighting into speckles.
            line.position.z = 0.02 + Float(s) * 0.006
            flat.addChildNode(line)
        }

        // Start/finish gate at the first centerline point.
        let gate = SCNNode(geometry: SCNBox(width: 0.55, height: 0.07, length: 0.16, chamferRadius: 0.01))
        gate.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        gate.geometry?.firstMaterial?.emission.contents = UIColor(white: 0.7, alpha: 1)
        gate.position = SCNVector3(points[0].x, points[0].y, points[0].h + 0.06)
        let next = points[1]
        gate.eulerAngles.z = Float(atan2(next.y - points[0].y, next.x - points[0].x)) + .pi / 2
        flat.addChildNode(gate)

        // Corner number markers.
        for corner in map.corners {
            let p = normalize(corner.trackPosition.x, corner.trackPosition.y, map: map)
            let h = points.min(by: { hypot($0.x - p.x, $0.y - p.y) < hypot($1.x - p.x, $1.y - p.y) })?.h ?? 0
            let text = SCNText(string: "\(corner.number)", extrusionDepth: 0.4)
            text.font = UIFont.systemFont(ofSize: 5, weight: .heavy)
            text.flatness = 0.04
            text.firstMaterial?.lightingModel = .constant
            text.firstMaterial?.diffuse.contents = UIColor(white: 0.85, alpha: 1)

            let node = SCNNode(geometry: text)
            node.name = "corner-\(corner.number)"
            node.scale = SCNVector3(0.055, 0.055, 0.055)
            // Center the glyph on the corner position, lifted off the track.
            let (minB, maxB) = text.boundingBox
            node.pivot = SCNMatrix4MakeTranslation((maxB.x + minB.x) / 2, (maxB.y + minB.y) / 2, 0)
            node.position = SCNVector3(p.x, p.y, h + 0.4)
            node.constraints = [SCNBillboardConstraint()]
            flat.addChildNode(node)
        }

        // Ghost car: a glowing marble lapping the circuit at constant speed.
        let car = SCNNode(geometry: SCNSphere(radius: 0.085))
        car.geometry?.firstMaterial?.lightingModel = .constant
        car.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        car.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 1)
        let path = stride(from: 0, to: points.count, by: 8).map { points[$0] } + [points[0]]
        var lapLength: Float = 0
        for i in 1..<path.count {
            lapLength += hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y)
        }
        let lapSeconds: Float = 24
        var moves: [SCNAction] = []
        for i in 1..<path.count {
            let seg = hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y)
            moves.append(.move(to: SCNVector3(path[i].x, path[i].y, path[i].h + 0.09),
                               duration: Double(seg / lapLength * lapSeconds)))
        }
        car.position = SCNVector3(path[0].x, path[0].y, path[0].h + 0.09)
        car.runAction(.repeatForever(.sequence(moves)))
        flat.addChildNode(car)

        // Slow orbit; user gestures move the camera independently.
        spinner.runAction(spin, forKey: spinKey)

        // Lights.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 750
        sun.eulerAngles = SCNVector3(-Float.pi / 3, 0.4, 0)
        scene.rootNode.addChildNode(sun)

        // Camera with a touch of bloom so the racing line glows.
        let camera = SCNCamera()
        camera.wantsHDR = true
        // The scene is mostly black; adaptive exposure would crank the gain
        // and bleach every color toward white. Lock it.
        camera.wantsExposureAdaptation = false
        camera.bloomIntensity = 0.5
        camera.bloomThreshold = 0.55
        camera.zFar = 200
        camera.projectionDirection = .horizontal
        camera.fieldOfView = fieldOfView
        // The camera looks at a focus point: the circuit's centre, or the
        // tapped corner (Track3DView.focus moves both).
        let focus = SCNNode()
        focus.name = "focus"
        scene.rootNode.addChildNode(focus)
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = homeCamera
        cameraNode.constraints = [lookAt(focus)]
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }

    // MARK: - Geometry helpers

    /// Center-of-mass and scale used to map decimeter coordinates into a
    /// roughly 10-unit-wide scene.
    private static func bounds(map: TrackMap) -> (cx: Double, cy: Double, scale: Double) {
        let minX = map.x.min() ?? 0, maxX = map.x.max() ?? 1
        let minY = map.y.min() ?? 0, maxY = map.y.max() ?? 1
        let span = max(maxX - minX, maxY - minY, 1)
        return ((minX + maxX) / 2, (minY + maxY) / 2, 10.0 / span)
    }

    private static func normalize(_ x: Double, _ y: Double, map: TrackMap) -> (x: Float, y: Float) {
        normalize(x, y, bounds: bounds(map: map))
    }

    /// With the bounds worked out once: per point, measuring the whole map
    /// again made building a circuit quadratic (a 300 ms freeze per switch).
    private static func normalize(_ x: Double, _ y: Double, bounds b: (cx: Double, cy: Double, scale: Double)) -> (x: Float, y: Float) {
        (Float((x - b.cx) * b.scale), Float((y - b.cy) * b.scale))
    }

    /// Elevation is exaggerated so 20–30 m of real grade reads clearly at
    /// map scale instead of vanishing.
    private static func normalizedPoints(map: TrackMap) -> [(x: Float, y: Float, h: Float)] {
        guard map.x.count == map.y.count else { return [] }
        let b = bounds(map: map)
        let heights: [Float]
        if let z = map.z, z.count == map.x.count {
            heights = z.map { Float($0 * b.scale * 2.4) }
        } else {
            heights = [Float](repeating: 0, count: map.x.count)
        }
        let raw = zip(zip(map.x, map.y), heights).map { pair, h in
            let p = normalize(pair.0, pair.1, bounds: b)
            return (x: p.x, y: p.y, h: h)
        }
        // Two Chaikin passes: corner-cutting subdivision that keeps the ribbon
        // silky even when the user zooms right into an apex.
        return chaikin(chaikin(raw))
    }

    /// One closed-loop Chaikin corner-cutting pass (doubles the point count).
    private static func chaikin(_ pts: [(x: Float, y: Float, h: Float)]) -> [(x: Float, y: Float, h: Float)] {
        guard pts.count > 2 else { return pts }
        var out: [(x: Float, y: Float, h: Float)] = []
        out.reserveCapacity(pts.count * 2)
        for i in 0..<pts.count {
            let a = pts[i]
            let b = pts[(i + 1) % pts.count]
            out.append((a.x * 0.75 + b.x * 0.25, a.y * 0.75 + b.y * 0.25, a.h * 0.75 + b.h * 0.25))
            out.append((a.x * 0.25 + b.x * 0.75, a.y * 0.25 + b.y * 0.75, a.h * 0.25 + b.h * 0.75))
        }
        return out
    }

    /// Builds the track ribbon as an explicit triangle strip between the
    /// centerline offset left and right — no triangulation involved, so it
    /// can never accidentally fill the infield. Follows per-point elevation.
    private static func ribbonGeometry(
        points: [(x: Float, y: Float, h: Float)], halfWidth: Float,
        material: SCNMaterial, closed: Bool = true
    ) -> SCNGeometry {
        let n = points.count
        var vertices: [SCNVector3] = []
        vertices.reserveCapacity(2 * (n + 1))

        let last = closed ? n : n - 1
        for i in 0...last {
            let index = i % n
            let prev = points[closed ? (index - 1 + n) % n : max(index - 1, 0)]
            let next = points[closed ? (index + 1) % n : min(index + 1, n - 1)]
            var dx = next.x - prev.x
            var dy = next.y - prev.y
            let len = max(sqrt(dx * dx + dy * dy), 0.0001)
            dx /= len
            dy /= len
            let p = points[index]
            vertices.append(SCNVector3(p.x - dy * halfWidth, p.y + dx * halfWidth, p.h))
            vertices.append(SCNVector3(p.x + dy * halfWidth, p.y - dx * halfWidth, p.h))
        }

        let normals = [SCNVector3](repeating: SCNVector3(0, 0, 1), count: vertices.count)
        let indices = (0..<UInt32(vertices.count)).map { $0 }
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangleStrip)]
        )
        geometry.materials = [material]
        return geometry
    }
}
