import SwiftUI

@main
struct ECUPLRunLikeBoltLabApp: App {
    @StateObject private var store = TrackStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
