import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject private var store: TrackStore
    @State private var configuration = TrackConfiguration()
    @State private var preview: TrackPath?
    @State private var error: String?
    @State private var exportedFile: URL?
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            Form {
                Section("用途") {
                    Text("用于自有 iOS/iPadOS App 的定位测试与 GPX 导出，不会改变其他 App 的系统定位。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("操场预设") {
                    Picker("已保存预设", selection: Binding(get: { configuration.id }, set: { id in if let found = store.presets.first(where: { $0.id == id }) { configuration = found; refreshPreview() } })) {
                        Text("新建配置").tag(configuration.id)
                        ForEach(store.presets) { Text($0.name).tag($0.id) }
                    }
                    TextField("预设名称", text: $configuration.name)
                    HStack { Button("保存/覆盖") { store.save(configuration) }; Spacer(); Button("删除", role: .destructive) { store.delete(configuration) } }
                    if let example = store.presets.first {
                        Button("加载示例坐标") { configuration = example; refreshPreview() }
                    }
                }
                Section("四个角（WGS-84）") {
                    ForEach(configuration.corners.indices, id: \.self) { index in
                        VStack(alignment: .leading) {
                            Text("角点 \(index + 1)").font(.caption).foregroundStyle(.secondary)
                            HStack { TextField("纬度", value: $configuration.corners[index].latitude, format: .number).keyboardType(.numbersAndPunctuation); TextField("经度", value: $configuration.corners[index].longitude, format: .number).keyboardType(.numbersAndPunctuation) }
                        }
                    }
                    Button("更新路线预览") { refreshPreview() }
                }
                Section("跑圈参数") {
                    TextField("速度（米/秒）", value: $configuration.speedMetersPerSecond, format: .number).keyboardType(.decimalPad)
                    Stepper("圈数：\(configuration.laps)", value: $configuration.laps, in: 1...1_000)
                    DatePicker("GPX 开始时间", selection: Binding($configuration.scheduledStart, replacingNilWith: Date()), displayedComponents: [.date, .hourAndMinute])
                    Button("安排开始提醒") { Task { do { try await StartReminder.schedule(for: configuration) } catch { self.error = error.localizedDescription } } }
                    Text("开始时间写入 GPX 时间戳；App 只提供提醒和导出，不能在后台控制系统定位。") .font(.footnote).foregroundStyle(.secondary)
                }
                if let preview {
                    Section("路线预览") {
                        TrackMap(path: preview)
                        LabeledContent("单圈长度", value: String(format: "%.0f 米", preview.length))
                        LabeledContent("预计总时长", value: duration(preview.length * Double(configuration.laps) / configuration.speedMetersPerSecond))
                    }
                }
                Section { Button("导出 GPX") { export() }.frame(maxWidth: .infinity) }
            }
            .navigationTitle("Run Like Bolt Lab")
            .alert("无法生成路线", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") }
            .sheet(isPresented: $showingShare) { if let exportedFile { ShareSheet(items: [exportedFile]) } }
            .onAppear { refreshPreview() }
        }
    }

    private func refreshPreview() { do { preview = try TrackPath(configuration: configuration) } catch { preview = nil; self.error = error.localizedDescription } }
    private func export() { do { exportedFile = try GPXExporter.export(configuration: configuration); showingShare = true } catch { self.error = error.localizedDescription } }
    private func duration(_ seconds: Double) -> String { let f = DateComponentsFormatter(); f.allowedUnits = [.hour, .minute, .second]; f.unitsStyle = .abbreviated; return f.string(from: seconds) ?? "—" }
}

private struct TrackMap: View {
    let path: TrackPath
    @State private var position: MapCameraPosition = .automatic
    var body: some View { Map(position: $position) { MapPolyline(coordinates: path.sampled(spacingMeters: 3).map(\.coordinate)).stroke(.blue, lineWidth: 4); ForEach(path.points.indices, id: \.self) { index in if index % 33 == 0 { Marker("", coordinate: path.points[index]).tint(.orange) } } }.frame(height: 260).clipShape(.rect(cornerRadius: 10)).onAppear { position = .region(MKCoordinateRegion(center: path.points[0], latitudinalMeters: max(70, path.length / 2), longitudinalMeters: max(70, path.length / 2))) } }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private extension Binding where Value == Date? {
    init(_ source: Binding<Date?>, replacingNilWith fallback: Date) { self.init(get: { source.wrappedValue ?? fallback }, set: { source.wrappedValue = $0 }) }
}
