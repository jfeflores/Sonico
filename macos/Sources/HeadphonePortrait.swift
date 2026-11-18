import AppKit
import RealityKit
import SwiftUI
import simd

/// Live, original 3D geometry. No Sony imagery, downloaded model, or animation runtime.
struct HeadphonePortrait: View {
    let model: HeadphoneModelID
    let finish: HeadphoneFinish?
    let animateArrival: Bool
    let onRevealStart: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasFrame = false
    @State private var ready = false
    @State private var orbit = PortraitOrbit()
    @GestureState private var drag = CGSize.zero

    var body: some View {
        VStack(spacing: 2) {
            viewport
            HStack(spacing: 10) {
                Text("Drag to rotate").font(.caption).padding(.trailing, 4)
                rotationButton("Rotate left", icon: "arrow.counterclockwise") { orbit = orbit.stepped(-1) }
                rotationButton("Rotate right", icon: "arrow.clockwise") { orbit = orbit.stepped(1) }
                rotationButton("Reset view", icon: "arrow.uturn.backward") { orbit = PortraitOrbit() }
            }
            .frame(height: 26)
            .opacity(ready ? 1 : 0)
            .disabled(!ready)
            .accessibilityHidden(!ready)
            .animation(reduceMotion ? nil : XMMotion.reveal, value: ready)
        }
    }

    private func rotationButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).labelStyle(.iconOnly).frame(width: 22, height: 22) }
            .buttonStyle(.borderless).help(title)
    }

    private var viewport: some View {
        ZStack {
            if !hasFrame {
                Image(systemName: "headphones").font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(XMTheme.onHeader.opacity(0.62))
            }
            PortraitRenderer(model: model, finish: finish, orbit: orbit.dragged(by: drag),
                             animateArrival: animateArrival, reduceMotion: reduceMotion) {
                hasFrame = true
                if animateArrival { onRevealStart() }
            } onReady: {
                ready = true
            }
        }
        .allowsHitTesting(false)
        .overlay {
            if ready {
                Color.clear.contentShape(Rectangle())
                    .pointerStyle(drag == .zero ? .grabIdle : .grabActive)
                    .gesture(DragGesture(minimumDistance: 2)
                        .updating($drag) { value, translation, _ in translation = value.translation }
                        .onEnded { value in orbit = orbit.dragged(by: value.translation) })
            }
        }
        .accessibilityHidden(true) // Rotation and reset are separate native buttons.
        .frame(height: 206)
    }
}

@MainActor
enum HeadphoneSculpture {
    typealias Vec = SIMD3<Float>

    private struct Profile {
        let width: Float
        let rise: Float
        let bandDepth: Float
        let crown: Float
        let cupHeight: Float
        let cupDepth: Float
        let cupRoundness: Float
        let cupCenter: Float
        let cupThickness: Float
        let yoke: Bool
        let fold: Bool

        init(_ model: HeadphoneModelID) {
            switch model {
            case .xm5, .xm6: // XM6 uses its own sculpt below.
                (width, rise, bandDepth, crown, cupHeight, cupDepth, cupRoundness, cupCenter, cupThickness, yoke, fold) =
                    (0.93, 1.34, 0.17, 0.075, 0.55, 0.39, 2.1, -0.61, 0.28, false, false)
            case .xm4:
                (width, rise, bandDepth, crown, cupHeight, cupDepth, cupRoundness, cupCenter, cupThickness, yoke, fold) =
                    (0.93, 1.27, 0.25, 0.09, 0.52, 0.37, 2.6, -0.59, 0.27, true, true)
            case .xm3:
                (width, rise, bandDepth, crown, cupHeight, cupDepth, cupRoundness, cupCenter, cupThickness, yoke, fold) =
                    (0.94, 1.26, 0.24, 0.085, 0.53, 0.38, 2.3, -0.60, 0.25, true, true)
            }
        }
    }

