import MapKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: ControllerModel
    @State private var showingImporter = false

    var body: some View {
        VStack(spacing: 14) {
            header
            HSplitView {
                controls
                    .frame(minWidth: 360, idealWidth: 400, maxWidth: 460)
                routeAndLog
                    .frame(minWidth: 500)
            }
        }
        .padding(18)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.xml]) { result in
            switch result {
            case .success(let url): model.selectRoute(url)
            case .failure(let error): model.alertMessage = error.localizedDescription
            }
        }
        .alert(
            "操作提示",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.alertMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Run Like Bolt · Mac 控制端")
                    .font(.title2.bold())
                Text("通过 USB 和 iOS Developer Services 播放测试定位")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(model.status, systemImage: model.isRunning ? "location.fill" : "iphone.gen3")
                .foregroundStyle(model.isRunning ? .orange : .secondary)
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(spacing: 12) {
                GroupBox("设备") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("可选：设备 UDID", text: $model.udid)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("检查设备", systemImage: "stethoscope") { model.doctor() }
                            Button("准备设备", systemImage: "externaldrive.badge.checkmark") { model.prepare() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(model.isRunning)

                GroupBox("GPX 路线") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button("选择 GPX…", systemImage: "folder") { showingImporter = true }
                            Button("加载示例", systemImage: "figure.run") { model.loadSampleRoute() }
                        }
                        if let route = model.route {
                            Text(route.name).font(.headline).lineLimit(1)
                            LabeledContent("轨迹点", value: "\(route.pointCount)")
                            LabeledContent("路线时长", value: route.durationText)
                        } else {
                            Text("尚未选择文件").foregroundStyle(.secondary)
                        }
                        Button("开始播放", systemImage: "play.fill") { model.play() }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.route == nil || model.isRunning)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(model.isRunning)

                GroupBox("静态位置") {
                    VStack(spacing: 10) {
                        HStack {
                            TextField("纬度", text: $model.latitude)
                            TextField("经度", text: $model.longitude)
                        }
                        .textFieldStyle(.roundedBorder)
                        Button("设置静态位置", systemImage: "mappin.and.ellipse") {
                            model.setStaticLocation()
                        }
                        .disabled(model.isRunning)
                    }
                }
                .disabled(model.isRunning)

                GroupBox("安全控制") {
                    HStack {
                        Button("停止", systemImage: "stop.fill", role: .destructive) { model.stop() }
                            .disabled(!model.isRunning)
                        Button("恢复真实定位", systemImage: "location.slash") { model.clearLocation() }
                            .disabled(model.isRunning)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var routeAndLog: some View {
        VStack(spacing: 12) {
            GroupBox("路线预览") {
                if let route = model.route {
                    RouteMap(route: route)
                        .frame(minHeight: 300)
                } else {
                    ContentUnavailableView("选择 GPX 以预览", systemImage: "map")
                        .frame(minHeight: 300)
                }
            }
            GroupBox {
                VStack(spacing: 8) {
                    HStack {
                        Text("运行日志").font(.headline)
                        Spacer()
                        Button("清空") { model.clearLog() }
                            .buttonStyle(.plain)
                    }
                    ScrollView {
                        Text(model.log)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(minHeight: 170)
                    .padding(8)
                    .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

private struct RouteMap: View {
    let route: GPXRoute
    @State private var position: MapCameraPosition

    init(route: GPXRoute) {
        self.route = route
        _position = State(initialValue: .region(route.region))
    }

    var body: some View {
        Map(position: $position) {
            MapPolyline(coordinates: route.coordinates)
                .stroke(.blue, lineWidth: 4)
            if let first = route.coordinates.first {
                Marker("起点", coordinate: first).tint(.green)
            }
        }
        .mapStyle(.standard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
