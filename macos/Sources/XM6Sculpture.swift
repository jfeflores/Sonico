import RealityKit
import simd

// Original geometry modeled from visual reference, not a downloaded mesh.
extension HeadphoneSculpture {
    static func makeXM6(finish: HeadphoneFinish) -> Entity {
        let root = Entity()
        let shell = material(finish.shell, roughness: 0.54, specular: 0.40)
        let face = material(tint(finish.shell, toward: 0xDDDFDF, fraction: 0.10), roughness: 0.77, specular: 0.22)
        let band = material(tint(finish.shell, toward: finish.cushion, fraction: 0.34), roughness: 0.69, specular: 0.34)
        let leather = material(finish.cushion, roughness: 0.72, specular: 0.31)
        let liner = material(darken(finish.cushion, by: 0.48), roughness: 0.95, specular: 0.12)
        let seam = material(darken(finish.shell, by: 0.63), roughness: 0.68, specular: 0.27)
        let slide = material(darken(finish.shell, by: 0.91), roughness: 0.44, metallic: 0.10)
        let pin = material(darken(finish.shell, by: 0.72), roughness: 0.39, metallic: 0.28)
        let recess = material(darken(finish.cushion, by: 0.31), roughness: 0.88)
        let marker = material(0xB94237, roughness: 0.64)

        // The XM6's wider, more padded crown, with tapered collars that wrap the slide stems.
        addMesh(to: root, name: "Padded crown", length: 82, ring: 36, material: band) { u, angle in
            crownPoint(u: u, angle: angle, cap: true)
        }
        for end: Float in [0, 1] {
            addMesh(to: root, name: "Crown end cap", length: 7, ring: 36, material: shell) { u, angle in
                crownPoint(u: end == 0 ? u * 0.050 : 0.950 + u * 0.050, angle: angle,
                           cap: true, expansion: 0.001 + 0.005 * sin(.pi * u))
            }
            addMesh(to: root, name: "Crown join", length: 3, ring: 36, material: seam) { u, angle in
                crownPoint(u: (end == 0 ? 0.050 : 0.946) + u * 0.004, angle: angle,
                           cap: false, expansion: 0.0028 * sin(.pi * u))
            }
        }

        let housingProfile: [(Float, Float)] = [(-0.024, 0.975), (0.008, 0.993), (0.046, 1.003),
            (0.094, 1.006), (0.151, 0.991), (0.203, 0.951), (0.243, 0.898),
            (0.276, 0.829), (0.301, 0.753), (0.315, 0.675), (0.321, 0.616)]
        for sign: Float in [-1, 1] {
            let earcup = Entity()
            earcup.name = sign < 0 ? "Left earcup" : "Right earcup"
            earcup.position = [sign * 0.853, -0.60, 0.019]
            earcup.orientation = simd_quatf(angle: sign > 0 ? 0.01 : .pi - 0.10, axis: [0, 1, 0])
                * simd_quatf(angle: sign > 0 ? -0.080 : 0.078, axis: [0, 0, 1])
            root.addChild(earcup)
            cupSurface(on: earcup, name: "Recessed speaker fabric", profile: [(-0.163, 0), (-0.163, 0.63),
                       (-0.170, 0.744)], material: liner)
            cupSurface(on: earcup, name: "Rolled earpad", profile: [(-0.050, 0.752), (-0.132, 0.706),
                       (-0.213, 0.697), (-0.264, 0.714), (-0.300, 0.751), (-0.316, 0.804),
                       (-0.315, 0.867), (-0.293, 0.928), (-0.250, 0.968), (-0.203, 0.989),
                       (-0.130, 0.991), (-0.070, 0.981), (-0.026, 0.967)], material: leather)
            cupSurface(on: earcup, name: "Housing gasket", profile: [(-0.063, 0.971), (-0.041, 0.985),
                       (-0.020, 0.984), (-0.008, 0.979)], material: seam)
            cupSurface(on: earcup, name: "Matte tapered housing", profile: housingProfile, material: shell, outer: true)
            // A nearly flat, lightly contrasting outer face, flush with the shoulder.
            cupSurface(on: earcup, name: "Inset outer face", profile: [(0.321, 0.616), (0.3225, 0.600),
                       (0.324, 0.580), (0.325, 0.557), (0.327, 0.38), (0.328, 0)], material: face, outer: true)

            // Slots follow the housing normals instead of floating above rounded corners.
            slot(on: earcup, profile: housingProfile, station: 5, angle: 1.03, width: 0.105, material: seam)
            slot(on: earcup, profile: housingProfile, station: 5, angle: 2.04, width: 0.088, material: seam)
            slot(on: earcup, profile: housingProfile, station: 3, angle: 3.16,
                 width: sign > 0 ? 0.122 : 0.082, thickness: sign > 0 ? 0.062 : 0.070, material: recess)
            if sign < 0 {
                slot(on: earcup, profile: housingProfile, station: 2, angle: 3.65,
                     width: 0.105, thickness: 0.034, material: slide)
                slot(on: earcup, profile: housingProfile, station: 3, angle: 3.99,
                     width: 0.075, thickness: 0.026, material: seam)
            }

            let stem = Entity()
            stem.name = "Telescoping hinge"
            stem.position = [sign * 0.945, -0.094, 0.008]
            stem.orientation = simd_quatf(angle: sign * 0.106, axis: [0, 0, 1])
            root.addChild(stem)
            // Flat-topped upper sleeve, curved diagonal fold seam, then a paddle that hugs the cup.
            stemSurface(on: stem, name: "Exposed rail", lower: -0.037, upper: 0.289,
                        fold: false, size: [0.073, 0.090], material: slide)
            stemSurface(on: stem, name: "Fold seam", lower: -0.045, upper: -0.021,
                        fold: true, size: [0.081, 0.106], material: seam)
            stemSurface(on: stem, name: "Hinge pin trim", lower: -0.059, upper: -0.041,
                        fold: true, size: [0.082, 0.107], material: pin)
            stemSurface(on: stem, name: "Lower hinge arm", lower: -0.255, upper: -0.057,
                        fold: true, size: [0.084, 0.109], offsetAtBase: sign * 0.156, material: shell)
            let mount = box(on: stem, size: [0.152, 0.123, 0.192], at: [sign * 0.122, -0.229, 0],
                            radius: 0.042, material: shell)
            mount.name = "Earcup mount"
            if sign < 0 {
                let dot = ModelEntity(mesh: .generateSphere(radius: 0.028), materials: [marker])
                dot.scale = [1, 1, 0.38]
                dot.position = [0, 0.065, 0.085]
                stem.addChild(dot)
            }
        }
        return root
    }

