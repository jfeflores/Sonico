# Project XMConnect: native validation

This records the current native build and complements the earlier [architecture review](MACOS-REVIEW.md). It is not a device certification or a full security audit.

## Verified locally

- A fresh `bash macos/build.sh` build passed all seven CTest suites, including 48 Swift model assertions. SourceKit reported no diagnostics across the native sources and tests. The app passed strict ad-hoc signature verification, and its executable does not link a Homebrew dylib. The bundle includes the upstream MIT and fmt notices.
- In explicit demo mode, the device overview, noise-mode selection and ambient slider, ten-band EQ editor and flat reset, grouped settings, and the disconnected state were exercised. The accessibility tree exposed the rotation buttons, band frequencies, and selected listening mode. No Bluetooth discovery, connections, or device writes were initiated.
- In the demo, drag changed the rendered portrait and **Reset View** restored a pixel-identical crop. Rotation becomes available after the final frame of the 580 ms entrance. Source review confirmed that Reduce Motion bypasses the entrance and that leaving the page or closing the window detaches the renderer. System-wide Reduce Motion and VoiceOver were not exercised end to end.
- The previous `RealityView` path showed 42.5% process CPU in one resting demo sample. The on-demand RealityKit/MetalKit renderer reported 0.0% in four consecutive one-second idle samples on the same Mac after the model settled. These are short local observations, not a Bluetooth, energy, or cross-device benchmark.

## Code review and remaining checks

- The window and menu bar bind to one main-actor model. The serial service owns the C handles and drops stale deliveries by service identity. It no longer publishes timestamp-only changes. The live 25 ms protocol polling interval remains unchanged until timing can be verified on hardware.
- Input batching retains the quiet period and maximum delay; continuous UI edits should not be treated as acknowledged until the device replies. Capabilities and ranges gate settings, including legacy Clear Bass. The native build omits automatic packet recording.
- Next: explicitly connect the WH-1000XM6, record its firmware and finish, and verify sound modes, EQ, playback, phone-driven changes, disconnect/reconnect, and menu-only operation. Also verify on the macOS 15 deployment floor; the local runtime was macOS 27.3 on Apple silicon. Developer ID signing and notarization are separate release work.
