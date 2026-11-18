# Native macOS fork: initial review and implementation proposal

## Scope and status

Reviewed fork: `https://github.com/jfeflores/Sony-Connect-MAC`, default branch `v1-compat`, commit `17c7cd51e70740782828dd5c3d1432a9b3364684`.

At inspection, the fork's HEAD matched `mos9527/SonyHeadphonesClient`'s `v1-compat` HEAD. The working directory was initially empty; the fork was cloned here for inspection.

This is a focused, static architecture/security review and migration proposal, **not a comprehensive security audit, penetration test, or implemented native application**. Reviewed areas include the build/release configuration, public C ABI, framing/session code, macOS Bluetooth backend, reference-client event loop, diagnostic capture, license, and selected device support documentation. Generated protocol implementations, every platform, and every device/firmware combination were not exhaustively reviewed. No confirmed exploitation or security severity is claimed.

No repository builds, tests, dependency installs, or Bluetooth/device operations were executed. Target-controlled execution requires an isolated, resource-limited sandbox before validation. The active developer directory points to Command Line Tools; `xcodebuild -version` reports that full Xcode is not selected. Runtime performance, signing, permission behavior, sandbox compatibility, and hardware parity remain unvalidated. Two delegated reviews failed at the provider; the observations below were reviewed directly rather than relying on their results.

## Confirmed product decisions

- Temporary product name: **Project XMConnect**; not final branding or a cleared trademark.
- Initial hardware target: **WH-1000XM6 over-ear headphones**, confirmed by the user, with firmware described as latest. Record the exact firmware version during hardware validation.
- Native app minimum: **macOS 15+**.
- Use Apple's native UI/animation frameworks, applying **Material 3 Expressive** design principles rather than introducing an Android or web frontend.
- User-provided phone screenshots will arrive later and will guide visual fidelity. Defer final screen composition and visual approval until those references are available.
- Main app and menu-bar controls must preserve supported hardware functionality and share the same session.

These decisions supersede the tentative baseline and naming suggestions in the initial review.

## Executive recommendation

Keep the existing C++ headphone protocol engine and Objective-C++ macOS transport. Add a separate SwiftUI/AppKit application target using the existing C ABI. Do not rewrite the protocol in Swift and replace the UI simultaneously.

The project already produces a standalone `.app` (`client/CMakeLists.txt:101–107`), but the visible controls are SDL3/ImGui (`client/CMakeLists.txt:146–224`), not native SwiftUI/AppKit controls. Metal-backed rendering does not make those controls native.

Useful foundations to preserve:

- Protocol/UI/transport separation: `libmdr/`, `libmdr-bt/`, and `client/`.
- Public C ABI with opaque handles, ABI-version checking, feature queries, device-reported ranges, and state-change events: `libmdr/include/mdr-c/Headphones.h`.
- Current/desired/submitted state handling: `libmdr/src/Property.hpp`.
- Frame length/checksum checks and bounded field readers: `libmdr/src/Command.cpp:96–138`, `libmdr/include/mdr/Protocol.hpp:449–460,504–516`.
- ABI and recorded-device replay tests, already invoked by CI: `tests/CMakeLists.txt`, `.github/workflows/cmake.yml:174–181`.
- macOS connection generations that reject stale callbacks: `libmdr-bt/src/MacOS/ConnectionMacOS.mm`.
- Sanitized diagnostic exports enabled by default, with failure rather than silent raw fallback for recognized malformed sensitive payloads: `client/Debugger.cpp:72–73,310–355`.

## Prioritized improvements

Priorities below are engineering order, not vulnerability severity.

### P1 — Bound incoming transport and framing buffers

**Source evidence:** The macOS delegate appends received bytes without a capacity limit (`libmdr-bt/src/MacOS/ConnectionMacOS.mm:179–186`). The session then appends them to `mRecvBuf` (`libmdr/src/Headphones.cpp:130–144`). `MoveNext()` returns without discarding anything when no start or end marker is found (`:242–248`).