    private static func crownPoint(u: Float, angle: Float, cap: Bool, expansion: Float = 0) -> Vec {
        let t = 0.147 + u * (.pi - 0.294)
        // A shallow shoulder broadens the sides before the semicircular crown.
        let center = Vec(0.967 * signedPower(cos(t), 0.91), -0.039 + 1.231 * sin(t), -0.018 * sin(t))
        let radial = normalize(Vec(1.231 * cos(t), 0.967 * sin(t), 0))
        let taper = pow(sin(t), 0.71)
        let width = 0.074 + 0.052 * taper + expansion
        let depth = 0.128 + 0.110 * taper + expansion
        let endCap: Float = cap && (u < 0.00001 || u > 0.99999) ? 0 : 1
        return center + endCap * (radial * width * signedPower(cos(angle), 0.79)
                                  + Vec(0, 0, depth * signedPower(sin(angle), 0.78)))
    }

    private static func cupPoint(_ x: Float, _ radius: Float, _ angle: Float, outer: Bool) -> Vec {
        let blend = outer ? min(1, max(0, (radius - 0.62) / 0.38)) : 1
        let shoulder = blend * blend * (3 - 2 * blend)
        let height = 0.494 + 0.137 * shoulder
        let y = radius * height * signedPower(cos(angle), 0.93) - (outer ? 0.051 * (1 - shoulder) : 0)
        let z = radius * 0.474 * signedPower(sin(angle), 0.94)
        return Vec(x, y, z)
    }

