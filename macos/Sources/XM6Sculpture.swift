import RealityKit
import simd

// Original geometry based on visual reference. The fixed geometry is built once;
// previewing another finish swaps materials, not vertex buffers.
extension HeadphoneSculpture {
    private enum XM6Part: Int, CaseIterable {
        case shell, touch, band, cushion, lining, seam, rail, pin, port, marker

        @MainActor func material(for finish: HeadphoneFinish) -> PhysicallyBasedMaterial {
            let make = HeadphoneSculpture.material
            switch self {
            case .shell: return make(finish.shell, 0.49, 0, 0.35)
            case .touch: return make(tint(finish.shell, toward: 0xF1F1ED, fraction: 0.11), 0.71, 0, 0.22)
            case .band: return make(tint(finish.shell, toward: finish.cushion, fraction: 0.40), 0.63, 0, 0.30)
            case .cushion: return make(finish.cushion, 0.62, 0, 0.34)
            case .lining: return make(darken(finish.cushion, by: 0.65), 0.92, 0, 0.17)
            case .seam: return make(darken(finish.shell, by: 0.67), 0.72, 0, 0.26)
            case .rail: return make(darken(finish.shell, by: 0.93), 0.43, 0.11, 0.42)
            case .pin: return make(tint(finish.shell, toward: 0xAEA69C, fraction: 0.22), 0.43, 0.26, 0.38)
            case .port: return make(darken(finish.cushion, by: 0.28), 0.88, 0, 0.28)
            case .marker: return make(0xB94237, 0.64, 0, 0.45)
            }
        }
    }

    private static let xm6Geometry: MeshResource? = try? buildXM6Geometry()

    static func makeXM6(finish: HeadphoneFinish) -> Entity? {
        guard let mesh = xm6Geometry else { return nil }
        let entity = ModelEntity(mesh: mesh, materials: xm6Materials(finish))
        entity.name = "WH-1000XM6"
        return entity
    }

    static func recolorXM6(_ entity: Entity, finish: HeadphoneFinish) -> Bool {
        guard let model = entity as? ModelEntity else { return false }
        model.model?.materials = xm6Materials(finish)
        return true
    }

    private static func xm6Materials(_ finish: HeadphoneFinish) -> [any Material] {
        XM6Part.allCases.map { $0.material(for: finish) }
    }

    private struct Surface {
        var positions: [Vec] = []
        var normals: [Vec] = []
        var indices: [UInt32] = []
    }

    private struct XM6Mesh {
        private var surfaces = Array(repeating: Surface(), count: XM6Part.allCases.count)

        /// Smooth across the periodic seam, share ring vertices, and omit zero-area cap faces.
        mutating func add(_ part: XM6Part, rows: Int, ring: Int, reverse: Bool = false,
                          point: (Float, Float) -> Vec) {
            var points = [Vec]()
            points.reserveCapacity((rows + 1) * ring)
            for row in 0...rows {
                for col in 0..<ring {
                    points.append(point(Float(row) / Float(rows), Float(col) / Float(ring) * 2 * .pi))
                }
            }
            func facing(_ v: Vec) -> Vec { reverse ? -v : v }
            let base = UInt32(surfaces[part.rawValue].positions.count)
            var piece = Surface()
            piece.positions = points
            piece.normals.reserveCapacity(points.count)
            piece.indices.reserveCapacity(rows * ring * 6)
            for row in 0...rows {
                for col in 0..<ring {
                    let prev = (col + ring - 1) % ring, next = (col + 1) % ring
                    let offset = row * ring
                    let a = points[min(row + 1, rows) * ring + col] - points[max(row - 1, 0) * ring + col]
                    let b = points[offset + next] - points[offset + prev]
                    var n = facing(cross(a, b))
                    if simd_length_squared(n) < 1e-12 {
                        let adjacent = (row == 0 ? 1 : row - 1) * ring
                        n = facing(cross(a, points[adjacent + next] - points[adjacent + prev]))
                    }
                    piece.normals.append(simd_length_squared(n) > 1e-12 ? normalize(n) : [0, 1, 0])
                    guard row < rows else { continue }
                    let i = offset + col, j = offset + next
                    let k = i + ring, l = j + ring
                    func triangle(_ a: Int, _ b: Int, _ c: Int) {
                        guard simd_length_squared(cross(points[b] - points[a], points[c] - points[a])) > 1e-16 else { return }
                        piece.indices.append(base + UInt32(a))
                        piece.indices.append(base + UInt32(reverse ? c : b))
                        piece.indices.append(base + UInt32(reverse ? b : c))
                    }
                    triangle(i, k, j)
                    triangle(k, l, j)
                }
            }
            surfaces[part.rawValue].positions.append(contentsOf: piece.positions)
            surfaces[part.rawValue].normals.append(contentsOf: piece.normals)
            surfaces[part.rawValue].indices.append(contentsOf: piece.indices)
        }

