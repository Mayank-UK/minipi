//
//  GetAsteroidPositionsUseCase.swift
//  MiniPi
//
//  Pure Kepler mechanics (Module A §A.4). Given a set of asteroids (with orbital
//  elements) and a date, returns each body's heliocentric ecliptic (x, y, z) in AU.
//  Also exposes orbit-vertex sampling so the scene can draw each asteroid's true
//  orbital ellipse. Deterministic, no network, no SceneKit dependency.
//

import Foundation

/// Plain 3D vector in astronomical units (ecliptic coordinates).
struct Vec3 {
    let x: Double
    let y: Double
    let z: Double
}

struct AsteroidPosition {
    let asteroid: Asteroid
    let position: Vec3
}

class GetAsteroidPositionsUseCase {

    /// Solves Kepler's equation by Newton–Raphson (≈6 iterations is plenty for NEO eccentricities).
    private static func solveKepler(meanAnomaly M: Double, eccentricity e: Double,
                                    iterations: Int = 6) -> Double {
        var E = M
        for _ in 0..<iterations {
            let d = 1 - e * cos(E)
            let step = (E - e * sin(E) - M) / max(abs(d), 1e-9)
            E -= step
        }
        return E
    }

    private static func julianDay(_ date: Date) -> Double {
        2_440_587.5 + date.timeIntervalSince1970 / 86_400.0
    }

    private static func normalize(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a < -(.pi) { a += 2 * .pi }
        if a > .pi { a -= 2 * .pi }
        return a
    }

    /// Shared rotation: true anomaly (rad) + elements → heliocentric ecliptic position (AU).
    private static func ecliptic(trueAnomaly nu: Double, a: Double, e: Double,
                                 omega: Double, inc: Double, node: Double) -> Vec3 {
        let r = a * (1 - e * e) / (1 + e * cos(nu))
        let xp = r * cos(nu)
        let yp = r * sin(nu)

        let x1 = cos(omega) * xp - sin(omega) * yp
        let y1 = sin(omega) * xp + cos(omega) * yp

        let X = cos(node) * x1 - sin(node) * cos(inc) * y1
        let Y = sin(node) * x1 + cos(node) * cos(inc) * y1
        let Z = sin(inc) * y1

        return Vec3(x: X, y: Y, z: Z)
    }

    /// Parsed orbital elements in radians (or nil if the body lacks them).
    private static func parsed(_ asteroid: Asteroid) -> (a: Double, e: Double, omega: Double,
                                                        inc: Double, node: Double,
                                                        M0: Double, period: Double, epoch: Double)? {
        guard let el = asteroid.orbitalElements,
              let a = el.semiMajorAxisAU, a > 0,
              let e = el.eccentricity, e >= 0, e < 1,
              let period = el.orbitalPeriodDays, period > 0,
              let M0Deg = el.meanAnomalyDeg,
              let omegaDeg = el.perihelionArgumentDeg,
              let incDeg = el.inclinationDeg,
              let nodeDeg = el.ascendingNodeLongitudeDeg
        else { return nil }

        let deg = Double.pi / 180
        return (a, e, omegaDeg * deg, incDeg * deg, nodeDeg * deg,
                M0Deg * deg, period, el.epochOsculation ?? julianDay(Date()))
    }

    /// Heliocentric ecliptic position (AU) for a single body at `date`, or nil if it lacks elements.
    static func position(of asteroid: Asteroid, at date: Date) -> Vec3? {
        guard let p = parsed(asteroid) else { return nil }
        let dt = julianDay(date) - p.epoch
        let n = 2 * .pi / p.period
        let M = normalize(p.M0 + n * dt)
        let E = solveKepler(meanAnomaly: M, eccentricity: p.e)
        let nu = 2 * atan2(sqrt(1 + p.e) * sin(E / 2), sqrt(1 - p.e) * cos(E / 2))
        return ecliptic(trueAnomaly: nu, a: p.a, e: p.e, omega: p.omega, inc: p.inc, node: p.node)
    }

    /// Samples the body's full orbital ellipse (AU), for drawing its path. Nil if no elements.
    static func orbitVertices(of asteroid: Asteroid, steps: Int = 128) -> [Vec3]? {
        guard let p = parsed(asteroid) else { return nil }
        return (0...steps).map { i in
            let nu = 2 * .pi * Double(i) / Double(steps)
            return ecliptic(trueAnomaly: nu, a: p.a, e: p.e, omega: p.omega, inc: p.inc, node: p.node)
        }
    }

    func execute(_ asteroids: [Asteroid], at date: Date) -> [AsteroidPosition] {
        asteroids.compactMap { asteroid in
            Self.position(of: asteroid, at: date).map { AsteroidPosition(asteroid: asteroid, position: $0) }
        }
    }
}
