import Foundation

@MainActor
final class ControllerModel: ObservableObject {
    @Published var route: GPXRoute?
    @Published var latitude = "31.2300"
    @Published var longitude = "121.4700"
    @Published var udid = ""
    @Published var log = "等待操作。\n"
    @Published var status = "尚未检查设备"
    @Published var isRunning = false
    @Published var runningAction = ""
    @Published var alertMessage: String?

    private var activeProcess: Process?
    private var outputPipe: Pipe?

    let projectURL: URL

    init(projectURL: URL? = nil) {
        if let projectURL {
            self.projectURL = projectURL
        } else if let path = ProcessInfo.processInfo.environment["ECUPL_PROJECT_DIR"] {
            self.projectURL = URL(fileURLWithPath: path, isDirectory: true)
        } else if Bundle.main.bundleURL.pathExtension == "app" {
            self.projectURL = Bundle.main.bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        } else {
            self.projectURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        }
    }

    func selectRoute(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            route = try GPXRoute.load(from: url)
            appendLog("已载入 GPX：\(url.path)")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadSampleRoute() {
        let url = projectURL.appendingPathComponent("ECUPLRunLikeBoltLab/Resources/SampleStadium.gpx")
        guard FileManager.default.fileExists(atPath: url.path) else {
            showError("找不到项目内置的示例 GPX")
            return
        }
        selectRoute(url)
    }

    func doctor() { run(arguments: ["doctor"], title: "检查设备") }

    func prepare() {
        run(arguments: ["prepare"] + deviceArguments, title: "准备设备")
    }

    func play() {
        guard let route else {
            showError("请先选择 GPX 文件")
            return
        }
        run(arguments: ["play"] + deviceArguments + [route.url.path], title: "播放路线")
    }

    func setStaticLocation() {
        guard let latitudeValue = Double(latitude), let longitudeValue = Double(longitude),
              latitudeValue.isFinite, longitudeValue.isFinite,
              (-90...90).contains(latitudeValue), (-180...180).contains(longitudeValue) else {
            showError("请输入有效的纬度和经度")
            return
        }
        run(
            arguments: ["set"] + deviceArguments + [String(latitudeValue), String(longitudeValue)],
            title: "静态定位"
        )
    }

    func clearLocation() { run(arguments: ["clear"] + deviceArguments, title: "恢复真实定位") }

    func stop() {
        guard let process = activeProcess, process.isRunning else { return }
        status = "正在停止并恢复真实定位…"
        appendLog("发送停止请求…")
        process.interrupt()
    }

    func clearLog() { log = "" }

    func shutdown() {
        guard let process = activeProcess, process.isRunning else { return }
        process.interrupt()
    }

    private var deviceArguments: [String] {
        let value = udid.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? [] : ["--udid", value]
    }

    private func run(arguments: [String], title: String) {
        guard !isRunning else {
            showError("请先停止当前操作")
            return
        }
        let executable = projectURL.appendingPathComponent("scripts/locationctl")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            showError("找不到可执行的 scripts/locationctl")
            return
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = projectURL
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.appendRaw(text) }
        }

        process.terminationHandler = { [weak self, weak pipe] finished in
            pipe?.fileHandleForReading.readabilityHandler = nil
            let remaining = pipe?.fileHandleForReading.readDataToEndOfFile() ?? Data()
            Task { @MainActor in
                if let text = String(data: remaining, encoding: .utf8), !text.isEmpty {
                    self?.appendRaw(text)
                }
                self?.activeProcess = nil
                self?.outputPipe = nil
                self?.isRunning = false
                self?.runningAction = ""
                if finished.terminationStatus == 0 {
                    self?.status = "\(title)完成"
                    self?.appendLog("\(title)完成。")
                } else {
                    self?.status = "\(title)失败（退出码 \(finished.terminationStatus)）"
                    self?.alertMessage = self?.status
                }
            }
        }

        do {
            appendLog("$ ./scripts/locationctl \(arguments.joined(separator: " "))")
            try process.run()
            activeProcess = process
            outputPipe = pipe
            isRunning = true
            runningAction = title
            status = "正在\(title)…"
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            showError("无法启动控制端：\(error.localizedDescription)")
        }
    }

    private func appendLog(_ text: String) {
        appendRaw("\(text)\n")
    }

    private func appendRaw(_ text: String) {
        log += text
        if log.count > 80_000 { log.removeFirst(log.count - 80_000) }
    }

    private func showError(_ message: String) {
        alertMessage = message
        appendLog("错误：\(message)")
    }
}
