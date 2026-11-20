import Foundation
import RealityKit

/// Manual Release microbenchmark. Times synchronous model creation and material updates,
/// not app startup, first visible frame, or GPU latency.
@main struct PortraitBench {
    @MainActor static func main() {
        let clock = ContinuousClock()
        let finishes = [1, 3, 5].compactMap { HeadphoneFinish.reported(UInt32($0), model: .xm6) }
        precondition(finishes.count == 3)

        func ms(since start: ContinuousClock.Instant) -> Double {
            let elapsed = start.duration(to: clock.now).components
            return Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
        }
        func modelEntities(_ node: Entity) -> Int {
            (node is ModelEntity ? 1 : 0) + node.children.reduce(0) { $0 + modelEntities($1) }
        }
        func summarize(_ label: String, _ samples: [Double]) {
            let sorted = samples.sorted()
            print(String(format: "%@: median %.3f ms, p90 %.3f ms (%d samples)", label,
                         sorted[sorted.count / 2], sorted[(sorted.count * 9) / 10 - 1], sorted.count))
        }
        let start = clock.now
        guard let first = HeadphoneSculpture.make(model: .xm6, finish: finishes[0]) as Entity? else {
            preconditionFailure("Portrait mesh creation failed")
        }
        let cold = ms(since: start)
        let count = modelEntities(first)
        precondition(count > 0, "Portrait mesh creation failed")
        print(String(format: "First model incl. RealityKit initialization: %.1f ms; model entities: %d", cold, count))

        var creation = [Double]()
        for i in 1...30 {
            let finish = finishes[i % finishes.count]
            let start = clock.now
            guard let fresh = HeadphoneSculpture.make(model: .xm6, finish: finish) as Entity? else {
                preconditionFailure("Portrait mesh creation failed")
            }
            creation.append(ms(since: start))
            withExtendedLifetime(fresh) {}
        }
        summarize("Recreate a model", creation)
        #if !PORTRAIT_BASELINE
        var recolor = [Double]()
        for i in 1...30 {
            let start = clock.now
            precondition(HeadphoneSculpture.recolorXM6(first, finish: finishes[i % finishes.count]))
            recolor.append(ms(since: start))
        }
        summarize("Recolor existing model", recolor)
        #endif
    }
}
