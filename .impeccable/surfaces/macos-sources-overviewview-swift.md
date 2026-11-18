---
version: 1
slug: "macos-sources-overviewview-swift"
primary_target: "macos/Sources/OverviewView.swift"
related_targets: ["macos/Sources/HeadphonePortrait.swift","macos/Sources/EqualizerView.swift","macos/Sources/DeviceSettingsView.swift","macos/Sources/MenuBarView.swift"]
---

# Native device window and menu bar

Mode: Operate. Confirmed audience, stack, hardware and scope are recorded in PRODUCT.md. This is code-led app work, not a generated visual comp.

## Direction contract

THESIS: A phone-familiar WH-1000XM6 controller with a Mac window and a genuinely shared menu-bar session. Do not replace the supplied screen hierarchy with a generic dashboard.

OWN-WORLD: User-pinned Material 3 Expressive plus supplied Sound Connect screens: pale device header, near-black ground, charcoal rounded groups, lavender selected states, SF typography and SF Symbols. Original, model-specific 3D portraits rendered in RealityKit; no proprietary device renders. Shape and state changes spring responsively, with Reduce Motion honored.

STORY: Select paired headphones, connect explicitly, inspect actual status, adjust sound, and keep quick controls available when the main window closes. Disconnected/initializing/error/demo states are unmistakable.

FIRST VIEWPORT: A compact resizable Mac window with toolbar navigation. Overview starts with the pale model/battery header and then sound mode, EQ, multipoint and playback groups. EQ has a measured response display and an accessible ten-band editor; range and count are device-reported. Settings use the supplied grouped disclosure hierarchy.

FORM: seed: none (pinned). User: “as similar to actual app on the phone as possible” and “material 3 expressive design philosophy ... alongside ... photos of the mobile app ... for the native Mac app”; the five supplied screenshots pin the first-surface experience. User approved “After reviewing, you may begin.” A recognized connection triggers a single 580 ms turn into a three-quarter resting pose. Use an immediate resting pose under Reduce Motion; battery and settings updates never replay it. The lavender selection indicator remains the sound-mode feedback.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Boundaries

No copied Sony art, no phone cloud/Scene/Discover placeholders, no firmware-update promises, no testing against the user's headphones without consent. A native headphone symbol is the fallback for identities without a matching portrait. Do not guess the finish of an unreported device. Initial app-only build is distinct from complete reference-client feature parity. Hardware integration remains an explicit validation gate.
