#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname -- "$SCRIPT_DIR")
RUNTIME_DIR="$PROJECT_DIR/.runtime"
VENV_DIR="$RUNTIME_DIR/venv"

mkdir -p "$RUNTIME_DIR/pip-cache" "$RUNTIME_DIR/tmp" "$RUNTIME_DIR/pycache"

export PIP_CACHE_DIR="$RUNTIME_DIR/pip-cache"
export TMPDIR="$RUNTIME_DIR/tmp"
export PYTHONPYCACHEPREFIX="$RUNTIME_DIR/pycache"

if [ ! -x "$VENV_DIR/bin/python" ]; then
    python3 -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install --requirement "$PROJECT_DIR/requirements-location.txt"

printf '%s\n' "定位控制运行环境已安装到：$RUNTIME_DIR"
printf '%s\n' "下一步运行：$PROJECT_DIR/scripts/locationctl doctor"
