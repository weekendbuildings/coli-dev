import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI


// Calling the workshop from anywhere: global hot keys through Carbon RegisterEventHotKey (no Accessibility
// permission needed), the wake word (WorkshopWake.swift) and a soft sound. The HUD comes up on the current desktop.
// Вызов Мастерской откуда угодно: глобальные горячие клавиши через Carbon RegisterEventHotKey (разрешение на
// управление компьютером не нужно), слово вызова (WorkshopWake.swift) и мягкий звук. HUD появляется на текущем столе.

enum WorkshopHotKey: UInt32 {
    /// Show the HUD; the key is chosen in Settings (⌃⌥T by default). / Показать HUD; клавиша выбирается в настройках.
    case summon = 1
    /// ⌃⌥V — hold to talk, release to send. / Держи и говори, отпусти — вопрос уйдёт.
    case voice = 2

    static let signature: OSType = 0x5456_5254 // "TVRT"
}

/// Connects the hot keys, the wake word and the shared models. / Связывает горячие клавиши, слово вызова и модели.
@MainActor
final class WorkshopHub {
    static let shared = WorkshopHub()

    let wake = WorkshopWakeListener()
    private weak var store: LearningStore?
    private weak var model: WorkshopModel?
    private var handler: EventHandlerRef?
    private var hotKeys: [WorkshopHotKey: EventHotKeyRef] = [:]
    private var subscriptions: Set<AnyCancellable> = []
    private var turn: (started: Date, lastChange: Date, transcript: String)?

    func connect(store: LearningStore, model: WorkshopModel) {
        guard self.store == nil else { return }
        self.store = store
        self.model = model
        installHandler()
        _ = register(.summon, HUDShortcut.find(UserDefaults.standard.string(forKey: HUDShortcut.defaultsKey)))
        _ = register(.voice, HUDShortcut.voice)
        // «Творец» / "Creator" addresses the assistant: the question is heard and answered by voice; the overlay stays
        // as it is (closed → only a small glass badge). / «Творец» — обращение к ассистенту; оверлей не открывается сам.
        wake.onWake = { [weak self] in self?.listenAfterWake() }
        wake.onCommand = { [weak self] command in self?.run(command) }
        Publishers.CombineLatest3(model.voice.$isListening, model.voice.$isSpeaking, model.$isAnswering)
            .sink { [weak self] listening, speaking, answering in
                DispatchQueue.main.async { self?.updateBadge(listening: listening, speaking: speaking, answering: answering) }
            }
            .store(in: &subscriptions)
        // Listening pauses while the owner talks or the assistant speaks. / Пауза, пока владелец говорит или ассистент отвечает.
        Publishers.CombineLatest(model.voice.$isListening, model.voice.$isSpeaking)
            .map { $0 || $1 }
            .removeDuplicates()
            .sink { [weak self] _ in Task { await self?.refreshWake() } }
            .store(in: &subscriptions)
        store.$language.removeDuplicates().sink { [weak self] _ in Task { await self?.refreshWake() } }.store(in: &subscriptions)
    }

    func refreshWake(askPermissions: Bool = false) async {
        guard let store, let model else { return }
        // A turn after the wake word still runs: keep the microphone for it. / Вопрос после слова ещё идёт.
        await wake.refresh(language: store.language, paused: model.voice.isListening || model.voice.isSpeaking || turn != nil,
                           askPermissions: askPermissions)
    }

    private func installHandler() {
        guard handler == nil else { return }
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
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
    }

