import SwiftUI

@main
struct ColiDevApp: App {
    @StateObject private var store = LearningStore()
    @StateObject private var backendSupervisor = LocalBackendSupervisor()
    @StateObject private var updater = AppUpdateController()
    @StateObject private var workshop = WorkshopModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(backendSupervisor)
                .environmentObject(updater)
                .environmentObject(workshop)
                .frame(minWidth: 980, minHeight: 680)
                .tint(AppPalette.accent.color)
                .background(AppPalette.canvas.color.ignoresSafeArea())
        }
        // The workshop in the menu bar (macOS 13+). / Мастерская в строке меню (macOS 13+).
        MenuBarExtra {
            WorkshopView(model: workshop, compact: true)
                .environmentObject(store)
                .tint(AppPalette.accent.color)
                .frame(width: 460, height: 600)
                .onAppear { WorkshopHub.shared.connect(store: store, model: workshop) }
        } label: {
            Image(systemName: "sparkles")
                .accessibilityLabel(L10n.text("workshop.title", store.language))
        }
        .menuBarExtraStyle(.window)
    }
}