        @MainActor func resource() throws -> MeshResource {
            let descriptors = XM6Part.allCases.map { part in
                let surface = surfaces[part.rawValue]
                var mesh = MeshDescriptor(name: String(describing: part))
                mesh.positions = .init(surface.positions)
                mesh.normals = .init(surface.normals)
                mesh.primitives = .triangles(surface.indices)
                mesh.materials = .allFaces(UInt32(part.rawValue))
                return mesh
            }
            return try MeshResource.generate(from: descriptors)
        }
    }

    private static func buildXM6Geometry() throws -> MeshResource {
        var mesh = XM6Mesh()
        mesh.add(.band, rows: 56, ring: 28) { u, a in crownPoint(u: u, angle: a, cap: true) }
        for end: Float in [0, 1] {
            mesh.add(.shell, rows: 6, ring: 28) { u, a in
                crownPoint(u: end == 0 ? u * 0.046 : 0.954 + u * 0.046, angle: a,
                           cap: true, expansion: 0.001 + 0.005 * sin(.pi * u))
            }
            mesh.add(.seam, rows: 2, ring: 28) { u, a in
                crownPoint(u: (end == 0 ? 0.046 : 0.950) + u * 0.004, angle: a, cap: false, expansion: 0.0031)
            }
        }

        // One continuous profile with a material change at the smaller, lowered touch surface.
        let housing: [(Float, Float)] = [(-0.025, 0.973), (0.008, 0.993), (0.052, 1.005), (0.100, 1.004),
            (0.157, 0.987), (0.214, 0.950), (0.258, 0.902), (0.292, 0.839), (0.316, 0.768),
            (0.332, 0.683), (0.342, 0.599), (0.349, 0.509), (0.353, 0.392), (0.356, 0.24), (0.357, 0)]
        for sign: Float in [-1, 1] {
            let cupRotation = simd_quatf(angle: sign > 0 ? 0.015 : .pi - 0.10, axis: [0, 1, 0])
                * simd_quatf(angle: sign > 0 ? -0.080 : 0.078, axis: [0, 0, 1])
            func cup(_ point: Vec) -> Vec { [sign * 0.855, -0.60, 0.019] + cupRotation.act(point) }
            func profilePoint(_ profile: [(Float, Float)], u: Float, a: Float, outer: Bool) -> Vec {
                let (x, radius) = interpolate(profile, at: u)
                return cupPoint(x, radius, a, outer: outer)
            }

            let fabric: [(Float, Float)] = [(-0.145, 0), (-0.148, 0.32), (-0.165, 0.56), (-0.180, 0.745)]
            mesh.add(.lining, rows: 10, ring: 56, reverse: true) { u, a in cup(profilePoint(fabric, u: u, a: a, outer: false)) }
            let pads: [(Float, Float)] = [(-0.052, 0.752), (-0.132, 0.710), (-0.211, 0.696),
                (-0.262, 0.711), (-0.305, 0.752), (-0.328, 0.810), (-0.322, 0.880), (-0.294, 0.936),
                (-0.247, 0.972), (-0.196, 0.988), (-0.130, 0.990), (-0.071, 0.984), (-0.023, 0.966)]
            mesh.add(.cushion, rows: 30, ring: 64, reverse: true) { u, a in
                let point = profilePoint(pads, u: u, a: a, outer: false)
                // Subtle shaping along the padded crest, instead of texture noise or dark stripes.
                let compression = 1 + sin(4 * a + 0.4) * 0.004 * sin(.pi * u)
                return cup([point.x, point.y * compression, point.z * compression])
            }
            let gasket: [(Float, Float)] = [(-0.080, 0.973), (-0.048, 0.982), (-0.020, 0.983), (0.005, 0.981)]
            mesh.add(.seam, rows: 6, ring: 56, reverse: true) { u, a in cup(profilePoint(gasket, u: u, a: a, outer: false)) }
            mesh.add(.shell, rows: 26, ring: 64, reverse: true) { u, a in
                cup(profilePoint(housing, u: u * 10 / 14, a: a, outer: true))
            }
            mesh.add(.touch, rows: 10, ring: 64, reverse: true) { u, a in
                cup(profilePoint(housing, u: (10 + 4 * u) / 14, a: a, outer: true))
            }

            // Wrap visible microphone slots around the earcups; the underside controls differ by side.
            addSlot(to: &mesh, .port, profile: housing, station: 6, angle: 0.71, width: 0.102, height: 0.022, cup: cup)
            addSlot(to: &mesh, .port, profile: housing, station: 6, angle: 2.22, width: 0.078, height: 0.020, cup: cup)
            addSlot(to: &mesh, .port, profile: housing, station: 5, angle: 4.88, width: 0.068, height: 0.018, cup: cup)
            if sign > 0 {
                addSlot(to: &mesh, .port, profile: housing, station: 2, angle: 3.28, width: 0.132, height: 0.041, cup: cup)
                addSlot(to: &mesh, .pin, profile: housing, station: 2, angle: 3.48, width: 0.026, height: 0.019, cup: cup)
            } else {
                addSlot(to: &mesh, .port, profile: housing, station: 2, angle: 3.22, width: 0.072, height: 0.069, cup: cup)
                addSlot(to: &mesh, .rail, profile: housing, station: 2, angle: 3.60, width: 0.113, height: 0.034, cup: cup)
                addSlot(to: &mesh, .rail, profile: housing, station: 2, angle: 3.91, width: 0.085, height: 0.031, cup: cup)
            }

            let hingeRotation = simd_quatf(angle: sign * 0.106, axis: [0, 0, 1])
            func hinge(_ point: Vec) -> Vec { [sign * 0.945, -0.094, 0.008] + hingeRotation.act(point) }
            addStem(to: &mesh, .rail, lower: -0.035, upper: 0.29, size: [0.073, 0.090], curve: 0.177 * sign, hinge: hinge)
            addStem(to: &mesh, .seam, lower: -0.058, upper: -0.021, size: [0.084, 0.101], diagonal: 0.021,
                    offset: 0.165 * sign, curve: 0.018 * sign, hinge: hinge)
            addStem(to: &mesh, .pin, lower: -0.071, upper: -0.044, size: [0.085, 0.102], diagonal: 0.021,
                    offset: 0.181 * sign, curve: 0.018 * sign, hinge: hinge)
            addStem(to: &mesh, .shell, lower: -0.289, upper: -0.052, size: [0.088, 0.112], diagonal: 0.021,
                    offset: 0.198 * sign, curve: 0.068 * sign, hinge: hinge)
            if sign < 0 {
                mesh.add(.marker, rows: 14, ring: 16, reverse: true) { u, a in
                    let radius = sin(.pi * u)
                    return hinge([0.027 * radius * cos(a), 0.087 + 0.027 * radius * sin(a), 0.086 - 0.008 * cos(.pi * u)])
                }
            }
        }
        return try mesh.resource()
    }

