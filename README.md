# ECUPL Run Like Bolt Lab for iOS

这是一个面向**自有 iOS/iPadOS App 定位测试**的路线配置器：输入操场四角 WGS-84 坐标，设置配速、圈数和开始时间，即可预览平滑环线并导出 GPX 回放文件。

## 范围

- 支持四角跑道、预设、圈数、速度、定时提醒和 GPX 导出。
- 导出的 GPX 可加入 Xcode Test Plan，在自有 App 的定位测试中回放。
- 不是系统级 Mock Location 提供者；不能让微信或其他第三方 App 接收虚拟定位。

## 打开与运行

1. 安装完整 Xcode（Command Line Tools 不足以构建 iOS App）。
2. 用 Xcode 打开 `ECUPLRunLikeBoltLab.xcodeproj`。
3. 在 Signing & Capabilities 选择你的 Development Team，再连接 iPhone/iPad 运行。
4. 填写四个角点后，点击“导出 GPX”，在系统分享表中保存或发送文件。

工程没有第三方依赖；开发安装只需要 Xcode，本项目不会向系统安装其他工具。

## Xcode 测试回放

将导出的 `.gpx` 加到你的 App 工程，然后在 Test Plan 的 Configuration > Localization > Simulated Location 中选择它。GPX 是用于受控测试输入的标准 Xcode 工作流。

## 坐标约定

输入 WGS-84 经纬度。四个点顺序不限，程序会围绕中心自动排序并在角落以二次 Bézier 曲线平滑转弯。
