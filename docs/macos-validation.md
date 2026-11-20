# Sonico: native validation

This complements the earlier [architecture review](MACOS-REVIEW.md). It is not device certification or a full security audit.

## Owner-confirmed hardware check

The project owner tested a physical WH-1000XM6 and confirmed Sonico recognizes it and that the controls work. A repeat hardware session is not required for this release. The exact firmware and a per-control test matrix were not reported, so this does not establish full feature coverage across hardware or firmware versions.

## Sonico polish pass

- Build: `bash macos/build.sh`; demo: `open build-native/macos/Sonico.app --args --demo`. Seven CTest suites passed, including 54 model assertions. Strict ad-hoc signature verification passed. Adaptive icon and static fallback builds both passed; Icon Composer light/dark, tinted/clear and 16/32 pt previews were inspected. The adaptive catalog is built with Xcode 26+ and supported by newer macOS; the `.icns` fallback covers macOS 15.
- Palette tests covered all represented colors, models, appearances and contrast settings: minimum **5.09:1** for the tested text roles and **3.43:1** for EQ guides. Native demo QA inspected Silver, Midnight Blue in dark mode and Sand Pink in light mode (the latter two seeded in a temporary QA build). Exercised EQ editing, Settings navigation, and orbit/reset; resetting matched the original crop exactly. No Bluetooth activity was initiated.
- The XM6 geometry remains original. [Sony's product photo](https://electronics.sony.com/audio/headphones/headband/p/wh1000xm6-b), [parts diagrams](https://helpguide.sony.net/mdr/2984/v1/en/contents/TP1001856813.html), and user-provided reference images informed the silhouette and physical details. None is bundled.
- Following [BAMA Performance](https://github.com/daveebbelaar/bama/tree/22dc792ea040a35270c219c669f626594267aa1f/skills/code/performance), the optimized release microbenchmark measured median warm XM6 construction at **22.3 → 17.3 ms** in repeated runs, and material-only updates at approximately **17–19 ms**. The sculpt went from 34 renderable entities to one actor-owned mesh, with its surfaces grouped by material. These measurements exclude window presentation and GPU frame latency. Idle demo process CPU displayed 0.0% in three consecutive one-second samples. No claim is made about Bluetooth battery life, cold-start latency, or GPU throughput.

To run the microbenchmark from the project root (on Apple silicon):

```sh
out=$(mktemp -d)
swiftc -O -target arm64-apple-macosx15.0 -parse-as-library \
  macos/Sources/{Domain,FinishPalette,Theme,HeadphonePortrait,PortraitRenderer,PortraitOrbit,XM6Sculpture}.swift \
  macos/Tests/PortraitBench.swift -o "$out/portrait-bench"
"$out/portrait-bench"
```

## EQ, settings, and navigation pass

- Demo shows factory names only: Off, Heavy, Clear, Hard, Soft for XM6; legacy options for earlier XM demos. It does not include personal presets, custom curves, sample tracks, or fictitious paired devices. Live preset names and the active preset are read from the headset; other slots' curves are not available until the headset activates them. Draft band edits and Clear Bass are not sent until Apply Changes; Sonico rechecks the slot after polling and before submission. V1 custom slot curves remain read-only because its band write does not name the edited slot.
- Expanded Settings use capability and range checks for ambient controls, Speak-to-Chat, listening, button assignments, automatic power, voice options, and multipoint playback. Unsupported controls and combinations are not offered. Headphone-initiated pairing, connect/disconnect of secondary sources, and unpairing remain in Bluetooth Settings or the reference client. Sony account, firmware, and companion-app-only functions are outside this pass.
- Playback follows MDR notifications and requests a readback after transport commands; title, artist, album, and source are shown only when the headset reports them. This does not try to read global macOS media state with private APIs. Timing and metadata behavior on physical hardware still need verification.
- An isolated demo instance exercised preset selection, adding/hiding/reordering a saved shortcut, and selecting Settings after resizing the window to 537 points. The 640 ms RealityKit reveal starts after the headset is recognized and the app can read settings; Reduce Motion skips it. No Bluetooth discovery, connection, or writes were started for these tests.

## Earlier Project XMConnect validation

- A fresh `bash macos/build.sh` build passed all seven CTest suites, including 48 Swift model assertions. SourceKit reported no diagnostics across the native sources and tests. The app passed strict ad-hoc signature verification, and its executable does not link a Homebrew dylib. The bundle includes the upstream MIT and fmt notices.
- In explicit demo mode, the device overview, noise-mode selection and ambient slider, ten-band EQ editor and flat reset, grouped settings, and the disconnected state were exercised. The accessibility tree exposed the rotation buttons, band frequencies, and selected listening mode. No Bluetooth discovery, connections, or device writes were initiated.
- In the demo, drag changed the rendered portrait and **Reset View** restored a pixel-identical crop. Rotation becomes available after the final frame of the 580 ms entrance. Source review confirmed that Reduce Motion bypasses the entrance and that leaving the page or closing the window detaches the renderer. System-wide Reduce Motion and VoiceOver were not exercised end to end.
- The previous `RealityView` path showed 42.5% process CPU in one resting demo sample. The on-demand RealityKit/MetalKit renderer reported 0.0% in four consecutive one-second idle samples on the same Mac after the model settled. These are short local observations, not a Bluetooth, energy, or cross-device benchmark.

## Code review and remaining checks

- The window and menu bar bind to one main-actor model. The serial service owns the C handles and drops stale deliveries by service identity. It no longer publishes timestamp-only changes. The live 25 ms protocol polling interval remains unchanged until timing can be verified on hardware.
- Input batching retains the quiet period and maximum delay; continuous UI edits should not be treated as acknowledged until the device replies. Capabilities and ranges gate settings, including legacy Clear Bass. The native build omits automatic packet recording.
- Next: verify installation of the Developer ID-signed, notarized installer on a clean Mac. The local runtime was macOS 27.3 on Apple silicon; macOS 15 and physical Intel runtime behavior were not independently verified.
