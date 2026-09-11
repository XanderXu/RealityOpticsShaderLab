import SwiftUI

@main
struct RealityOpticsShaderLabApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentMinSize)
    }
}
