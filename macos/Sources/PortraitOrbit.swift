import Foundation

/// Angles in radians. Horizontal input can make a full turn; pitch stays within a
/// useful product-view range so a fast drag cannot flip the headset upside down.
struct PortraitOrbit: Equatable {
    static let sensitivity = 0.011 // radians per window point
    static let pitchRange = -0.52...0.52
    var yaw: Double = 0
    var pitch: Double = 0

    func dragged(by displacement: CGSize) -> Self {
        Self(yaw: (yaw + Double(displacement.width) * Self.sensitivity)
            .remainder(dividingBy: 2 * .pi),
             pitch: min(Self.pitchRange.upperBound, max(Self.pitchRange.lowerBound,
                        pitch + Double(displacement.height) * Self.sensitivity)))
    }

    func stepped(_ direction: Double) -> Self {
        Self(yaw: (yaw + direction * .pi / 6).remainder(dividingBy: 2 * .pi), pitch: pitch)
    }
}