    private static func cupSurface(on parent: Entity, name: String, profile: [(Float, Float)],
                                   material: PhysicallyBasedMaterial, outer: Bool = false) {
        let steps = (profile.count - 1) * 4
        addMesh(to: parent, name: name, length: steps, ring: 72, material: material,
                reverse: true, poleNormal: profile[0].1 == 0 ? [-1, 0, 0] : [1, 0, 0]) { u, angle in
            let (x, radius) = interpolate(profile, at: u)
            return cupPoint(x, radius, angle, outer: outer)
        }
    }

    private static func interpolate(_ points: [(Float, Float)], at u: Float) -> (Float, Float) {
        // Local Catmull–Rom curve between authored stations, clamped to each segment
        // so poles, flush joins and the cushion roll remain where they were defined.
        let position = u * Float(points.count - 1)
        let index = min(Int(position), points.count - 2)
        let t = position - Float(index)
        let a = points[max(0, index - 1)], b = points[index]
        let c = points[index + 1], d = points[min(points.count - 1, index + 2)]
        func cubic(_ a: Float, _ b: Float, _ c: Float, _ d: Float) -> Float {
            let result = b + (t * 0.5) * (c - a + t * (2 * a - 5 * b + 4 * c - d + t * (3 * (b - c) + d - a)))
            return min(max(b, c), max(min(b, c), result))
        }
        return (cubic(a.0, b.0, c.0, d.0), cubic(a.1, b.1, c.1, d.1))
    }

    private static func slot(on parent: Entity, profile: [(Float, Float)], station: Int, angle: Float,
                             width: Float, thickness: Float = 0.022, material: PhysicallyBasedMaterial) {
        func point(_ i: Int, _ a: Float) -> Vec { cupPoint(profile[i].0, profile[i].1, a, outer: true) }
        let surface = point(station, angle)
        let tangent = normalize(point(station, angle + 0.01) - point(station, angle - 0.01))
        let alongProfile = normalize(point(station + 1, angle) - point(station - 1, angle))
        let normal = normalize(cross(tangent, alongProfile))
        let across = normalize(cross(normal, tangent))
        let node = box(on: parent, size: [width, thickness, 0.009], at: surface + normal * 0.003,
                       radius: 0.004, material: material)
        node.name = "Inset port or microphone"
        node.orientation = simd_quatf(simd_float3x3(columns: (tangent, across, normal)))
    }

    private static func stemSurface(on parent: Entity, name: String, lower: Float, upper: Float,
                                    fold: Bool, size: SIMD2<Float>, offsetAtBase: Float = 0, material: PhysicallyBasedMaterial) {
        addMesh(to: parent, name: name, length: 22, ring: 32, material: material, reverse: true) { u, angle in
            let cap: Float = u == 0 || u == 1 ? 0 : 1
            let diagonal = fold ? 0.026 * sin(angle) : 0
            let taper: Float = fold ? 0.86 + 0.14 * u : 1
            let y = lower + (upper - lower) * u + diagonal * cap
            let curve = offsetAtBase * pow(1 - u, 1.44)
            return Vec(curve + size.x * taper * cap * signedPower(cos(angle), 0.76), y,
                       -size.y * taper * cap * signedPower(sin(angle), 0.79))
        }
    }

    private static func tint(_ color: UInt32, toward target: UInt32, fraction: Float) -> UInt32 {
        func channel(_ shift: Int) -> UInt32 {
            let source = Float((color >> shift) & 255), end = Float((target >> shift) & 255)
            return UInt32((source + (end - source) * fraction).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }
}