**Consequence:** A connected peer sending continuous junk or an unterminated frame can cause retained bytes and repeated scans to grow. This is a source-grounded resource-exhaustion risk at the Bluetooth-peer-to-app boundary, not evidence that an arbitrary nearby unpaired device can attack the app. Runtime memory growth and practical peer preconditions still need validation. The 2,048-byte receive scratch array is not an accumulated-buffer limit.

**Fix:** Bound the transport backlog and assembled frame independently. Discard leading non-frame junk, define deterministic resynchronization, and fail/disconnect on excessive backlog or frame size. Derive limits from supported payloads, framing overhead, worst-case escaping, and any required chunked messages; do not blindly cap all wire frames at 2,048 bytes.

**Tests:** Long no-marker input, start marker without end marker, nested starts, oversized escaped frames, fragmented valid packets, malformed input followed by a valid packet, and transport overflow. Assert bounded retained bytes and recovery or a documented error.

### P1 — Remove automatic, unbounded packet recording from consumer builds

**Source evidence:** macOS CI explicitly enables `MDR_CLIENT_DEBUGGER` and `MDR_ENABLE_LOG` in MinSizeRel builds (`.github/workflows/cmake.yml:163–166`). Every observed packet is forwarded to the debugger independently of whether its window is open (`client/Client.cpp:1461–1473`). `AppendPacket` retains frame, decoded payload, and candidates with no history limit (`client/Debugger.cpp:1052–1064`). Detaching does not clear history (`:1375–1379`).

**Consequence:** Long sessions retain increasing diagnostic data and consume memory/decoding work. Raw in-memory captures can include playback metadata and paired-device identifiers; export sanitization does not sanitize the retained history. This is a privacy/retention and performance concern, not demonstrated data exfiltration. `MDR_ENABLE_LOG=ON` alone does not enable the `MDR_DEBUG` raw-byte dumps.

**Fix:** Separate consumer and diagnostic build configurations. Consumer builds disable packet capture/debugger and verbose logs. Diagnostic capture is explicit, bounded by bytes and count, clearable, and preferably time-limited; release logging uses privacy-aware Apple logging. Keep sanitized export as the default and test its coverage; do not describe it as guaranteed anonymization of unknown future packet types.

**Tests:** An hour-equivalent synthetic stream stays within the history byte limit; capture-off retains no packet payloads; disconnect/clear behavior is explicit; export redacts known identifiers and fails safely on unsupported sensitive layouts.

### P2 — Decouple UI refresh, protocol draining, and idle scheduling

**Source evidence:** The worker updates every 25 ms (`client/SDLMain.cpp:62–64,103–120`); `UpdateDeviceControls` calls `mdrHeadphonesPoll` once per update (`client/Client.cpp:2612–2621`); `MoveNext` handles at most one complete frame per call (`libmdr/src/Headphones.cpp:242–262`). Every packet also requests a redraw (`client/Client.cpp:1465–1468`), which starts a 60-frame redraw budget (`client/SDLMain.cpp:62,195–196`). UI and worker operations share a mutex (`:161–167`).

**Consequence:** Avoidable idle wakeups, burst-drain latency, and redraw work are plausible. The threaded reference client processes at most roughly 40 frames/second through this path, less when work takes time. No measured CPU or energy saving is claimed.

**Fix:** In the native app, keep protocol operations on one serial execution context, drain buffered work with a time/frame budget, and publish only changed snapshots. Coalesce EQ/volume edits while preserving the final value. Wake on incoming bytes, commands, or protocol deadlines rather than treating the renderer as the session clock. Do not use an unbounded drain loop or a tight loop around the existing transport `Poll`: its readiness includes send availability, not just readable data (`ConnectionMacOS.mm:332–349`). Never block the main thread or synchronously wait on it from the session queue.

