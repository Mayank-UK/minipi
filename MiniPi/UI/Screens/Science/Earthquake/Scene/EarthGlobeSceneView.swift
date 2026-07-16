//
//  EarthGlobeSceneView.swift
//  MiniPi
//
//  SceneKit scene for the earthquake Map tab: a 3D Earth globe with magnitude-
//  coloured markers at each event's lat/lon, on a starfield. The camera orbits
//  Earth (drag) and pinches to zoom; tap a marker to open its detail sheet.
//  Mirrors SolarSystemSceneView's UIViewRepresentable + Coordinator structure,
//  including the larger invisible hittable target + hit-test walk-up trick that
//  makes tapping small moving markers reliable.
//

import SwiftUI
import SceneKit
import UIKit

struct EarthGlobeSceneView: UIViewRepresentable {

    let earthquakes: [Earthquake]
    let selectedID: String?
    let onSelect: (Earthquake) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
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
        context.coordinator.update(earthquakes: earthquakes, selectedID: selectedID)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        var onSelect: (Earthquake) -> Void
        let scene: SCNScene
        private weak var scnView: SCNView?

        private let earthRadius: CGFloat = 1.0
        private var markersRoot = SCNNode()
        private var markerNodes: [String: SCNNode] = [:]
        private var selectionStates: [String: Bool] = [:]
        private var lookup: [String: Earthquake] = [:]
        private var lastKey: String = ""

        init(onSelect: @escaping (Earthquake) -> Void) {
            self.onSelect = onSelect
            self.scene = SCNScene()
            super.init()
            buildScene()
        }

