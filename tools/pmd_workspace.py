#!/usr/bin/env python3
"""Launch pymobiledevice3 while keeping its private state in this workspace."""

from pathlib import Path
import os
import sys


runtime_value = os.environ.get("ECUPL_LOCATION_RUNTIME")
if not runtime_value:
    print("ECUPL_LOCATION_RUNTIME is not set", file=sys.stderr)
    raise SystemExit(2)

runtime_dir = Path(runtime_value).resolve()
state_dir = runtime_dir / "state" / "pymobiledevice3"
state_dir.mkdir(parents=True, exist_ok=True)

# pymobiledevice3 has no environment variable for its ~/.pymobiledevice3 folder.
# Override that one package-level path before loading its CLI instead of changing HOME.
import pymobiledevice3.common

pymobiledevice3.common._HOMEFOLDER = state_dir

from pymobiledevice3.__main__ import main


if __name__ == "__main__":
    main()