    static func make(model: HeadphoneModelID, finish: HeadphoneFinish) -> Entity {
        if model == .xm6 { return makeXM6(finish: finish) }
        let p = Profile(model)
        let root = Entity()
        let shell = material(finish.shell, roughness: 0.43)
        let soft = material(finish.cushion, roughness: 0.80)
        let liner = material(darken(finish.cushion, by: 0.75), roughness: 0.93)
        let seam = material(darken(finish.shell, by: 0.78), roughness: 0.54)
        let slide = material(darken(finish.shell, by: 0.86), roughness: 0.34, metallic: 0.12)
        let dark = material(darken(finish.cushion, by: 0.39), roughness: 0.72)

        // A padded, swept arch tapers into the two telescoping stems.
        addMesh(to: root, name: "Headband", length: 64, ring: 24, material: shell) { u, a in
            let t = 0.16 + u * (.pi - 0.32)
            let center = Vec(p.width * cos(t), -0.11 + p.rise * sin(t), 0.02 * sin(t))
            let radial = normalize(Vec(p.rise * cos(t), p.width * sin(t), 0))
            let taper = 0.60 + 0.40 * sin(t)
            return center + radial * p.crown * taper * signedPower(cos(a), 0.75)
                + Vec(0, 0, p.bandDepth * taper * signedPower(sin(a), 0.72))
        }
        addMesh(to: root, name: "Inner headband pad", length: 48, ring: 20, material: soft) { u, a in
            let t = 0.49 + u * (.pi - 0.98)
            let radial = normalize(Vec(p.rise * cos(t), p.width * sin(t), 0))
            let center = Vec(p.width * cos(t), -0.11 + p.rise * sin(t), 0.018)
            let taper = 0.55 + 0.45 * sin(.pi * u)
            return center + radial * (-p.crown * 0.79 + 0.039 * taper * cos(a))
                + Vec(0, 0, p.bandDepth * 0.87 * taper * signedPower(sin(a), 0.8))
        }

        for sign: Float in [-1, 1] {
            let housing = Entity()
            housing.position = [sign * (p.width - 0.002), p.cupCenter, 0.012]
            housing.orientation = simd_quatf(angle: sign > 0 ? 0.06 : .pi - 0.06, axis: [0, 1, 0])
            root.addChild(housing)
            // Stepped x/radius pairs define the fabric, rolled cushion, perimeter seam,
            // and sculpted shell. The varying slopes catch real light as the head turns.
            ringSurface(on: housing, name: "Driver cloth", profile: [(-0.18, 0), (-0.18, 0.70), (-0.16, 0.79)],
                        cup: p, material: liner)
            ringSurface(on: housing, name: "Rolled cushion", profile: [(-0.085, 0.75), (-0.18, 0.70), (-0.24, 0.72),
                        (-0.27, 0.79), (-0.27, 0.90), (-0.25, 0.97), (-0.19, 1.01), (-0.09, 1.01),
                        (-0.045, 0.986), (-0.02, 0.95)], cup: p, material: soft)
            ringSurface(on: housing, name: "Perimeter seam", profile: [(-0.032, 0.946), (-0.008, 0.971), (0.02, 0.978)],
                        cup: p, material: seam)
            let thick = p.cupThickness
            ringSurface(on: housing, name: "Molded outer shell", profile: [(0.0, 0.966), (0.034, 1.0),
                        (thick * 0.36, 1.018), (thick * 0.65, 0.98), (thick * 0.85, 0.88),
                        (thick * 0.97, 0.70), (thick, 0.5), (thick * 1.01, 0.27), (thick * 1.013, 0)],
                        cup: p, material: shell)

            let earAttachment = sign * (p.width + (p.yoke ? 0.09 : 0.19))
            let top = Vec(sign * (p.width - 0.012), 0.20, 0.014)
            let bottom = Vec(earAttachment, p.cupCenter + p.cupHeight * 0.72, 0.02)
            let joint = mix(top, bottom, t: Vec(repeating: 0.50))
            roundedLink(on: root, from: top, to: joint, width: p.yoke ? 0.13 : 0.11, depth: 0.17, material: slide)
            roundedLink(on: root, from: joint, to: bottom, width: p.yoke ? 0.13 : 0.15, depth: 0.19, material: shell)
            if p.fold {
                box(on: root, size: [0.16, 0.105, 0.18], at: joint, radius: 0.047, material: seam)
            }
            if p.yoke {
                for z: Float in [-1, 1] {
                    let hinge = Vec(sign * (p.width + 0.14), p.cupCenter + 0.12, z * p.cupDepth * 0.87)
                    roundedLink(on: root, from: bottom + [0, 0, z * 0.055], to: hinge,
                                width: 0.105, depth: 0.105, material: shell)
                }
            }
            if sign < 0 {
                box(on: housing, size: [0.069, 0.041, 0.121], at: [0.102, -p.cupHeight * 0.913, 0.032], radius: 0.017, material: dark)
                box(on: housing, size: [0.056, 0.038, 0.075], at: [0.092, -p.cupHeight * 0.895, -0.17], radius: 0.015, material: seam)
            } else {
                box(on: housing, size: [0.070, 0.038, 0.115], at: [0.09, -p.cupHeight * 0.925, -0.02], radius: 0.015, material: dark)
            }
        }
        return root
    }

