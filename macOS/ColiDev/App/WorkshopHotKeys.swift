import AppKit
import Carbon.HIToolbox
import SwiftUI

// The workshop over other apps: global hot keys through Carbon RegisterEventHotKey (no Accessibility
// permission needed) and a floating panel that does not pull the main window forward.
// Мастерская поверх других программ: глобальные горячие клавиши через Carbon RegisterEventHotKey
// (разрешение на управление компьютером не нужно) и плавающая панель, которая не тянет за собой главное окно.

enum WorkshopHotKey: UInt32 {
    /// ⌃⌥T — show or hide the panel. / Показать или спрятать панель.
    case panel = 1
    /// ⌃⌥V — hold to talk, release to send. / Держи и говори, отпусти — вопрос уйдёт.
    case voice = 2

    var keyCode: UInt32 { self == .panel ? UInt32(kVK_ANSI_T) : UInt32(kVK_ANSI_V) }
    static let modifiers = UInt32(controlKey | optionKey)
    static let signature: OSType = 0x5456_5254 // "TVRT"
}

/// Connects the hot keys, the floating panel and the shared models. / Связывает горячие клавиши, панель и общие модели.
@MainActor
final class WorkshopHub {
    static let shared = WorkshopHub()

    private weak var store: LearningStore?
    private weak var model: WorkshopModel?
    private var panel: NSPanel?
    private var handler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []
    private(set) var registered: [WorkshopHotKey] = []

    func connect(store: LearningStore, model: WorkshopModel) {
        self.store = store
        self.model = model
        registerHotKeys()
    }

    private func registerHotKeys() {
        guard handler == nil else { return }
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let read = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                         MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard read == noErr, hotKeyID.signature == WorkshopHotKey.signature, let key = WorkshopHotKey(rawValue: hotKeyID.id) else {
                return OSStatus(eventNotHandledErr)
            }
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            DispatchQueue.main.async { WorkshopHub.shared.handle(key, pressed: pressed) }
            return noErr
        }, types.count, &types, nil, &handler)
        guard status == noErr else { return }
        for key in [WorkshopHotKey.panel, .voice] {
            var reference: EventHotKeyRef?
            let id = EventHotKeyID(signature: WorkshopHotKey.signature, id: key.rawValue)
            if RegisterEventHotKey(key.keyCode, WorkshopHotKey.modifiers, id, GetApplicationEventTarget(), 0, &reference) == noErr,
               let reference {
                hotKeys.append(reference)
                registered.append(key)
            }
        }
    }

    private func handle(_ key: WorkshopHotKey, pressed: Bool) {
        guard let store, let model else { return }
        switch key {
        case .panel:
            if pressed { togglePanel() }
        case .voice:
            if pressed {
                showPanel()
                model.tab = .chat
                model.startListening(language: store.language)
            } else {
                model.stopListeningAndAsk(store: store)
            }
        }
    }

    func togglePanel() {
        if let panel, panel.isVisible, panel.isKeyWindow {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let store, let model else { return }
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
                                styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
                                backing: .buffered, defer: false)
            panel.title = L10n.text("workshop.title", store.language)
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView:
                WorkshopView(model: model, compact: true)
                    .environmentObject(store)
                    .tint(AppPalette.accent.color)
                    .frame(minWidth: 380, minHeight: 420)
            )
            panel.center()
            self.panel = panel
        }
        panel?.makeKeyAndOrderFront(nil)
    }
}
