//
//  SolarSystemSceneView.swift
//  MiniPi
//
//  SceneKit scene for the Explore tab (Module A), NASA-"Eyes on Asteroids"-style:
//  starfield background, Sun + inner planets as reference, real NEOs gliding along
//  their true orbital ellipses (drawn as faint paths), with name labels. The camera
//  orbits the Sun (drag), pinches to zoom, and tap a body to select it.
//

import SwiftUI
import SceneKit
import UIKit

struct SolarSystemSceneView: UIViewRepresentable {

    let asteroids: [Asteroid]
    let date: Date
    let selectedID: String?
    let onSelect: (Asteroid) -> Void
    let onSelectPlanet: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onSelectPlanet: onSelectPlanet)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling2X
        context.coordinator.attach(to: scnView)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.onSelectPlanet = onSelectPlanet
        context.coordinator.update(asteroids: asteroids, date: date, selectedID: selectedID)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        var onSelect: (Asteroid) -> Void
        var onSelectPlanet: (String) -> Void
        let scene: SCNScene
        private weak var scnView: SCNView?

        private let asteroidsRoot = SCNNode()
        private let orbitsRoot = SCNNode()         // asteroid orbital ellipses
        private var asteroidNodes: [String: SCNNode] = [:]
        private var selectionStates: [String: Bool] = [:]    // last applied selected-flag per body
        private var asteroidLabels: [String: SCNNode] = [:]  // hazardous-always labels
        private var asteroidLookup: [String: Asteroid] = [:]
        private var lastAsteroidKey: String = ""

        private struct Planet {
            let node: SCNNode; let label: SCNNode
            let radiusAU: Double; let periodDays: Double
        }
        private var planets: [Planet] = []

        private let auScale: CGFloat = 1.0
        private let j2000 = Date(timeIntervalSince1970: 946_728_000) // 2000-01-01 12:00 UTC

        private var selectionLabel: SCNNode?

        init(onSelect: @escaping (Asteroid) -> Void,
             onSelectPlanet: @escaping (String) -> Void) {
            self.onSelect = onSelect
            self.onSelectPlanet = onSelectPlanet
            self.scene = SCNScene()
            super.init()
            buildScene()
        }

        func attach(to view: SCNView) {
            self.scnView = view
            // The camera must live in the scene graph: otherwise the controller can't
            // lock its orbit target (the Sun drifts on pan) and hitTest gets a broken
            // projection (taps miss every body).
            let cam = cameraNode()
            scene.rootNode.addChildNode(cam)
            view.pointOfView = cam

            // Orbit the Sun: drag always rotates around the target (no panning the Sun away).
            let controller = view.defaultCameraController
            controller.pointOfView = cam
            controller.target = SCNVector3Zero
            controller.interactionMode = .orbitTurntable
            controller.inertiaEnabled = true

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.delegate = self
            tap.cancelsTouchesInView = false
            view.addGestureRecognizer(tap)
        }

        // MARK: Scene construction

        private func buildScene() {
            scene.background.contents = starfield(size: 1024, stars: 800)

            let ambient = SCNLight(); ambient.type = .ambient; ambient.color = UIColor(white: 0.22, alpha: 1)
            let ambientNode = SCNNode(); ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            // Sun (emissive) with an omni light at its centre.
            let sunColor = UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1)
            let sun = SCNNode(geometry: sphere(radius: 0.14, color: sunColor))
            sun.geometry?.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.72, blue: 0.25, alpha: 1)
            let sunLight = SCNLight(); sunLight.type = .omni; sunLight.color = UIColor.white
            sun.light = sunLight
            scene.rootNode.addChildNode(sun)

            let sunLabel = makeLabel("Sun")
            sunLabel.position = SCNVector3(0, 0.2, 0)
            scene.rootNode.addChildNode(sunLabel)

            let defs: [(name: String, aAU: Double, r: CGFloat, color: UIColor, period: Double)] = [
                ("Mercury", 0.39, 0.032, UIColor(white: 0.62, alpha: 1), 88),
                ("Venus",   0.72, 0.046, UIColor(red: 0.92, green: 0.74, blue: 0.46, alpha: 1), 225),
                ("Earth",   1.00, 0.050, UIColor(red: 0.28, green: 0.56, blue: 0.95, alpha: 1), 365),
                ("Mars",    1.52, 0.040, UIColor(red: 0.86, green: 0.36, blue: 0.22, alpha: 1), 687),
            ]
            for d in defs {
                let node = SCNNode(geometry: sphere(radius: d.r, color: d.color))
                node.name = "planet:\(d.name)"
                node.geometry?.firstMaterial?.shininess = 0.2
                scene.rootNode.addChildNode(node)
                scene.rootNode.addChildNode(orbitRing(radius: CGFloat(d.aAU) * auScale))
                let label = makeLabel(d.name, size: 10)
                scene.rootNode.addChildNode(label)
                planets.append(Planet(node: node, label: label, radiusAU: d.aAU, periodDays: d.period))
            }

            scene.rootNode.addChildNode(orbitsRoot)
            scene.rootNode.addChildNode(asteroidsRoot)
        }

        private func cameraNode() -> SCNNode {
            let camera = SCNCamera()
            camera.fieldOfView = 50
            let node = SCNNode()
            node.camera = camera
            node.position = SCNVector3(0, 3.4, 6.2)
            node.eulerAngles = SCNVector3(-0.52, 0, 0)
            return node
        }

        // MARK: Per-frame update

        func update(asteroids: [Asteroid], date: Date, selectedID: String?) {
            // Keep the Sun pinned at the centre: re-assert the orbit target every frame
            // so no gesture (e.g. a two-finger pan) can ever drift it away from the origin.
            scnView?.defaultCameraController.target = SCNVector3Zero

            asteroidLookup = Dictionary(uniqueKeysWithValues: asteroids.map { ($0.id, $0) })

            let days = date.timeIntervalSince(j2000) / 86_400.0
            for planet in planets {
                let theta = 2 * .pi * (days / planet.periodDays)
                let p = eclipticToScene(planet.radiusAU * cos(theta), planet.radiusAU * sin(theta), 0)
                planet.node.position = p
                planet.label.position = SCNVector3(p.x, p.y + 0.09, p.z)
            }

            let key = asteroids.map(\.id).joined(separator: ",")
            if key != lastAsteroidKey {
                rebuildOrbits(asteroids)
                rebuildHazardousLabels(asteroids)
                lastAsteroidKey = key
            }

            let ids = Set(asteroids.map { $0.id })
            for (id, node) in asteroidNodes where !ids.contains(id) {
                node.removeFromParentNode()
                asteroidNodes.removeValue(forKey: id)
                selectionStates.removeValue(forKey: id)
            }

            for asteroid in asteroids {
                let isSelected = selectedID == asteroid.id
                let node: SCNNode
                if let existing = asteroidNodes[asteroid.id] {
                    node = existing
                    // Restyle only when selection changes — avoids rebuilding every
                    // asteroid's geometry 60×/sec with a crowded scene.
                    if selectionStates[asteroid.id] != isSelected {
                        applyAsteroidStyle(node, asteroid: asteroid, selected: isSelected)
                        selectionStates[asteroid.id] = isSelected
                    }
                } else {
                    node = makeAsteroidNode(asteroid, selected: isSelected)
                    asteroidNodes[asteroid.id] = node
                    selectionStates[asteroid.id] = isSelected
                    asteroidsRoot.addChildNode(node)
                }
                node.name = asteroid.id

                let pos: SCNVector3
                if let p = GetAsteroidPositionsUseCase.position(of: asteroid, at: date) {
                    pos = eclipticToScene(p.x, p.y, p.z)
                    node.position = pos
                    node.isHidden = false
                } else {
                    node.isHidden = true
                    pos = node.position
                }

                // Hazardous "important" label follows the body.
                if let label = asteroidLabels[asteroid.id] {
                    label.position = SCNVector3(pos.x, pos.y + 0.1, pos.z)
                    label.isHidden = node.isHidden
                }
            }

            updateSelectionLabel(selectedID: selectedID, date: date)
        }

        /// Draws orbit ellipses only for hazardous bodies — with a crowded catalog
        /// scene, drawing every orbit turns into visual noise.
        private func rebuildOrbits(_ asteroids: [Asteroid]) {
            orbitsRoot.childNodes.forEach { $0.removeFromParentNode() }
            for asteroid in asteroids where asteroid.isPotentiallyHazardous {
                guard let verts = GetAsteroidPositionsUseCase.orbitVertices(of: asteroid) else { continue }
                let points = verts.map { eclipticToScene($0.x, $0.y, $0.z) }
                let color = UIColor(red: 0.98, green: 0.66, blue: 0.16, alpha: 1)
                orbitsRoot.addChildNode(lineNode(points: points, color: color))
            }
        }

        /// Always-on labels only for hazardous ("important") asteroids — keeps the scene uncluttered.
        private func rebuildHazardousLabels(_ asteroids: [Asteroid]) {
            for (_, label) in asteroidLabels { label.removeFromParentNode() }
            asteroidLabels.removeAll()
            for asteroid in asteroids where asteroid.isPotentiallyHazardous {
                let label = makeLabel(asteroid.name, color: UIColor(red: 0.98, green: 0.7, blue: 0.25, alpha: 1), size: 9)
                scene.rootNode.addChildNode(label)
                asteroidLabels[asteroid.id] = label
            }
        }

        private func updateSelectionLabel(selectedID: String?, date: Date) {
            guard let id = selectedID, let asteroid = asteroidLookup[id],
                  let p = GetAsteroidPositionsUseCase.position(of: asteroid, at: date) else {
                selectionLabel?.isHidden = true
                return
            }
            if selectionLabel == nil {
                let label = makeLabel(asteroid.name, color: .white, size: 12)
                scene.rootNode.addChildNode(label)
                selectionLabel = label
            }
            selectionLabel?.isHidden = false
            if let t = selectionLabel?.geometry as? SCNText, t.string as? String != asteroid.name {
                t.string = asteroid.name
            }
            let pos = eclipticToScene(p.x, p.y, p.z)
            selectionLabel?.position = SCNVector3(pos.x, pos.y + 0.12, pos.z)
        }

        // MARK: Tap → select the body (iterate hits so orbit lines don't block it).
        // We don't reframe the camera onto the body — that would move the orbit target
        // off the Sun. The Sun stays centred; tapping just opens the detail card.

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView, gesture.state == .ended else { return }
            let location = gesture.location(in: view)
            for hit in view.hitTest(location, options: [:]) {
                // Walk up through unnamed helper nodes (hit spheres, labels, orbit
                // lines) to the first named ancestor.
                var node = hit.node
                while node.name == nil, let parent = node.parent { node = parent }
                guard let name = node.name else { continue }

                if name.hasPrefix("planet:") {
                    onSelectPlanet(String(name.dropFirst("planet:".count)))
                    return
                } else if let asteroid = asteroidLookup[name] {
                    onSelect(asteroid)
                    return
                }
                // A named node we don't recognise (e.g. a body that's stale in the
                // lookup) — keep scanning the remaining hits instead of giving up.
            }
        }

        // MARK: Geometry helpers

        private func makeAsteroidNode(_ asteroid: Asteroid, selected: Bool) -> SCNNode {
            let node = SCNNode()
            applyAsteroidStyle(node, asteroid: asteroid, selected: selected)

            // Invisible-but-hittable target. The visual body is tiny (~0.02) and
            // moving, so a larger sphere makes taps reliable for *any* asteroid.
            // Important: `transparency = 0` is treated as "not there" by hit testing,
            // so we keep the material opaque (transparency 1) and make it visually
            // invisible via a ~0 alpha diffuse instead. Left unnamed so the tap
            // handler walks up through it to the asteroid node.
            let hit = SCNNode(geometry: SCNSphere(radius: 0.12))
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(white: 1, alpha: 0.001)
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.transparency = 1.0
            m.writesToDepthBuffer = false
            hit.geometry?.materials = [m]
            node.addChildNode(hit)
            return node
        }

        private func applyAsteroidStyle(_ node: SCNNode, asteroid: Asteroid, selected: Bool) {
            let color = asteroid.isPotentiallyHazardous
                ? UIColor(red: 0.98, green: 0.66, blue: 0.16, alpha: 1)
                : UIColor(red: 0.38, green: 0.82, blue: 0.98, alpha: 1)
            let radius: CGFloat = selected ? 0.03 : 0.02
            node.geometry = sphere(radius: radius, color: color)
            node.geometry?.firstMaterial?.emission.contents = color
        }

        private func sphere(radius: CGFloat, color: UIColor) -> SCNGeometry {
            let g = SCNSphere(radius: radius)
            g.firstMaterial?.diffuse.contents = color
            g.firstMaterial?.lightingModel = .blinn
            return g
        }

        /// Visible thick ring for planet orbits.
        private func orbitRing(radius: CGFloat) -> SCNNode {
            let torus = SCNTorus(ringRadius: radius, pipeRadius: 0.005)
            let m = SCNMaterial()
            m.diffuse.contents = UIColor.clear
            m.emission.contents = UIColor.white.withAlphaComponent(0.55)
            m.lightingModel = .constant
            m.isDoubleSided = true
            torus.materials = [m]
            let node = SCNNode(geometry: torus)
            node.eulerAngles = SCNVector3(Float.pi / 2, 0, 0) // lay flat in the ecliptic (xz) plane
            return node
        }

        /// Vivid, always-on-top line for an asteroid's orbital ellipse.
        private func lineNode(points: [SCNVector3], color: UIColor) -> SCNNode {
            var idx: [Int32] = []
            for i in 0..<(points.count - 1) { idx.append(Int32(i)); idx.append(Int32(i + 1)) }
            let source = SCNGeometrySource(vertices: points)
            let element = SCNGeometryElement(indices: idx, primitiveType: .line)
            let geo = SCNGeometry(sources: [source], elements: [element])
            let m = SCNMaterial()
            m.diffuse.contents = color
            m.emission.contents = color
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.writesToDepthBuffer = false
            m.readsFromDepthBuffer = false
            geo.materials = [m]
            return SCNNode(geometry: geo)
        }

        private func makeLabel(_ text: String, color: UIColor = .white, size: CGFloat = 12) -> SCNNode {
            let t = SCNText(string: text, extrusionDepth: 0)
            t.font = UIFont.systemFont(ofSize: size, weight: .semibold)
            t.flatness = 0.6
            let m = SCNMaterial()
            m.diffuse.contents = color
            m.emission.contents = color
            m.lightingModel = .constant
            t.materials = [m]
            let node = SCNNode(geometry: t)
            node.scale = SCNVector3(0.01, 0.01, 0.01)
            node.constraints = [SCNBillboardConstraint()]
            return node
        }

        /// Ecliptic (X in-plane, Y in-plane, Z out-of-plane) → scene (x, y=Z, z=Y) × AU scale.
        private func eclipticToScene(_ x: Double, _ y: Double, _ z: Double) -> SCNVector3 {
            SCNVector3(Float(x * auScale), Float(z * auScale), Float(y * auScale))
        }

        // MARK: Starfield

        private func starfield(size: Int, stars: Int) -> UIImage {
            let sz = CGSize(width: size, height: size)
            return UIGraphicsImageRenderer(size: sz).image { ctx in
                let cg = ctx.cgContext
                cg.setFillColor(UIColor.black.cgColor)
                cg.fill(CGRect(origin: .zero, size: sz))
                for _ in 0..<stars {
                    let x = CGFloat.random(in: 0...sz.width)
                    let y = CGFloat.random(in: 0...sz.height)
                    let r = CGFloat.random(in: 0.4...1.6)
                    let b = CGFloat.random(in: 0.35...1.0)
                    cg.setFillColor(UIColor(white: b, alpha: 1).cgColor)
                    cg.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                }
                for _ in 0..<40 {
                    let x = CGFloat.random(in: 0...sz.width)
                    let y = CGFloat.random(in: 0...sz.height)
                    cg.setFillColor(UIColor.white.cgColor)
                    cg.fillEllipse(in: CGRect(x: x, y: y, width: 2.4, height: 2.4))
                }
            }
        }
    }
}
