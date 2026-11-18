import AppKit
import MetalKit
import QuartzCore
import RealityKit
import SwiftUI

/// RealityKit owns the original scene and materials. MetalKit only schedules frames
/// during the arrival or when the viewport or orbit changes.
struct PortraitRenderer: NSViewRepresentable {
    let model: HeadphoneModelID
    let finish: HeadphoneFinish?
    let orbit: PortraitOrbit
    let animateArrival: Bool
    let reduceMotion: Bool
    let onFirstFrame: () -> Void
    let onReady: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.preferredFramesPerSecond = 60
        (view.layer as? CAMetalLayer)?.isOpaque = false
        context.coordinator.configure(view: view, model: model, finish: finish, orbit: orbit,
                                      animate: animateArrival && !reduceMotion,
                                      onFirstFrame: onFirstFrame, onReady: onReady)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.update(orbit: orbit, reduceMotion: reduceMotion, view: view)
    }

    static func dismantleNSView(_ view: MTKView, coordinator: Coordinator) {
        coordinator.stop(view: view)
    }

    @MainActor final class Coordinator: NSObject, MTKViewDelegate {
        private static let duration = 0.58
        private var renderer: RealityRenderer?
        private var headset: Entity?
        private var orbit = PortraitOrbit()
        private var yaw: Float = 0
        private var pitch: Float = 0
        private var roll: Float = 0
        private var revealStartedAt: CFTimeInterval?
        private var revealing = false
        private var pendingDrawable: CAMetalDrawable?
        private var needsFrame = false
        private var onFirstFrame: (() -> Void)?
        private var onReady: (() -> Void)?

        func configure(view: MTKView, model: HeadphoneModelID, finish: HeadphoneFinish?, orbit: PortraitOrbit,
                       animate: Bool, onFirstFrame: @escaping () -> Void, onReady: @escaping () -> Void) {
            guard view.device != nil, let renderer = try? RealityRenderer() else { return }
            self.renderer = renderer
            self.onFirstFrame = onFirstFrame
            self.onReady = onReady
            self.orbit = orbit
            revealing = animate
            yaw = model == .xm6 ? -1.16 : -0.95
            pitch = model == .xm6 ? -0.08 : -0.13
            roll = model == .xm6 ? 0.28 : -0.17
            renderer.cameraSettings.colorBackground = .color(CGColor(gray: 0, alpha: 0))
            renderer.cameraSettings.isToneMappingEnabled = true
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 31
            camera.camera.near = 0.1
            camera.camera.far = 20
            camera.position = [0, 0.02, model == .xm6 ? 5.58 : 5.3]
            renderer.entities.append(camera)
            renderer.activeCamera = camera
            renderer.entities.append(light(at: [-3, 5, 4], intensity: model == .xm6 ? 2100 : 2300))
            renderer.entities.append(light(at: [4, 1, 3], intensity: 820))
            renderer.entities.append(light(at: [1, 3, -4], intensity: model == .xm6 ? 960 : 1350))
            let headset = HeadphoneSculpture.make(model: model, finish: finish ?? .unreported)
            self.headset = headset
            renderer.entities.append(headset)
            view.delegate = self
            view.enableSetNeedsDisplay = !revealing
            view.isPaused = !revealing
            view.needsDisplay = true
        }

        func update(orbit: PortraitOrbit, reduceMotion: Bool, view: MTKView) {
            if reduceMotion && revealing {
                revealing = false
                pause(view)
                requestFrame(view)
            }
            if self.orbit != orbit {
                self.orbit = orbit
                requestFrame(view)
            }
        }

        func stop(view: MTKView) {
            pause(view)
            view.delegate = nil
            renderer = nil
            headset = nil
            pendingDrawable = nil
            onFirstFrame = nil
            onReady = nil
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { requestFrame(view) }

        func draw(in view: MTKView) {
            guard pendingDrawable == nil, let renderer, let headset else { return }
            guard let drawable = view.currentDrawable else { return }
            let time = CACurrentMediaTime()
            if revealing && revealStartedAt == nil { revealStartedAt = time }
            let t = revealing ? min((time - (revealStartedAt ?? time)) / Self.duration, 1) : 1
            if t >= 1 && revealing {
                revealing = false
                pause(view)
            }
            let remaining = Float(pow(1 - t, 3))
            let scale = 1 - 0.06 * remaining
            headset.transform = Transform(
                scale: SIMD3(repeating: scale),
                rotation: simd_quatf(angle: pitch + Float(orbit.pitch) - 0.07 * remaining, axis: [1, 0, 0])
                    * simd_quatf(angle: roll * (1 - 0.4 * remaining), axis: [0, 0, 1])
                    * simd_quatf(angle: yaw + Float(orbit.yaw) + 0.47 * remaining, axis: [0, 1, 0]),
                translation: [0, -0.09 * remaining, 0])
            needsFrame = false
            pendingDrawable = drawable
            do {
                let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: drawable.texture))
                try renderer.updateAndRender(deltaTime: 0, cameraOutput: output, onComplete: { [weak self, weak view] _ in
                    DispatchQueue.main.async {
                        guard let self, let view, let drawable = self.pendingDrawable else { return }
                        self.pendingDrawable = nil
                        drawable.present()
                        let firstFrame = self.onFirstFrame
                        self.onFirstFrame = nil
                        firstFrame?()
                        if t >= 1 && !self.revealing {
                            let ready = self.onReady
                            self.onReady = nil
                            ready?()
                        }
                        if self.needsFrame && !self.revealing { view.needsDisplay = true }
                    }
                })
            } catch {
                stop(view: view)
            }
        }

        private func requestFrame(_ view: MTKView) {
            needsFrame = true
            if !revealing && pendingDrawable == nil { view.needsDisplay = true }
        }

        private func pause(_ view: MTKView) {
            view.isPaused = true
            view.enableSetNeedsDisplay = true
        }

        private func light(at position: SIMD3<Float>, intensity: Float) -> DirectionalLight {
            let light = DirectionalLight()
            light.light.intensity = intensity
            light.look(at: .zero, from: position, relativeTo: nil)
            return light
        }
    }
}
