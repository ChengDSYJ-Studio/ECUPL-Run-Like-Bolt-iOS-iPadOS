# ECUPL Run Like Bolt Lab for iOS/iPadOS

一个用于 iPhone/iPad 虚拟校园跑辅助工具，让你节省每一天的校园跑时间。输入操场四角的 WGS-84 坐标，设置速度、圈数和开始时间，即可预览平滑环线、导出 GPX，并通过连接的 Mac 在测试设备上播放路线。

## 工作方式

项目由两部分组成：

1. **iPhone/iPad App**：编辑跑道、预览路线、保存预设、安排提醒并导出 GPX。
2. **Mac 控制端**：通过 USB 和 iOS Developer Services，把 GPX 路线播放到已连接的测试设备。

```text
iPhone/iPad App 生成 GPX
          ↓
通过 AirDrop、文件共享等方式保存到 Mac
          ↓
Mac locationctl → USB → iPhone Developer Services
```

> iOS App 自身没有写入系统定位的权限。虚拟定位必须由连接的 Mac 发起，不能脱离电脑在手机上独立运行。

## 功能

- 输入顺序任意的四个 WGS-84 角点；
- 自动按中心排序角点，并用二次 Bézier 曲线平滑转弯；
- 设置速度、圈数和 GPX 开始时间；
- 使用 MapKit 预览路线和估算总时长；
- 将配置保存到本机预设；
- 导出符合 GPX 1.1 核心格式的带时间戳轨迹；
- 在 Mac 上发现 USB 设备、准备 Developer Disk Image；
- 播放 GPX、设置静态位置和恢复真实定位；
- 支持通过 UDID 指定设备。

## 系统要求

### iPhone/iPad App

- iOS/iPadOS 17 或更新版本；
- 完整版 Xcode；
- Apple Development Team，用于真机签名；
- iPhone/iPad 已开启开发者模式。

### Mac 控制端

- macOS；
- Python 3.9 或更新版本；
- Xcode Command Line Tools 或完整版 Xcode（可视化控制器需要）；
- 数据线连接的 iPhone/iPad；
- 设备已解锁并选择“信任此电脑”；
- 设备已开启“设置 > 隐私与安全性 > 开发者模式”。

## 构建 iPhone/iPad App

1. 使用 Xcode 打开 `ECUPLRunLikeBoltLab.xcodeproj`。
2. 选择 `ECUPLRunLikeBoltLab` Target。
3. 在 Signing & Capabilities 中选择你的 Development Team。
4. 选择已连接的 iPhone/iPad，然后运行。
5. 输入四个角点，更新预览并导出 GPX。
6. 使用 AirDrop、系统文件分享或其他方式，把 GPX 保存到 Mac。

App 不需要定位读取权限，因为它只显示用户输入的坐标，不读取设备当前位置。

## 安装 Mac 控制端

在项目根目录执行：

```sh
./scripts/setup-location-runtime.sh
```

安装脚本会创建工作区专用的 `.runtime/`，并安装固定版本的 `pymobiledevice3`。它不会修改系统 Python，也不会把工具状态写入 `~/.pymobiledevice3`。

安装后检查环境和 USB 连接：

```sh
./scripts/locationctl doctor
```

如果输出中显示设备 UDID，再准备 Developer Disk Image：

```sh
./scripts/locationctl prepare
```

首次准备可能需要联网下载与设备系统版本匹配的文件。

## Mac 可视化控制器

安装运行环境后，可以在 Finder 中双击 `RunLocationController.command`，也可以在终端执行：

```sh
./scripts/open-location-controller.sh
```

首次打开会在 `.runtime/` 中编译 SwiftUI 控制器并组装临时 App，不会安装到系统“应用程序”目录。窗口内可以：

- 检查和准备 USB 设备；
- 选择 GPX 或载入项目内置示例，并在地图上预览；
- 播放路线或设置静态经纬度；
- 指定设备 UDID；
- 随时停止播放、恢复真实定位并查看运行日志。

关闭窗口前建议点击“停止”或“恢复真实定位”。命令行接口仍可用于自动化和故障排查。

## 播放 GPX 路线

```sh
./scripts/locationctl play "/完整路径/路线.gpx"
```

控制端会先检查：

- GPX 是否是可解析的 XML；
- 是否包含至少两个 `trkpt`；
- 经纬度是否有效；
- 文件和轨迹点数量是否超过安全上限。

播放完成后按 Enter，或者在播放过程中按 `Ctrl+C`，控制端会尝试清除虚拟位置并恢复真实定位。

如果连接了多台设备，可以指定 UDID：

```sh
./scripts/locationctl play --udid 00008110-XXXXXXXXXXXX "/完整路径/路线.gpx"
```

