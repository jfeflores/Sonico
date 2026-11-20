#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${SONICO_RELEASE_DIR:-$ROOT/dist}"
MODE="${1:-}"

case "$MODE" in
    --unsigned-draft) suffix=-UNSIGNED ;;
    --signed)
        : "${SONICO_APP_IDENTITY:?Set the Developer ID Application identity}"
        : "${SONICO_INSTALLER_IDENTITY:?Set the Developer ID Installer identity}"
        : "${SONICO_NOTARY_PROFILE:?Set the notarytool keychain profile}"
        [[ "$SONICO_APP_IDENTITY" == "Developer ID Application: "* ]]
        [[ "$SONICO_INSTALLER_IDENTITY" == "Developer ID Installer: "* ]]
        suffix= ;;
    *) printf 'Usage: bash macos/package.sh --unsigned-draft|--signed\n' >&2; exit 2 ;;
esac

# Build and archive one committed revision, never untracked or dirty working files.
if ! git -C "$ROOT" diff --quiet HEAD --; then
    printf 'Commit the release changes before packaging.\n' >&2
    exit 2
fi
REV="$(git -C "$ROOT" rev-parse HEAD)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sonico-package.XXXXXX")"
trap 'printf "Build workspace: %s\n" "$WORK"' EXIT
mkdir -p "$OUT" "$WORK/source"
OUT="$(cd "$OUT" && pwd)"
SRC="$WORK/source/Sonico"
mkdir -p "$SRC"
git -C "$ROOT" archive "$REV" | tar -xf - -C "$SRC"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$SRC/macos/Resources/Info.plist")"
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$SRC/macos/Resources/Info.plist")"
PKG="Sonico-$VERSION-universal$suffix.pkg"
SOURCE="Sonico-$VERSION-source.tar.gz"
for name in "$PKG" "$SOURCE" SHA256SUMS.txt; do
    if [[ -e "$OUT/$name" ]]; then printf 'Refusing to replace %s\n' "$OUT/$name" >&2; exit 2; fi
done

# Use and distribute the same pinned fmt source; no Homebrew libraries at runtime.
FMT_NAME=fmt-12.2.1.zip
FMT_SHA=870a49acec5bcdab236aeea834ebd7f0b8548a7d8cea33c996b6873a37f2d50c
mkdir -p "$SRC/third-party"
FMT_ZIP="$SRC/third-party/$FMT_NAME"
if [[ -n "${SONICO_FMT_ARCHIVE:-}" ]]; then
    cp "$SONICO_FMT_ARCHIVE" "$FMT_ZIP"
else
    curl --fail --location --silent --show-error --retry 2 \
        "https://github.com/fmtlib/fmt/releases/download/12.2.1/$FMT_NAME" -o "$FMT_ZIP"
fi
printf '%s  %s\n' "$FMT_SHA" "$FMT_ZIP" | shasum -a 256 -c -
ditto -x -k "$FMT_ZIP" "$WORK/vendor"
cmake -S "$WORK/vendor/fmt-12.2.1" -B "$WORK/fmt" -DCMAKE_BUILD_TYPE=Release \
    -DFMT_DOC=OFF -DFMT_TEST=OFF -DCMAKE_INSTALL_PREFIX="$WORK/fmt-prefix"
cmake --build "$WORK/fmt" --parallel 4
cmake --install "$WORK/fmt"

# Run the full test suite for both slices; Apple silicon builders need Rosetta for Intel tests.
for arch in arm64 x86_64; do
    XMCONNECT_BUILD_DIR="$WORK/$arch" bash "$SRC/macos/build.sh" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" -DCMAKE_PREFIX_PATH="$WORK/fmt-prefix"
done
STAGE="$WORK/stage"
APP="$STAGE/Sonico.app"
mkdir -p "$STAGE"
ditto "$WORK/arm64/macos/Sonico.app" "$APP"
EXEC="$APP/Contents/MacOS/Sonico"
xcrun lipo -create "$WORK/arm64/macos/Sonico.app/Contents/MacOS/Sonico" \
    "$WORK/x86_64/macos/Sonico.app/Contents/MacOS/Sonico" -output "$EXEC"
