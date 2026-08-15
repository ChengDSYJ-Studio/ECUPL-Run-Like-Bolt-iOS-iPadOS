#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname -- "$SCRIPT_DIR")
RUNTIME_DIR="$PROJECT_DIR/.runtime"
APP_DIR="$RUNTIME_DIR/ECUPLLocationController.app"
EXECUTABLE="$RUNTIME_DIR/mac-controller-build/debug/ECUPLLocationController"

if [ ! -x "$RUNTIME_DIR/venv/bin/python" ]; then
    printf '%s\n' "尚未安装定位运行环境。请先执行：" >&2
    printf '  %s\n' "$PROJECT_DIR/scripts/setup-location-runtime.sh" >&2
    exit 2
fi

mkdir -p "$RUNTIME_DIR/mac-controller-build" "$RUNTIME_DIR/swift-module-cache" "$RUNTIME_DIR/tmp"
export ECUPL_PROJECT_DIR="$PROJECT_DIR"
export TMPDIR="$RUNTIME_DIR/tmp"
export CLANG_MODULE_CACHE_PATH="$RUNTIME_DIR/swift-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$RUNTIME_DIR/swift-module-cache"

swift build \
    --package-path "$PROJECT_DIR/MacLocationController" \
    --scratch-path "$RUNTIME_DIR/mac-controller-build"

mkdir -p "$APP_DIR/Contents/MacOS"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/ECUPLLocationController"
cp "$PROJECT_DIR/MacLocationController/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR"

exec open -W "$APP_DIR"
