---
name: sonico-adaptive-icon
description: Rebuild and verify Sonico's layered macOS app icon without breaking older build toolchains. Use this skill when changing the icon art, appearance variants, Dock/Finder packaging, or the Xcode/CMake build for the icon.
---

# Sonico adaptive icon

**Failure pattern:** Icon Composer content compiles on modern Xcode but cannot be the only icon source on older Xcode or Command Line Tools. Incremental builds can also keep an obsolete `Assets.car` when switching to the fallback.

**Verified by:** Both `-DSONICO_ADAPTIVE_ICON=OFF` and `=ON` passed the native build and tests in the same build directory. The fallback bundle contained only `AppIcon.icns`; switching back restored `Assets.car`. Icon Composer previewed the six appearances and the small-size default.

1. Edit `macos/Icon/AppIcon.icon/icon.json` and its original filled SVG layers. Do not draw the rounded exterior, system shadow, or tint yourself. Keep `AppIcon` as the basename in the build and plist.
2. To refresh the checked-in legacy icon after an art change, run from the repo root using full Xcode 26 or newer:
   ```sh
   out=$(mktemp -d)
   xcrun actool macos/Icon/AppIcon.icon --compile "$out" --platform macosx \
     --minimum-deployment-target 15.0 --app-icon AppIcon \
     --output-partial-info-plist "$out/Info.plist" --errors --warnings
   test -s "$out/AppIcon.icns" && cp "$out/AppIcon.icns" macos/Icon/AppIcon.icns
   ```
   Only the `.icns` fallback is checked in; CMake compiles and bundles the `.car` on supported toolchains.
3. Preview with `"$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"`. Export `Default`, `Dark`, `TintedLight`, `TintedDark`, `ClearLight`, and `ClearDark`; check readability at 16 and 32 pt as well. Run both build modes and verify the final signature at `build-native/macos/Sonico.app`.

**What didn't work:** `xcrun` availability alone did not distinguish a toolchain that can compile `.icon`. An installed Xcode upgrade also left `actool` unusable until Xcode completed first launch. `xcrun ictool` is not the renderer above, and bare `Tinted`/`Clear` are not recognized rendition names.
