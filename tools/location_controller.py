#!/usr/bin/env python3
"""Workspace-local macOS controller for iPhone developer location simulation."""

from __future__ import annotations

import argparse
from importlib.metadata import PackageNotFoundError, version
import json
import math
import os
from pathlib import Path
import platform
import signal
import subprocess
import sys

from defusedxml import ElementTree as ET
from defusedxml.common import DefusedXmlException


PROJECT_DIR = Path(__file__).resolve().parents[1]
RUNTIME_DIR = PROJECT_DIR / ".runtime"
PYTHON = RUNTIME_DIR / "venv" / "bin" / "python"
PMD_LAUNCHER = PROJECT_DIR / "tools" / "pmd_workspace.py"


class ControllerError(RuntimeError):
    pass


def require_runtime() -> None:
    if not PYTHON.is_file():
        raise ControllerError(
            "未找到工作区运行环境。请先执行 scripts/setup-location-runtime.sh"
        )


def pmd_command(arguments: list[str]) -> list[str]:
    return [str(PYTHON), str(PMD_LAUNCHER), *arguments]


def pmd_environment() -> dict[str, str]:
    directories = {
        "TMPDIR": RUNTIME_DIR / "tmp",
        "PYTHONPYCACHEPREFIX": RUNTIME_DIR / "pycache",
        "XDG_CACHE_HOME": RUNTIME_DIR / "cache",
    }
    for directory in directories.values():
        directory.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    environment.update({key: str(value) for key, value in directories.items()})
    environment["ECUPL_LOCATION_RUNTIME"] = str(RUNTIME_DIR)
    return environment


def run_pmd(arguments: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    require_runtime()
    return subprocess.run(
        pmd_command(arguments), text=True, check=check, env=pmd_environment()
    )


def validate_coordinate(latitude: float, longitude: float) -> None:
    if not math.isfinite(latitude) or not -90 <= latitude <= 90:
        raise ControllerError("纬度必须是 -90 到 90 之间的有限数值")
    if not math.isfinite(longitude) or not -180 <= longitude <= 180:
        raise ControllerError("经度必须是 -180 到 180 之间的有限数值")


def inspect_gpx(path: Path) -> int:
    if not path.is_file():
        raise ControllerError(f"GPX 文件不存在：{path}")
    if path.stat().st_size > 128 * 1024 * 1024:
        raise ControllerError("GPX 文件超过 128 MB 安全上限")
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, DefusedXmlException) as error:
        raise ControllerError(f"GPX XML 无法解析：{error}") from error

    points = []
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1] != "trkpt":
            continue
        try:
            latitude = float(element.attrib["lat"])
            longitude = float(element.attrib["lon"])
        except (KeyError, ValueError) as error:
            raise ControllerError("GPX 中存在缺少或无效的 lat/lon 坐标") from error
        validate_coordinate(latitude, longitude)
        points.append((latitude, longitude))
        if len(points) > 250_000:
            raise ControllerError("GPX 超过 250000 个轨迹点上限")

    if len(points) < 2:
        raise ControllerError("GPX 至少需要两个 trkpt 轨迹点")
    return len(points)


def device_options(args: argparse.Namespace) -> list[str]:
    return ["--udid", args.udid] if getattr(args, "udid", None) else []


def clear_location(*, udid: str | None = None, quiet: bool = False) -> bool:
    options = ["--udid", udid] if udid else []
    result = run_pmd(
        ["developer", "dvt", "simulate-location", "clear", *options], check=False
    )
    if result.returncode == 0:
        if not quiet:
            print("已请求恢复真实定位。")
        return True
    if not quiet:
        print("恢复真实定位失败；请重启 iPhone。", file=sys.stderr)
    return False


def run_until_stopped(arguments: list[str], *, clear_after: bool, udid: str | None) -> int:
    require_runtime()
    command = pmd_command(arguments)
    process = subprocess.Popen(command, start_new_session=True, env=pmd_environment())

    def forward_signal(signum: int, _frame: object) -> None:
        if process.poll() is None:
            os.killpg(process.pid, signum)

    previous_interrupt = signal.signal(signal.SIGINT, forward_signal)
    previous_terminate = signal.signal(signal.SIGTERM, forward_signal)
    try:
        return process.wait()
    finally:
        signal.signal(signal.SIGINT, previous_interrupt)
        signal.signal(signal.SIGTERM, previous_terminate)
        if clear_after:
            clear_location(udid=udid, quiet=False)