    private static func crownPoint(u: Float, angle: Float, cap: Bool, expansion: Float = 0) -> Vec {
        let t = 0.147 + u * (.pi - 0.294)
        let center = Vec(0.967 * signedPower(cos(t), 0.90), -0.039 + 1.231 * sin(t), -0.034 * sin(t))
        let radial = normalize(Vec(1.231 * cos(t), 0.967 * sin(t), 0))
        let taper = pow(sin(t), 0.71)
        let width = 0.075 + 0.047 * taper + expansion
        let depth = 0.131 + 0.092 * taper + expansion
        let endCap: Float = cap && (u < 0.00001 || u > 0.99999) ? 0 : 1
        return center + endCap * (radial * width * signedPower(cos(angle), 0.82)
                                  + Vec(0, 0, depth * signedPower(sin(angle), 0.86)))
    }

    private static func cupPoint(_ x: Float, _ radius: Float, _ angle: Float, outer: Bool) -> Vec {
        let blend = outer ? min(1, max(0, (radius - 0.57) / 0.43)) : 1
        let shoulder = blend * blend * (3 - 2 * blend)
        let height = 0.519 + 0.103 * shoulder
        let y = radius * height * signedPower(cos(angle), 0.92) - (outer ? 0.100 * (1 - shoulder) : 0)
        let z = radius * 0.475 * signedPower(sin(angle), 0.95)
        return Vec(x, y, z)
    }

    private static func interpolate(_ points: [(Float, Float)], at u: Float) -> (Float, Float) {
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

    private static func addSlot(to mesh: inout XM6Mesh, _ part: XM6Part, profile: [(Float, Float)], station: Int, angle: Float,
                                width: Float, height: Float, cup: (Vec) -> Vec) {
        func point(_ i: Int, _ a: Float) -> Vec { cupPoint(profile[i].0, profile[i].1, a, outer: true) }
        let surface = point(station, angle)
        let tangent = normalize(point(station, angle + 0.01) - point(station, angle - 0.01))
        let along = normalize(point(station + 1, angle) - point(station - 1, angle))
        let normal = normalize(cross(tangent, along)), across = normalize(cross(normal, tangent))
        mesh.add(part, rows: 4, ring: 20, reverse: true) { u, a in
            let v: Float = u <= 0.001 || u >= 0.999 ? 0 : 1
            let depth: Float = part == .rail ? 0.012 : 0.006
            let alongTangent = signedPower(cos(a), 0.62) * width * (0.46 + 0.06 * sin(.pi * u))
            let alongCross = signedPower(sin(a), 0.60) * height * 0.5
            let footprint = tangent * alongTangent + across * alongCross
            let height = normal * (depth * (u - 0.31))
            return cup(surface + footprint * v + height)
        }
    }

    private static func addStem(to mesh: inout XM6Mesh, _ part: XM6Part, lower: Float, upper: Float,
                                size: SIMD2<Float>, diagonal: Float = 0, offset: Float = 0, curve: Float = 0,
                                hinge: (Vec) -> Vec) {
        mesh.add(part, rows: part == .shell ? 14 : 8, ring: 24, reverse: true) { u, a in
            let cap = min(1, 8 * min(u, 1 - u))
            let y = lower + (upper - lower) * u + diagonal * sin(a) * cap
            let centerX = offset + curve * pow(1 - u, 1.22)
            return hinge(Vec(centerX + size.x * cap * signedPower(cos(a), 0.65), y,
                             -size.y * cap * signedPower(sin(a), 0.73)))
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
