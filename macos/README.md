# Sonico

Native macOS 15+ development app. The SwiftUI window and menu bar share a serialized session backed by `libmdr` and `IOBluetooth`; the upstream SDL/ImGui client is separate.

## Build and try it

With Swift 6/Xcode, CMake 3.31+, and an installed `fmt` 12 package:

```sh
bash macos/build.sh
open 'build-native/macos/Sonico.app' --args --demo
```

The script runs the native model tests and upstream C ABI/replay tests. The app is ad-hoc signed for local development, not a notarized release. Xcode 26+ compiles the adaptive icon; older toolchains use the static fallback.

Launch with `--demo` or select **Explore Demo** from the connection screen to see the connected layout and motion without Bluetooth. The **Preview finishes** menu in the demo header shows the four original RealityKit portrait variants. The app never contacts hardware in demo mode.

For live validation, pair your headphones in System Settings, keep their original Bluetooth name, then choose **Find Paired Headphones** and **Connect**. Discovery recognizes the over-ear WH-1000XM3 through WH-1000XM6. Transport selection follows upstream’s V1/V2 split. The model and finish on the connected portrait come from MDR identity, not the name shown in the Bluetooth list. Unknown finishes use a neutral material, and unknown model identifiers use a neutral icon. Retail shades may differ from the reported broad color category.

## Motion and validation

The native portrait performs one 640 ms ease-in-out turn with a first-frame crossfade per recognized session. Routine updates and returning to the overview do not replay it. After it settles, click and drag horizontally for a full turn or vertically for a limited tilt. Use Rotate Left, Rotate Right, and Reset View without a drag. Reduce Motion skips the reveal and makes the portrait ready immediately. The XM6 uses original parametric geometry sculpted from the supplied reference and device-selected materials. No Blender, image import, or third-party app runtime is needed. The developer-only LottieFiles guidance is installed under `.agents/skills/motion-design/` and locked in `skills-lock.json`; no Sony-branded image, mesh, or animation file is bundled.

The WH-1000XM6 is the first physical target. Confirm live identity and finish, connection/reconnection, battery, noise changes, EQ, and menu bar controls on hardware before public distribution. In particular, detecting a supported model in discovery does not guarantee its specific firmware or macOS Bluetooth behavior. See [design notes](../DESIGN.md) for visual and motion rules.
