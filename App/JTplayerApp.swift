import AmplayerKit
import SwiftUI

@main
struct JTplayerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            PlayerScreen()
                .environment(model)
                .tint(.jtAccent)
                .task { model.installDemoContentIfNeeded() }
                #if DEBUG
                .task { DebugHooks.run(model) }
                #endif
        }
    }
}