**Tests/measurement:** Burst notifications plus ACKs, command progress during bursts, command cancellation/reconnect, final slider value, and state changes made from the phone. Profile idle, active, minimized, and menu-only operation with Instruments before making optimization claims.

### P2 — Replace front-erased transport storage with a bounded queue

**Source evidence:** macOS receives into a vector and erases from its front on every read (`libmdr-bt/src/MacOS/ConnectionMacOS.mm:278–294`). That shifts the remaining backlog while holding the transport mutex.

**Fix:** Use a bounded ring buffer or read cursor with amortized compaction. Preserve byte order, asynchronous write ownership, and generation checks. Benchmark representative bursts before deciding whether additional transport changes are worthwhile.

### P1 before public distribution — Add a real macOS release pipeline

**Source evidence:** The inspected macOS CI packages the app into a ZIP; no Developer ID signing, hardened-runtime configuration, notarization, or stapling appears in that path (`.github/workflows/cmake.yml:163–201`). The plist has empty short/build versions and the upstream bundle identifier (`client/Platform/MacOS/Info.plist:13–28`).

**Fix:** Give the native target its own bundle ID and populated versions; embed required licenses; sign all executable components with Developer ID and appropriate hardened-runtime settings; notarize and staple the app/distribution. Validate installation on a clean Mac. Prefer a signed/notarized direct-download release first; do not promise Mac App Store acceptance or sandbox compatibility before validating the Bluetooth APIs and entitlements.

**Validation:** Inspect final signatures and entitlements, verify notarization/Gatekeeper acceptance, and test Bluetooth permission grant, denial, and recovery. This is a release-readiness gap, not evidence of an existing malicious binary.

### P2 — Make dependencies and CI inputs reproducible

**Source evidence:** Several dependencies use Git tags rather than immutable commits (`contrib/CMakeLists.txt:14–43`); workflow actions likewise use version tags (`.github/workflows/cmake.yml`). This is not proof of compromised dependencies or a known CVE.

**Fix:** Pin dependency/action commits, document controlled updates, use least-privilege workflow permissions, and separate fork checks from privileged signing/release jobs. Inventory licenses for what is actually shipped. The native target should omit SDL, ImGui, and their UI fonts rather than carrying unused cross-platform UI dependencies; `fmt` remains relevant to the protocol library.

### Additional API hardening for the Swift boundary

The C connection wrappers validate the connection pointer but forward other arguments (`libmdr/src/Headphones.cpp:2244–2298`). macOS receive/send assume usable pointers and nonnegative lengths. Treat argument validation and Swift buffer ownership as wrapper invariants. This is same-process API robustness, not a demonstrated remote vulnerability.

## Native macOS application design

### Implementation boundaries

- **Native app target:** SwiftUI scenes, views, animations, localization, settings, and accessibility; AppKit only for lifecycle/window/menu behavior that needs it.
- **Swift adapter:** Import `mdr-c` and `mdr-bt` through a Clang module/bridging boundary. The existing C ABI is sufficient; Objective-C++ glue is optional if packaging/lifetime requirements justify it.
- **Session service:** One owner for `MDRHeadphones` and its connection on a dedicated serial context. Serialize reads, writes, polling, teardown, and callback lifetime. Copy values into Swift snapshots before publishing to a `@MainActor` UI model. An actor alone is not a reason to perform blocking waits on Swift's cooperative thread pool.
- **Transport:** Preserve `IOBluetooth` RFCOMM initially. The existing Mac frontend explicitly rejects BLE (`client/Platform/MacOS/ClientConnection.cpp:7–10`). Do not substitute CoreBluetooth and assume the same protocol transport will work.
- **Build:** Keep CMake for the native C++ libraries and existing tests; integrate pinned library outputs into an Xcode macOS app target without linking the SDL/ImGui frontend. Keep the reference client available during parity validation and preserve upstream codegen sources/regeneration checks.

### UI direction: phone-familiar, Mac-usable