可选的时间扰动参数，单位为毫秒：

```sh
./scripts/locationctl play --timing-noise 300 "/完整路径/路线.gpx"
```

## 设置静态位置

参数顺序为纬度、经度：

```sh
./scripts/locationctl set 31.2300 121.4700
```

按 `Ctrl+C` 停止并恢复真实定位。使用 `--keep` 可以让命令结束后保留模拟位置，但通常不建议这样做。

## 恢复真实定位

```sh
./scripts/locationctl clear
```

如果清除命令失败，请重启 iPhone/iPad。重启通常也会移除 Developer Services 设置的虚拟位置。

## 控制端命令

| 命令 | 作用 |
| --- | --- |
| `locationctl doctor` | 检查运行环境和 USB 设备 |
| `locationctl devices` | 列出已连接设备 |
| `locationctl prepare` | 挂载匹配的 Developer Disk Image |
| `locationctl set LAT LON` | 设置静态测试位置 |
| `locationctl play FILE.gpx` | 按时间戳播放 GPX |
| `locationctl clear` | 恢复真实定位 |

查看全部参数：

```sh
./scripts/locationctl --help
./scripts/locationctl play --help
```

## 工作区运行环境

所有新增的 Python 运行文件都集中在：

```text
.runtime/
├── venv/          Python 虚拟环境
├── pip-cache/     安装缓存
├── cache/         通用运行缓存
├── state/         pymobiledevice3 私有状态
├── tmp/           临时文件
├── pycache/       Python 字节码缓存
├── swift-module-cache/ Swift 模块缓存
├── mac-controller-build/ 可视化控制器构建产物
└── ECUPLLocationController.app/ 临时 App 包
```

`.runtime/` 已加入 `.gitignore`。要完全删除控制端运行环境，请先停止所有 `locationctl` 命令，然后删除项目根目录下的 `.runtime/`。之后重新执行安装脚本即可恢复。

设备信任记录和开发者模式是 macOS/iOS 系统状态，不存放在 `.runtime/` 中。

## 常见问题

### `doctor` 显示“未发现 USB 设备”

依次检查：

1. 使用支持数据传输的数据线；
2. 解锁 iPhone/iPad；
3. 在设备上选择“信任此电脑”；
4. 重新插拔数据线；
5. 再次运行 `./scripts/locationctl doctor`。

### 提示开发者模式未开启

在设备上进入“设置 > 隐私与安全性 > 开发者模式”，开启后按提示重启并确认。

### Developer Disk Image 挂载失败

确认 Mac 可以联网，然后重新运行：

```sh
./scripts/locationctl prepare
```

iOS 17.0–17.3.1 的设备通道可能额外需要管理员权限运行 `pymobiledevice3 remote tunneld`；iOS 17.4 及以上通常可以使用自动建立的用户态 USB 通道。

### 路线没有移动

- 确认 GPX 中包含带递增时间戳的 `trkpt`；
- 确认运行的不是只有单个点的 GPX；
- 先运行 `prepare`，再运行 `play`；
- 检查目标 App 是否有定位权限；
- 部分 App 会识别或拒绝模拟定位。

### 如何立即回到真实位置

先执行 `./scripts/locationctl clear`。如果仍未恢复，重启设备。

## 项目结构

```text
ECUPLRunLikeBoltLab/
├── App/             SwiftUI App 入口
├── Models/          跑道配置与预设存储
├── Services/        路线、GPX 和提醒服务
├── Views/           编辑与预览界面
└── Resources/       示例 GPX

scripts/
├── setup-location-runtime.sh
├── open-location-controller.sh
└── locationctl

MacLocationController/
└── Sources/         macOS SwiftUI 可视化控制器

RunLocationController.command  Finder 双击启动入口

tools/
├── location_controller.py
├── pmd_workspace.py
└── tests/
```

## 测试

控制端单元测试：

```sh
./.runtime/venv/bin/python -m unittest discover -s tools/tests -v
```

iOS 单元测试可在完整 Xcode 中运行 `ECUPLRunLikeBoltLabTests` Target。

## 限制与使用边界

- 必须连接 Mac，iPhone/iPad App 无法单独修改系统定位；
- 使用的是开发测试通道，不保证未来所有 iOS 版本保持兼容；
- 模拟位置可能影响设备上的地图、导航和其他定位功能；
- App 或服务可以检测、拒绝或记录模拟定位；
- 请只在你拥有或明确获准测试的设备、账号和 App 上使用。

## 第三方组件

Mac 控制端使用 `pymobiledevice3 10.7.4`，许可证为 GPL-3.0-or-later。详情参见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
