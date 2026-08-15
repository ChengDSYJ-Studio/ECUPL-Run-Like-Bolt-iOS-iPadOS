import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: ControllerModel?

    func applicationWillTerminate(_ notification: Notification) {
        model?.shutdown()
    }
}

@main
struct ECUPLLocationControllerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = ControllerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 720)
                .onAppear { appDelegate.model = model }
        }
        .defaultSize(width: 1080, height: 780)
        .windowResizability(.contentMinSize)
    }
}