Use the user's exact phone app/device/version as visual authority before choosing a final layout. The current repo's theme is explicitly inspired by Android Sound Connect (`client/README.md`, `client/MaterialYouTheme.hpp:33–48`); that is not evidence of iPhone pixel parity. The official iPhone listing was verified through Apple's lookup API, but its retrieved images are mainly promotional illustrations, not sufficient detailed screen references.

Proposed functional structure, subject to reference screenshots:

- A device overview with connection state, recognizable original/licensed device illustration, battery parts, and supported codec information.
- Sound controls with noise cancellation/ambient/off choices, device-reported ambient range, EQ presets/bands/Clear Bass, and supported DSEE/listening controls.
- Device/system settings for multipoint, Speak-to-Chat, buttons, wearing detection, power, and voice guidance where actually supported.
- A compact phone-like window as the initial composition, with sensible resizing rather than stretching a phone screenshot. Use SF typography, native focus/keyboard behavior, accessible slider values, VoiceOver, contrast, and Reduce Motion support.
- Purposeful SwiftUI transitions for expanding controls, connection progress, and mode changes. Avoid continuous idle animation or treating an unacknowledged command as confirmed device state.

Define permission-denied, Bluetooth-off, unpaired, connecting, initializing, ready, applying, reconnecting, unsupported-feature, and device-error states. Do not leave a stale slider looking successfully applied after disconnect.

### Menu bar and lifecycle

Interpret “menu bar” as both a system status item and normal macOS app commands unless the user prefers otherwise.

- SwiftUI `MenuBarExtra` with `.window` style for battery, connection, noise mode, ambient level, and an EQ preset shortcut; offer Open App, Settings, Disconnect, and Quit.
- Main window and menu extra share one session; never open two competing control connections to the same headset.
- Closing the main window keeps the app/session alive while menu-bar mode is enabled; Quit explicitly tears down the session. Make Dock visibility an intentional preference, not an accidental consequence of `LSUIElement`.
- Standard About, Settings, Window, and Quit commands with keyboard shortcuts.
- Login launch should be opt-in using Apple's supported service-management APIs.

`MenuBarExtra` requires macOS 13+. The existing client targets macOS 12 in CI, but the user has confirmed **macOS 15+** for Project XMConnect. The new native target can use SwiftUI `MenuBarExtra` and Observation without a macOS 12 compatibility layer; do not change the shared libraries' deployment target unnecessarily.

## Functional parity: important limits

Separate **parity with the current open-source client** from **parity with Sony's entire phone app**.

The C ABI exposes batteries, playback, NC/ambient, EQ, DSEE, peripherals, assignable controls, wearing/power, voice assistant, connection mode, and safe listening. Build a per-device acceptance checklist using feature queries and reported ranges; do not hardcode support from a product name.

Device documentation has different coverage: `docs/device-support/WH-1000XM5.md` still labels multipoint/Speak-to-Chat untested and other features unavailable, while the XM6 document describes broader support and a dangerous voice-control/listening-mode interaction already guarded by the backend. These documents are evidence to verify, not guarantees about the user's firmware.

Do not promise firmware installation, downloadable voice languages, Sony account/cloud features, phone-location/activity automations, 360-audio setup, or all Sony content/services as a UI-only migration. Firmware initialization flags and firmware-version text are not a complete updater API. The XM6 notes explicitly say Voice Control language requires Sony language data and is unsupported. Retain such workflows in Sony's app unless separately implemented and validated.

A Mac app cannot enable unsupported Bluetooth audio codecs simply by displaying the headset's codec options. Device configuration and the Mac's actual audio route/codec are distinct concerns.

## Rebranding and license boundaries

The fork and immediate upstream are MIT licensed. The earlier Plutoberth project linked by the README is also MIT licensed, with its own copyright notice.

Permitted by the reviewed project license: modify, rename, distribute, sublicense, and sell the software. MIT does not require publishing modifications or retaining the original product name in the visible UI.

Required approach:

1. Preserve the applicable upstream copyright and MIT permission/warranty notice in source distributions and the shipped application, for example in bundled license resources and About → Licenses. Do not replace the original copyright with only ours. If older code/assets are retained from the earlier project, preserve its applicable notice too; this review does not establish the lineage of every file.
2. Add our own copyright only for our contributions. Keep third-party dependency/font notices for anything actually redistributed; the root MIT file is not a blanket substitute for their licenses.
3. Replace product name, icon, display name, bundle ID, UI copy, artwork, documentation/links, and release-artifact names deliberately. Do not blindly rename protocol constants, compatible model identifiers, or upstream attribution.
4. Use an independent product identity; retain a clear “not affiliated with or endorsed by Sony” statement. Compatibility wording can identify supported hardware without presenting the app as an official Sony product.
5. Do not extract/copy Sony logos, app icons, illustrations, device renders, or other proprietary assets merely because the open-source implementation is MIT. Similar functionality/layout does not establish rights to exact protected artwork or overall branding. Verify asset provenance and obtain legal review if close visual imitation is a public-release requirement.

Confirmed temporary working name: **Project XMConnect**. This is not a trademark/domain availability check or final public branding. Final name/icon need approval and clearance.

## Phased delivery and acceptance gates

### 1. Establish baseline and harden shared code

Confirm target headphone(s)/firmware, Mac/OS baseline, and priority features. Record current feature behavior against that hardware. Implement bounded buffering/capture and dedicated consumer configuration with regression tests. Retain passing C ABI and packet replay tests on both relevant Mac architectures.

### 2. Prove the native integration

Create a native app target plus adapter, initially with a plain device list, connect/disconnect, battery, and noise-mode control. Verify permissions, lifecycle, late callbacks, reconnect, and teardown on real hardware before investing in full visual polish. Add mock-session tests for disconnected/error states.

### 3. Confirm the visual brief and implement parity

Collect screenshots from the exact phone app screens and firmware. Confirm independent branding and a phone-familiar Mac composition. Implement feature-gated controls and app settings; test bidirectional changes made from both the phone and Mac. Use snapshots for layout checks but do not treat previews/mock values as hardware parity.

### 4. Add menu-bar behavior and native animation

Reuse the same session/model. Validate keyboard/VoiceOver navigation, menu-only operation, close versus quit behavior, optional login launch, light/dark appearance, and Reduce Motion.

### 5. Release validation

Profile energy/memory and command latency. Test Bluetooth toggles, phone multipoint contention, device power-off, sleep/wake, permission revocation, supported protocol families, and firmware-specific refusals. Bundle license resources, sign, notarize, staple, and verify clean-machine installation. Commit/publish only when explicitly requested.

## Remaining inputs before hardware and visual validation

- Record exact WH-1000XM6 firmware and phone platform/app version. The user will provide screenshots of overview, sound/EQ, and device settings later.
- Confirm Mac architectures and distribution channel before release packaging. Minimum macOS 15+ and temporary name Project XMConnect are settled.
- Select final public branding and clear assets before public distribution.

## External references checked

- [Immediate upstream MIT license](https://github.com/mos9527/SonyHeadphonesClient/blob/v1-compat/LICENSE)
- [Earlier Plutoberth MIT license](https://github.com/Plutoberth/SonyHeadphonesClient/blob/master/LICENSE)
- [Apple MenuBarExtra documentation](https://developer.apple.com/documentation/swiftui/menubarextra)
- [Apple IOBluetoothRFCOMMChannel documentation](https://developer.apple.com/documentation/iobluetooth/iobluetoothrfcommchannel)
- [Official Sony Sound Connect iPhone listing](https://apps.apple.com/us/app/sony-sound-connect/id1168502924), verified via `https://itunes.apple.com/lookup?id=1168502924&country=us`
- [Sony LinkBuds Open: app capabilities and model-dependent caveat](https://helpguide.sony.net/mdr/2964/v1/en/contents/TP1001298893.html); this is one model's guide, not a universal support matrix.