        func attach(to view: SCNView) {
            self.scnView = view

            let cam = SCNNode()
            cam.camera = SCNCamera()
            cam.camera?.fieldOfView = 50
            cam.position = SCNVector3(0, 0, 3.2)
            scene.rootNode.addChildNode(cam)
            view.pointOfView = cam

            // Orbit Earth: drag always rotates around the globe's centre.
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
            scene.background.contents = Self.starfield(size: 1024, stars: 900)

            // Earth — an equirectangular NASA Blue Marble texture on the sphere, so
            // continents/oceans are recognisable and quake markers can be read
            // against real geography. The texture's centre (prime meridian) maps to
            // +X; see `surfacePosition` for the matching lat/lon → cartesian math.
            let earthGeo = SCNSphere(radius: earthRadius)
            let material = SCNMaterial()
            material.diffuse.contents = UIImage(named: "earth_texture") ?? UIImage()
            material.lightingModel = .blinn
            material.shininess = 0.25
            material.isDoubleSided = false
            earthGeo.materials = [material]
            let earth = SCNNode(geometry: earthGeo)

            // Slow axial rotation for life.
            let spin = CABasicAnimation(keyPath: "rotation")
            spin.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, CGFloat.pi * 2))
            spin.duration = 90
            spin.repeatCount = .infinity
            earth.addAnimation(spin, forKey: "spin")
            scene.rootNode.addChildNode(earth)

            // A "sun" directional light angled so the lit hemisphere shows the
            // texture in full colour while the far side falls off naturally.
            let sun = SCNLight()
            sun.type = .directional
            sun.color = UIColor.white
            sun.intensity = 1200
            let sunNode = SCNNode()
            sunNode.light = sun
            sunNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
            scene.rootNode.addChildNode(sunNode)

            // Soft ambient fill so the night side isn't pure black.
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = UIColor(white: 0.18, alpha: 1)
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            // Faint atmosphere halo.
            let atmosphere = SCNNode(geometry: Self.sphere(radius: earthRadius * 1.04,
                                                           color: UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.10)))
            atmosphere.geometry?.firstMaterial?.lightingModel = .constant
            atmosphere.geometry?.firstMaterial?.isDoubleSided = true
            scene.rootNode.addChildNode(atmosphere)

            // Markers live UNDER the spinning earth node so they rotate with the
            // texture and stay glued to their geography.
            earth.addChildNode(markersRoot)
        }

        // MARK: Per-update

        func update(earthquakes: [Earthquake], selectedID: String?) {
            // Keep Earth centred under any gesture.
            scnView?.defaultCameraController.target = SCNVector3Zero

            lookup = Dictionary(uniqueKeysWithValues: earthquakes.map { ($0.id, $0) })

            let key = earthquakes.map(\.id).joined(separator: ",")
            if key != lastKey {
                // Remove stale markers.
                let ids = Set(earthquakes.map { $0.id })
                for (id, node) in markerNodes where !ids.contains(id) {
                    node.removeFromParentNode()
                    markerNodes.removeValue(forKey: id)
                    selectionStates.removeValue(forKey: id)
                }
                lastKey = key
            }

            for quake in earthquakes {
                guard let coord = quake.coordinate else { continue }
                let isSelected = selectedID == quake.id

                let node: SCNNode
                if let existing = markerNodes[quake.id] {
                    node = existing
                    if selectionStates[quake.id] != isSelected {
                        applyMarkerStyle(node, quake: quake, selected: isSelected)
                        selectionStates[quake.id] = isSelected
                    }
                } else {
                    node = makeMarkerNode(quake, selected: isSelected)
                    markerNodes[quake.id] = node
                    selectionStates[quake.id] = isSelected
                    markersRoot.addChildNode(node)
                }
                node.name = quake.id
                node.position = Self.surfacePosition(latitude: coord.latitude,
                                                     longitude: coord.longitude,
                                                     radius: earthRadius)
            }
        }

        // MARK: Tap → select the marker (walk up to the first named ancestor).

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView, gesture.state == .ended else { return }
            let location = gesture.location(in: view)
            for hit in view.hitTest(location, options: [:]) {
                var node = hit.node
                while node.name == nil, let parent = node.parent { node = parent }
                guard let name = node.name, let quake = lookup[name] else { continue }
                onSelect(quake)
                return
            }
        }

        // MARK: Geometry helpers

        private func makeMarkerNode(_ quake: Earthquake, selected: Bool) -> SCNNode {
            let node = SCNNode()
            applyMarkerStyle(node, quake: quake, selected: selected)

            // Larger invisible-but-hittable target so small markers are tappable.
            let hit = SCNNode(geometry: SCNSphere(radius: 0.06))
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

        private func applyMarkerStyle(_ node: SCNNode, quake: Earthquake, selected: Bool) {
            let band = quake.magnitudeBand
            let color = Self.bandColor(band)
            // Scale marker with magnitude; clamp so a M9 doesn't dwarf the globe.
            let mag = quake.magnitude ?? 0
            let baseRadius = CGFloat(0.010 + max(0, mag - 2) * 0.006)
            let radius = selected ? min(baseRadius * 1.8, 0.05) : min(baseRadius, 0.035)
            node.geometry = Self.sphere(radius: radius, color: color)
            node.geometry?.firstMaterial?.emission.contents = color
            node.geometry?.firstMaterial?.lightingModel = .constant
        }

        private static func sphere(radius: CGFloat, color: UIColor) -> SCNGeometry {
            let g = SCNSphere(radius: radius)
            g.firstMaterial?.diffuse.contents = color
            return g
        }

        /// lat/lon → point on a sphere of `radius`. Y is up (latitude); longitude
        /// rotates around Y. Chosen so that the prime meridian (lon 0) sits at +X
        /// and east (lon > 0) wraps toward +Z, matching the equirectangular texture
        /// orientation (east to the right). Slightly above the surface so markers
        /// sit proud.
        static func surfacePosition(latitude: Double, longitude: Double, radius: CGFloat) -> SCNVector3 {
            let phi = latitude * .pi / 180.0
            let theta = longitude * .pi / 180.0
            let r = Double(radius) * 1.01
            let x = r * cos(phi) * cos(theta)
            let y = r * sin(phi)
            let z = r * cos(phi) * sin(theta)
            return SCNVector3(Float(x), Float(y), Float(z))
        }

        static func bandColor(_ band: MagnitudeBand) -> UIColor {
            switch band {
            case .micro:    return UIColor(red: 0.2, green: 0.78, blue: 0.37, alpha: 1)   // green
            case .minor:    return UIColor(red: 0.98, green: 0.83, blue: 0.25, alpha: 1)   // yellow
            case .moderate: return UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1)   // amber
            case .major:    return UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)   // red
            }
        }

        // MARK: Starfield (same approach as SolarSystemSceneView)

        private static func starfield(size: Int, stars: Int) -> UIImage {
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
            }
        }
    }
}
