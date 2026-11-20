# Building a Sonico installer

The installer contains one universal Sonico app (Apple silicon and Intel) for macOS 15 or later. It installs to `/Applications` using Apple Installer. It has no installation scripts and does not launch Sonico or connect to a device.

## Create the artifacts

On macOS, install Xcode with Swift 6 and CMake 3.31+. Apple silicon builders need Rosetta to run the Intel tests. Commit the release changes first. The packaging script builds that exact revision in a temporary directory, tests both architectures, and verifies the install path, binary slices, and bundled licenses. It creates a `.pkg`, a corresponding source archive with the pinned `fmt` source, and SHA-256 checksums in `dist/`. Set `SONICO_RELEASE_DIR` to use another empty output directory.

For internal inspection only:

```sh
bash macos/package.sh --unsigned-draft
```

The `-UNSIGNED.pkg` is not a public installer. Do not ask users to disable or bypass Gatekeeper.

## Sign and notarize

Set these environment variables on the release Mac before running the signed build:

- `SONICO_APP_IDENTITY`: full **Developer ID Application** identity with its private key installed in Keychain.
- `SONICO_INSTALLER_IDENTITY`: full **Developer ID Installer** identity with its private key installed in Keychain.
- `SONICO_NOTARY_PROFILE`: profile name already saved with `xcrun notarytool store-credentials`.

```sh
bash macos/package.sh --signed
```

The signed path uses hardened runtime for the app, signs the product package, waits for Apple notarization, staples the ticket, and checks Gatekeeper acceptance. It does not upload files or publish a release.

## Release checklist

1. Review the [owner-confirmed WH-1000XM6 check](macos-validation.md#owner-confirmed-hardware-check). Report only the confirmed recognition and control behavior; do not infer firmware-wide support or full feature coverage.
2. Verify the downloaded, quarantined installer on a clean Mac. Confirm it installs to `/Applications`, launches, works in demo mode, and requests Bluetooth permission only when connecting. Test on the minimum macOS version and on a physical Intel Mac if claiming Intel validation.
3. Attach the signed `.pkg`, the matching `-source.tar.gz`, and `SHA256SUMS.txt` to a GitHub release whose tag points at the revision recorded in `BUILD-INFO.txt`. Remove unsigned review assets before publishing. Test the download and install instructions at the release URL.

See [Apple’s distribution guide](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution) and the [Sonico validation notes](macos-validation.md).
