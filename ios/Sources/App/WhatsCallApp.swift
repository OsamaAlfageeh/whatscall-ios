import SwiftUI

@main
struct WhatsCallApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(model.vpn)
                .task { await model.start() }
        }
    }
}
