import SwiftUI
import SceneKit

/// Interactive 3D circuit map: the real track centerline extruded into a
/// ribbon, with a glowing racing line, corner markers, and a start gate.
/// Slowly auto-rotates; drag to orbit, pinch to zoom.
struct Track3DView: UIViewRepresentable {
    let map: TrackMap
    /// Incrementing this rebuilds the scene, snapping camera and rotation
    /// back to the initial framing.
    var resetToken: Int = 0

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.scene = TrackSceneBuilder.build(map: map)
        context.coordinator.circuitName = map.circuitName
        context.coordinator.resetToken = resetToken
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard context.coordinator.circuitName != map.circuitName
                || context.coordinator.resetToken != resetToken else { return }
        context.coordinator.circuitName = map.circuitName
        context.coordinator.resetToken = resetToken
        view.scene = TrackSceneBuilder.build(map: map)
        // Drop any free camera the user's gestures created.
        view.pointOfView = view.scene?.rootNode.childNodes.first { $0.camera != nil }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var circuitName: String?
        var resetToken = 0
    }
}

enum TrackSceneBuilder {
    static func build(map: TrackMap) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let points = normalizedPoints(map: map)
        guard points.count > 2 else { return scene }

        // Spinner carries the slow auto-rotation; the flat track node inside it
        // holds everything positioned in the 2D map plane.
        let spinner = SCNNode()
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
            (UIColor(red: 0.10, green: 0.55, blue: 1.0, alpha: 1),
             UIColor(red: 0.14, green: 0.62, blue: 1.0, alpha: 1)),   // S1 electric blue
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
        spinner.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 45)))

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
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 7.5, 10.5)
        cameraNode.constraints = [SCNLookAtConstraint(target: spinner)]
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
        let b = bounds(map: map)
        return (Float((x - b.cx) * b.scale), Float((y - b.cy) * b.scale))
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
            let p = normalize(pair.0, pair.1, map: map)
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
