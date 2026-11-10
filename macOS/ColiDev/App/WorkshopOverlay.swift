import AppKit
import ServiceManagement
import SwiftUI

// The Creator Workshop as its own overlay: a borderless full-screen panel over every desktop and full-screen app with
// the same HUD page (core, sea, glass) as inside the app. The app keeps running in the background after its window is
// closed or ⌘Q, starts at login if the owner wants, and the wake word and hot key bring the overlay up from anywhere.
// Мастерская Творца как отдельный оверлей: панель без рамки на весь экран поверх всех столов и полноэкранных программ,
// с той же страницей HUD. Приложение продолжает работать в фоне после закрытия окна или ⌘Q, по желанию владельца
// запускается при входе, а слово вызова и горячая клавиша показывают оверлей откуда угодно.

/// One set of models for the window, the menu bar and the overlay. / Одни модели на окно, строку меню и оверлей.
@MainActor
final class AppServices {
    static let shared = AppServices()
    let store = LearningStore()
    let backend = LocalBackendSupervisor()
    let workshop = WorkshopModel()
}

/// Settings for staying in the background and starting at login. / Работа в фоне и запуск при входе.
enum WorkshopBackground {
    static let keepRunningKey = "workshop.background.keepRunning"
    static var keepRunning: Bool { UserDefaults.standard.object(forKey: keepRunningKey) as? Bool ?? true }
    /// Set by «Выйти совсем»: the next ⌘Q really quits. / После «Выйти совсем» ⌘Q действительно закрывает.
    static var quitForReal = false

    static var loginItemEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var loginItemNeedsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    /// The owner's switch in Settings; macOS may ask for approval in Login Items. / Переключатель владельца в настройках.
    @discardableResult
    static func setLoginItem(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            return false
        }
    }

    /// The app was started by macOS at login (then it stays hidden, only the workshop listens).
    /// Приложение запущено macOS при входе (тогда оно скрыто, слушает только Мастерская).
    static var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == AEEventID(kAEOpenApplication)
            && event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }
}

final class ColiDevAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            let services = AppServices.shared
            WorkshopHub.shared.connect(store: services.store, model: services.workshop)
            // A check shows the overlay at once. / Проверка сразу показывает оверлей.
            if ProcessInfo.processInfo.environment["COLIDEV_OVERLAY_AT_LAUNCH"] == "1" { WorkshopOverlay.shared.show() }
            if WorkshopBackground.launchedAtLogin {
                // At login: no window, no Dock icon; the backend and the wake word are ready. / При входе: без окна.
                NSApp.setActivationPolicy(.accessory)
                NSApp.windows.filter { !($0 is NSPanel) }.forEach { $0.close() }
                _ = await services.backend.ensureRunning()
            }
        }
    }

    /// ⌘Q closes the window but keeps the workshop listening; «Выйти совсем» in the menu bar really quits.
    /// ⌘Q закрывает окно, но Мастерская продолжает слушать; «Выйти совсем» в строке меню закрывает по-настоящему.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard WorkshopBackground.keepRunning, !WorkshopBackground.quitForReal else { return .terminateNow }
        NSApp.windows.filter { !($0 is NSPanel) }.forEach { $0.close() }
        NSApp.setActivationPolicy(.accessory)
        return .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Opening the app again brings back the Dock icon and a window. / Повторное открытие возвращает значок и окно.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        return true
    }
}

/// A borderless panel that can take the keyboard without pulling the app's window forward.
/// Панель без рамки, которая принимает клавиатуру и не тянет за собой окно приложения.
final class WorkshopOverlayPanel: NSPanel {
    var onCancel: () -> Void = {}
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel() }
}

@MainActor
final class WorkshopOverlay {
    static let shared = WorkshopOverlay()
    private var panel: WorkshopOverlayPanel?
    private var showAfterUnlock = false
    private var unlockObserver: NSObjectProtocol?

    var isVisible: Bool { panel?.isVisible == true && (panel?.alphaValue ?? 0) > 0.5 }

