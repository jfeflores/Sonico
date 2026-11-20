# Sonico

Sonico is an independent macOS app for controlling Sony WH-1000X headphones from your Mac. Switch listening modes, access the EQ stored on your headphones, and keep quick controls in the menu bar.

## Requirements

- macOS 15 or later
- Swift 6 with the macOS SDK, CMake 3.31 or later, and an installed `fmt` 12 package
- For a live connection: WH-1000XM3, XM4, XM5, or XM6 paired in macOS Bluetooth Settings. Controls depend on the model and firmware. The XM6 is the primary target; [live validation is still in progress](docs/macos-validation.md).

## Installation

```sh
git clone https://github.com/jfeflores/Sonico.git
cd Sonico
bash macos/build.sh
```

The script builds `build-native/macos/Sonico.app` and runs the offline tests. The bundle is ad-hoc signed for local development, not notarized for distribution.

## Quick start

Try the app without Bluetooth:

```sh
open build-native/macos/Sonico.app --args --demo
```

For a live session, launch without `--demo`. Pair the headphones in macOS Bluetooth Settings, keep their original Bluetooth name, then choose **Find Paired Headphones** and **Connect** in Sonico. Connecting reads your EQ; it does not apply a preset or overwrite a custom slot.

<img src="docs/images/sonico-demo.webp" width="650" alt="Sonico in demo mode, showing a Platinum Silver WH-1000XM6 portrait, tabs, and customizable shortcuts">

## What it does

- View battery and connection state, switch noise canceling and ambient modes, and change headphone settings that the device reports.
- Read the active EQ and available profiles. Supported custom-slot edits stay local until you select **Apply Changes**. The demo shows factory names only, not personal profiles or invented gain values.
- View playback information when the headphones share it, and use playback and volume controls from the window or menu bar.
- Add, hide, and reorder controls with **Edit Shortcuts**. Rotate the original 3D headphone portrait by dragging or using its buttons; the connection reveal respects Reduce Motion.

## Documentation

- [Native build and usage notes](macos/README.md)
- [Validation results and known limits](docs/macos-validation.md)
- [Design system](DESIGN.md)
- [Separate upstream reference client](client/README.md)

## Credits

- **J ([@jfeflores](https://github.com/jfeflores))** created the separate SwiftUI/AppKit app, menu-bar controls, device-aware interface, EQ workflow, and customizable shortcuts. Sonico also adds the original RealityKit portraits and icon, a native build, and targeted fixes and tests for the shared libraries.
- **[mos9527](https://github.com/mos9527), [Amr Satrio](https://github.com/Amrsatrio), and the [SonyHeadphonesClient contributors](https://github.com/mos9527/SonyHeadphonesClient)** built and maintained the inherited protocol libraries, Bluetooth backends, cross-platform reference client, and test infrastructure. Sonico uses and extends that work; it did not originate those components.
- **[Plutoberth and contributors](https://github.com/Plutoberth/SonyHeadphonesClient)** created the earlier project in this lineage. Their original notice is preserved alongside the direct upstream notice.

Sonico is not affiliated with or endorsed by Sony.

## License

The native Sonico app is licensed under the [GNU Affero General Public License v3.0 only](LICENSE). The inherited code and shared libraries retain their [MIT license](LICENSES/MIT-SonyHeadphonesClient.txt). See the [license and attribution notice](LICENSES/NOTICE.txt) for scope, original notices, and dependency terms.