    private func register(_ key: WorkshopHotKey, _ shortcut: HUDShortcut) -> Bool {
        if let old = hotKeys.removeValue(forKey: key) { UnregisterEventHotKey(old) }
        var reference: EventHotKeyRef?
        let id = EventHotKeyID(signature: WorkshopHotKey.signature, id: key.rawValue)
        guard RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &reference) == noErr,
              let reference else { return false }
        hotKeys[key] = reference
        return true
    }

    /// False when another app holds the key; the old one is put back. / false, если клавиша занята; старая возвращается.
    func setSummonShortcut(_ shortcut: HUDShortcut) -> Bool {
        let previous = HUDShortcut.find(UserDefaults.standard.string(forKey: HUDShortcut.defaultsKey))
        if register(.summon, shortcut) {
            UserDefaults.standard.set(shortcut.id, forKey: HUDShortcut.defaultsKey)
            return true
        }
        _ = register(.summon, previous)
        return false
    }

    private func handle(_ key: WorkshopHotKey, pressed: Bool) {
        guard let store, let model else { return }
        switch key {
        case .summon:
            guard pressed else { return }
            if WorkshopOverlay.shared.isVisible { WorkshopOverlay.shared.hide() } else { summon() }
        case .voice:
            if pressed {
                summon()
                model.startListening(language: store.language)
            } else {
                model.stopListeningAndAsk(store: store)
            }
        }
    }

    // MARK: Summon / вызов

    /// The app window, not the menu-bar panel. / Окно приложения, а не панель строки меню.
    static var mainWindow: NSWindow? {
        NSApp.windows.first { !($0 is NSPanel) && $0.canBecomeMain && $0.contentView != nil }
    }

    /// The workshop overlay on the current desktop, over every app, with a soft sound. / Оверлей поверх всех программ.
    func summon() {
        // The overlay over everything; the window inside the app stays as it is. / Оверлей поверх всего; окно приложения не трогаем.
        WorkshopOverlay.shared.show()
    }

    /// Runs a voice command; nothing is sent to the model. / Выполняет голосовую команду; модели ничего не уходит.
    func run(_ command: HUDVoiceCommand) {
        switch command {
        case .openWorkshop: WorkshopOverlay.shared.show()
        case .closeWorkshop: WorkshopOverlay.shared.hide()
        case .openPath:
            // Saying it again while the app is in front closes it. / Повтор, когда приложение впереди, закрывает его.
            if NSApp.isActive, let window = Self.mainWindow, window.isVisible, window.isKeyWindow { closePath() } else { openPath() }
        case .closePath: closePath()
        }
    }

    private func openPath() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = Self.mainWindow {
            window.collectionBehavior.insert(.moveToActiveSpace)
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            NSWorkspace.shared.open(Bundle.main.bundleURL)
        }
    }

    /// The app window goes away; the listener and the overlay keep working. / Окно уходит, слушание и оверлей остаются.
    private func closePath() {
        Self.mainWindow?.orderOut(nil)
        if !WorkshopOverlay.shared.isVisible { NSApp.setActivationPolicy(.accessory) }
    }

    /// With the overlay closed a voice turn shows only a small glass badge. / При закрытом оверлее — только маленький значок.
    private func updateBadge(listening: Bool, speaking: Bool, answering: Bool) {
        guard !WorkshopOverlay.shared.isVisible, turn != nil || listening || speaking || answering else {
            WorkshopVoiceBadge.shared.hide()
            return
        }
        guard let store else { return }
        let key = speaking ? "hud.state.speak" : (answering ? "hud.state.think" : "hud.state.listen")
        WorkshopVoiceBadge.shared.show(L10n.text(key, store.language))
    }

    /// After the wake word the question is heard until a pause, then sent. / После слова вызова вопрос слушается до паузы.
    private func listenAfterWake() {
        guard let store, let model, turn == nil, !model.voice.isListening else { return }
        let now = Date()
        turn = (now, now, "")
        wake.stop()
        model.startListening(language: store.language)
        followTurn()
    }

    private func followTurn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, let store = self.store, let model = self.model, var current = self.turn else { return }
            let now = Date()
            if model.voice.transcript != current.transcript {
                current.transcript = model.voice.transcript
                current.lastChange = now
                self.turn = current
            }
            if let command = HUDVoiceCommand.parse(current.transcript) {
                // A command, not a question. / Команда, а не вопрос.
                self.turn = nil
                Task { _ = await model.voice.stop(); await self.refreshWake() }
                self.run(command)
                return
            }
            switch HUDVoiceTurn.ending(transcript: current.transcript, started: current.started, lastChange: current.lastChange, now: now) {
            case .ask?:
                self.turn = nil
                model.stopListeningAndAsk(store: store)
            case .cancel?:
                self.turn = nil
                Task { _ = await model.voice.stop(); await self.refreshWake() }
            case nil:
                self.followTurn()
            }
        }
    }
}
