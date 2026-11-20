#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${XMCONNECT_BUILD_DIR:-$ROOT/build-native}"
# Uses an existing fmt 12 installation by default; no dependency downloads.
cmake -S "$ROOT" -B "$BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DMDR_BUILD_MACOS_APP=ON \
    -DMDR_BUILD_CLIENT=OFF \
    -DMDR_BUILD_BT=ON \
    -DMDR_USE_SYSTEM_FMT=ON \
    -DMDR_BUILD_CODEGEN=OFF \
    -DMDR_BUILD_TESTING=ON \
    -DMDR_BUILD_SHARED=ON \
    -DMDR_ENABLE_LOG=OFF \
    -DMDR_DEBUG=OFF \
    "$@"
cmake --build "$BUILD" --target Sonico xmconnect_tests mdr_tests --parallel 4
ctest --test-dir "$BUILD" --output-on-failure
printf '\nApp: %s/macos/Sonico.app\n' "$BUILD"
