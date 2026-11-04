import SwiftUI

@main
struct ColiDevApp: App {
    @StateObject private var store = LearningStore()
    @StateObject private var backendSupervisor = LocalBackendSupervisor()
    @StateObject private var updater = AppUpdateController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(backendSupervisor)
                .environmentObject(updater)
                .frame(minWidth: 980, minHeight: 680)
                .tint(AppPalette.accent.color)
                .background(AppPalette.canvas.color.ignoresSafeArea())
        }
    }
}