    static func material(_ rgb: UInt32, roughness: Float, metallic: Float = 0, specular: Float = 0.5) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                                                green: CGFloat((rgb >> 8) & 255) / 255,
                                                blue: CGFloat(rgb & 255) / 255, alpha: 1))
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: metallic)
        material.specular = .init(floatLiteral: specular)
        return material
    }

    static func darken(_ rgb: UInt32, by factor: Float) -> UInt32 {
        (UInt32(Float((rgb >> 16) & 255) * factor) << 16) | (UInt32(Float((rgb >> 8) & 255) * factor) << 8)
            | UInt32(Float(rgb & 255) * factor)
    }

    private static func ringSurface(on parent: Entity, name: String, profile: [(Float, Float)],
                                    cup: Profile, material: PhysicallyBasedMaterial) {
        addMesh(to: parent, name: name, length: profile.count - 1, ring: 64, material: material,
                reverse: true, poleNormal: profile[0].1 == 0 ? [-1, 0, 0] : [1, 0, 0]) { u, a in
            let ring = profile[Int((u * Float(profile.count - 1)).rounded())]
            return Vec(ring.0, cup.cupHeight * ring.1 * signedPower(cos(a), 2 / cup.cupRoundness),
                       cup.cupDepth * ring.1 * signedPower(sin(a), 2 / cup.cupRoundness))
        }
    }

    static func signedPower(_ value: Float, _ power: Float) -> Float {
        (value < 0 ? -1 : 1) * pow(abs(value), power)
    }

    private static func roundedLink(on parent: Entity, from: Vec, to: Vec, width: Float,
                                    depth: Float, material: PhysicallyBasedMaterial) {
        let delta = to - from
        let node = box(on: parent, size: [width, length(delta) + 0.035, depth], at: (from + to) / 2,
                       radius: width * 0.42, material: material)
        node.orientation = simd_quatf(from: [0, -1, 0], to: normalize(delta))
    }

    @discardableResult
    static func box(on parent: Entity, size: Vec, at point: Vec, radius: Float,
                            material: PhysicallyBasedMaterial) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: size, cornerRadius: radius)
        let node = ModelEntity(mesh: mesh, materials: [material])
        node.position = point
        parent.addChild(node)
        return node
    }

    static func addMesh(to parent: Entity, name: String, length: Int, ring: Int,
                                material: PhysicallyBasedMaterial, reverse: Bool = false, poleNormal: Vec = [0, 1, 0],
                                point: (Float, Float) -> Vec) {
        var positions: [Vec] = []
        var normals: [Vec] = []
        var indices: [UInt32] = []
        let stride = ring + 1
        for row in 0...length {
            for col in 0...ring {
                positions.append(point(Float(row) / Float(length), Float(col % ring) / Float(ring) * 2 * .pi))
            }
        }
        for row in 0...length {
            for col in 0...ring {
                let a = positions[min(row + 1, length) * stride + col] - positions[max(row - 1, 0) * stride + col]
                let b = positions[row * stride + ((col + 1) % ring)] - positions[row * stride + ((col + ring - 1) % ring)]
                let n = cross(a, b) * (reverse ? -1 : 1)
                normals.append(simd_length_squared(n) > 1e-12 ? normalize(n) : poleNormal)
                if row < length && col < ring {
                    let i = UInt32(row * stride + col), j = i + UInt32(stride)
                    indices += reverse ? [i, i + 1, j, j, i + 1, j + 1] : [i, j, i + 1, j, j + 1, i + 1]
                }
            }
        }
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = .init(positions)
        descriptor.normals = .init(normals)
        descriptor.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return }
        let surface = ModelEntity(mesh: mesh, materials: [material])
        surface.name = name
        parent.addChild(surface)
    }
}
