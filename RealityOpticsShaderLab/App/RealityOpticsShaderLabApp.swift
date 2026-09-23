import SwiftUI

@main
struct RealityOpticsShaderLabApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            MobileContentView()
                .environment(appModel)
            #else
            ContentView()
                .environment(appModel)
            #endif
        }
        #if os(visionOS)
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentMinSize)
        #endif
    }
}
