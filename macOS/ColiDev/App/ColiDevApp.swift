import SwiftUI

@main
struct ColiDevApp: App {
    @NSApplicationDelegateAdaptor(ColiDevAppDelegate.self) private var appDelegate
    // The same models serve the window, the menu bar and the workshop overlay. / Одни модели на окно, меню и оверлей.
    @StateObject private var store = AppServices.shared.store
    @StateObject private var backendSupervisor = AppServices.shared.backend
    @StateObject private var updater = AppUpdateController()
    @StateObject private var workshop = AppServices.shared.workshop

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
            VStack(spacing: 0) {
                WorkshopView(model: workshop, compact: true)
                HStack {
                    Button(L10n.text("menu.overlay", store.language)) { WorkshopOverlay.shared.show() }
                    Spacer()
                    Button(L10n.text("menu.quitForReal", store.language)) {
                        WorkshopBackground.quitForReal = true
                        NSApp.terminate(nil)
                    }
                }
                .padding(10)
            }
                .environmentObject(store)
                .tint(AppPalette.accent.color)
                .frame(width: 460, height: 640)
                .onAppear { WorkshopHub.shared.connect(store: store, model: workshop) }
        } label: {
            Image(systemName: "sparkles")
                .accessibilityLabel(L10n.text("workshop.title", store.language))
        }
        .menuBarExtraStyle(.window)
    }
}