    /// The screen is locked: macOS lets no app draw over the lock screen. / Экран заблокирован: поверх него рисовать нельзя.
    static var screenIsLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? Bool) == true
    }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        if Self.screenIsLocked {
            // Shown right after unlock; until then the answer is spoken. / Покажется сразу после разблокировки.
            showAfterUnlock = true
            watchUnlock()
            return
        }
        let panel = self.panel ?? makePanel()
        guard !isVisible else { return }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        let full = screen?.frame ?? panel.frame
        // Grows from slightly smaller with a fade, like macOS opening a space. / Вырастает из чуть меньшего с проявлением.
        panel.setFrame(full.insetBy(dx: full.width * 0.035, dy: full.height * 0.035), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        Self.play("Purr", volume: 0.45)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.42
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(full, display: true)
        }
    }

    private static func play(_ name: String, volume: Float) {
        guard UserDefaults.standard.object(forKey: WorkshopWakeListener.soundKey) as? Bool ?? true else { return }
        let sound = NSSound(named: NSSound.Name(name)) ?? NSSound(named: NSSound.Name("Tink"))
        sound?.volume = volume
        sound?.play()
    }

    func hide() {
        guard let panel, panel.isVisible, panel.alphaValue > 0.5 else { return }
        let full = panel.frame
        Self.play("Bottle", volume: 0.3)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(full.insetBy(dx: full.width * 0.035, dy: full.height * 0.035), display: true)
        }, completionHandler: {
            Task { @MainActor in if panel.alphaValue < 0.05 { panel.orderOut(nil) } }
        })
    }

    private func makePanel() -> WorkshopOverlayPanel {
        let services = AppServices.shared
        let panel = WorkshopOverlayPanel(contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900),
                                         styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                                         backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.onCancel = { [weak self] in self?.hide() }
        panel.contentView = NSHostingView(rootView:
            WorkshopHUDView(model: services.workshop, onDismiss: { [weak self] in self?.hide() })
                .environmentObject(services.store)
                .environmentObject(services.backend)
                .environmentObject(services.workshop)
        )
        self.panel = panel
        return panel
    }

    private func watchUnlock() {
        guard unlockObserver == nil else { return }
        unlockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.showAfterUnlock else { return }
                self.showAfterUnlock = false
                self.show()
            }
        }
    }
}

/// «Мастерская в фоне» in Settings. / «Мастерская в фоне» в настройках.
struct WorkshopBackgroundSection: View {
    @EnvironmentObject private var store: LearningStore
    @AppStorage(WorkshopBackground.keepRunningKey) private var keepRunning = true
    @State private var loginItem = WorkshopBackground.loginItemEnabled
    @State private var needsApproval = WorkshopBackground.loginItemNeedsApproval

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        Section {
            Toggle(text("settings.background.keepRunning"), isOn: $keepRunning)
            Toggle(text("settings.background.login"), isOn: $loginItem)
                .onChange(of: loginItem) { on in
                    WorkshopBackground.setLoginItem(on)
                    loginItem = WorkshopBackground.loginItemEnabled
                    needsApproval = WorkshopBackground.loginItemNeedsApproval
                }
            if needsApproval {
                Button(text("settings.background.approve")) { SMAppService.openSystemSettingsLoginItems() }
            }
            Text(text("settings.background.help")).font(.caption).foregroundStyle(.secondary)
        } header: {
            Text(text("settings.background.title"))
        }
    }
}


/// A small glass badge at the top of the screen while the assistant listens, thinks or speaks with the overlay closed.
/// Маленький стеклянный значок сверху, пока ассистент слушает, думает или говорит при закрытом оверлее.
@MainActor
final class WorkshopVoiceBadge {
    static let shared = WorkshopVoiceBadge()
    private var panel: NSPanel?
    private let label = NSTextField(labelWithString: "")

    func show(_ text: String) {
        let panel = self.panel ?? make()
        label.stringValue = text
        if let screen = NSScreen.main {
            let size = NSSize(width: 220, height: 44)
            panel.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height - 12,
                                  width: size.width, height: size.height), display: true)
        }
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.25; panel.animator().alphaValue = 1 }
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; panel.animator().alphaValue = 0 },
                                             completionHandler: { Task { @MainActor in panel.orderOut(nil) } })
    }

    private func make() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 44), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        let glass = NSVisualEffectView(frame: panel.contentRect(forFrameRect: panel.frame))
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 22
        glass.layer?.masksToBounds = true
        glass.autoresizingMask = [.width, .height]
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(label)
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: glass.centerXAnchor),
                                     label.centerYAnchor.constraint(equalTo: glass.centerYAnchor)])
        panel.contentView = glass
        self.panel = panel
        return panel
    }
}