def command_doctor(_args: argparse.Namespace) -> int:
    print(f"系统：{platform.system()} {platform.release()} ({platform.machine()})", flush=True)
    print(f"项目目录：{PROJECT_DIR}", flush=True)
    print(f"运行环境：{RUNTIME_DIR}", flush=True)
    require_runtime()
    try:
        version_text = version("pymobiledevice3")
    except PackageNotFoundError:
        raise ControllerError("工作区虚拟环境中没有安装 pymobiledevice3")
    print(f"pymobiledevice3：{version_text}", flush=True)
    print("\n正在检查 USB 设备：", flush=True)
    result = subprocess.run(
        pmd_command(["usbmux", "list", "--usb", "--simple"]),
        text=True,
        capture_output=True,
        check=False,
        env=pmd_environment(),
    )
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr.strip(), file=sys.stderr)
        raise ControllerError(
            "无法读取设备。请解锁 iPhone、使用数据线连接，并在手机上选择“信任”。"
        )
    try:
        devices = json.loads(result.stdout)
    except json.JSONDecodeError:
        devices = result.stdout.strip()
    if not devices:
        print("未发现 USB 设备。连接并解锁 iPhone 后重新运行 doctor。")
        return 1
    print(result.stdout.strip())
    print("\n设备已发现。请继续确认 iPhone 已开启“设置 > 隐私与安全性 > 开发者模式”。")
    return 0


def command_devices(_args: argparse.Namespace) -> int:
    return run_pmd(["usbmux", "list"], check=False).returncode


def command_prepare(args: argparse.Namespace) -> int:
    print("正在为设备准备 Developer Disk Image；首次运行可能需要下载。")
    result = run_pmd(["mounter", "auto-mount", *device_options(args)], check=False)
    if result.returncode != 0:
        print("准备失败。请确认设备已解锁、受信任并开启开发者模式。", file=sys.stderr)
    return result.returncode


def command_set(args: argparse.Namespace) -> int:
    validate_coordinate(args.latitude, args.longitude)
    print("开始设置虚拟定位。按 Ctrl+C 停止并恢复真实定位。")
    return run_until_stopped(
        [
            "developer",
            "dvt",
            "simulate-location",
            "set",
            *device_options(args),
            "--",
            str(args.latitude),
            str(args.longitude),
        ],
        clear_after=not args.keep,
        udid=args.udid,
    )


def command_play(args: argparse.Namespace) -> int:
    path = args.gpx.expanduser().resolve()
    point_count = inspect_gpx(path)
    print(f"GPX 检查通过：{point_count} 个点")
    print("开始播放路线。按 Ctrl+C 停止并恢复真实定位。")
    command = [
        "developer",
        "dvt",
        "simulate-location",
        "play",
        *device_options(args),
    ]
    if args.timing_noise:
        command += ["--timing-randomness-range", str(args.timing_noise)]
    command.append(str(path))
    return run_until_stopped(command, clear_after=not args.keep, udid=args.udid)


def command_clear(args: argparse.Namespace) -> int:
    return 0 if clear_location(udid=args.udid) else 1


def add_device_argument(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--udid", help="指定目标设备 UDID；默认使用第一台 USB 设备")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="通过 Mac 和 iOS Developer Services 控制已连接 iPhone 的测试定位。"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    doctor = subparsers.add_parser("doctor", help="检查本地环境和 USB 连接")
    doctor.set_defaults(handler=command_doctor)

    devices = subparsers.add_parser("devices", help="列出已连接的 iPhone/iPad")
    devices.set_defaults(handler=command_devices)

    prepare = subparsers.add_parser("prepare", help="为设备挂载开发者磁盘映像")
    add_device_argument(prepare)
    prepare.set_defaults(handler=command_prepare)

    set_parser = subparsers.add_parser("set", help="设置一个静态位置")
    add_device_argument(set_parser)
    set_parser.add_argument("latitude", type=float, help="纬度")
    set_parser.add_argument("longitude", type=float, help="经度")
    set_parser.add_argument(
        "--keep", action="store_true", help="命令结束后不自动恢复真实定位"
    )
    set_parser.set_defaults(handler=command_set)

    play = subparsers.add_parser("play", help="播放 GPX 路线")
    add_device_argument(play)
    play.add_argument("gpx", type=Path, help="GPX 文件路径")
    play.add_argument(
        "--timing-noise",
        type=int,
        default=0,
        metavar="MILLISECONDS",
        help="每个点增加的随机时间扰动范围，默认 0",
    )
    play.add_argument(
        "--keep", action="store_true", help="播放结束后不自动恢复真实定位"
    )
    play.set_defaults(handler=command_play)

    clear = subparsers.add_parser("clear", help="恢复真实定位")
    add_device_argument(clear)
    clear.set_defaults(handler=command_clear)
    return parser


def main() -> int:
    try:
        args = build_parser().parse_args()
        if not 0 <= getattr(args, "timing_noise", 0) <= 60_000:
            raise ControllerError("时间扰动必须在 0 到 60000 毫秒之间")
        return int(args.handler(args))
    except ControllerError as error:
        print(f"错误：{error}", file=sys.stderr)
        return 2
    except subprocess.CalledProcessError as error:
        print(f"设备控制命令失败，退出码 {error.returncode}。", file=sys.stderr)
        return error.returncode or 1
    except FileNotFoundError as error:
        print(f"无法启动设备控制程序：{error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