verify_universal() {
    local archs
    archs="$(xcrun lipo -archs "$1")"
    if [[ "$archs" != 'x86_64 arm64' && "$archs" != 'arm64 x86_64' ]]; then
        printf 'Expected a universal binary, found: %s\n' "$archs" >&2
        return 1
    fi
}
verify_universal "$EXEC"
if otool -arch all -L "$EXEC" | grep -E '^[[:space:]]*(@(rpath|loader_path|executable_path)/|/opt/|/usr/local/)'; then
    printf 'Unexpected non-system runtime dependency\n' >&2
    exit 1
fi

{
    printf 'Sonico %s\nSource revision: %s\nMinimum macOS: %s\nArchitectures: arm64, x86_64\n' "$VERSION" "$REV" "$MIN_OS"
    xcodebuild -version
    printf 'fmt source: %s (%s)\n' "$FMT_NAME" "$FMT_SHA"
} > "$SRC/BUILD-INFO.txt"
cp "$SRC/BUILD-INFO.txt" "$APP/Contents/Resources/BUILD-INFO.txt"
if [[ "$MODE" == --signed ]]; then
    codesign --force --sign "$SONICO_APP_IDENTITY" --options runtime --timestamp "$APP"
else
    codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"

# Install exactly one bundle to /Applications, without install scripts or relocation.
pkgbuild --analyze --root "$STAGE" "$WORK/components.plist"
if /usr/libexec/PlistBuddy -c 'Print :0:BundleIsRelocatable' "$WORK/components.plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$WORK/components.plist"
else
    /usr/libexec/PlistBuddy -c 'Add :0:BundleIsRelocatable bool false' "$WORK/components.plist"
fi
pkgbuild --root "$STAGE" --component-plist "$WORK/components.plist" \
    --install-location /Applications --identifier app.xmconnect.project.pkg \
    --version "$VERSION" "$WORK/component.pkg"
cat > "$WORK/requirements.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>os</key><array><string>$MIN_OS</string></array>
<key>arch</key><array><string>arm64</string><string>x86_64</string></array>
</dict></plist>
PLIST
productbuild --synthesize --product "$WORK/requirements.plist" \
    --package "$WORK/component.pkg" "$WORK/Distribution.xml"
if [[ "$MODE" == --signed ]]; then
    productbuild --distribution "$WORK/Distribution.xml" --package-path "$WORK" \
        --sign "$SONICO_INSTALLER_IDENTITY" --timestamp "$WORK/$PKG"
    xcrun notarytool submit "$WORK/$PKG" --keychain-profile "$SONICO_NOTARY_PROFILE" --wait
    xcrun stapler staple "$WORK/$PKG"
    xcrun stapler validate "$WORK/$PKG"
    spctl --assess --type install --verbose "$WORK/$PKG"
else
    productbuild --distribution "$WORK/Distribution.xml" --package-path "$WORK" "$WORK/$PKG"
fi

pkgutil --expand-full "$WORK/$PKG" "$WORK/expanded"
PAYLOAD="$WORK/expanded/component.pkg/Payload/Sonico.app"
[[ -d "$PAYLOAD" ]]
[[ ! -e "$WORK/expanded/component.pkg/Scripts" ]]
grep -q 'install-location="/Applications"' "$WORK/expanded/component.pkg/PackageInfo"
verify_universal "$PAYLOAD/Contents/MacOS/Sonico"
codesign --verify --deep --strict "$PAYLOAD"
cmp "$SRC/LICENSE" "$PAYLOAD/Contents/Resources/LICENSE.txt"
for notice in NOTICE MIT-SonyHeadphonesClient MIT-Plutoberth; do
    cmp "$SRC/LICENSES/$notice.txt" "$PAYLOAD/Contents/Resources/$notice.txt"
done
cmp "$SRC/macos/Resources/FMT-LICENSE.txt" "$PAYLOAD/Contents/Resources/FMT-LICENSE.txt"
COPYFILE_DISABLE=1 tar -czf "$WORK/$SOURCE" -C "$WORK/source" Sonico
(
    cd "$WORK"
    shasum -a 256 "$PKG" "$SOURCE" > SHA256SUMS.txt
)
mv "$WORK/$PKG" "$WORK/$SOURCE" "$WORK/SHA256SUMS.txt" "$OUT/"
printf '\nRelease files: %s (%s)\n' "$OUT" "$MODE"
