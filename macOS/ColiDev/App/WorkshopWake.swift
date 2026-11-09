import AppKit
import AVFoundation
import Speech
import SwiftUI

// Calling the workshop by voice: the Mac listens for "Creator" («Креатор», «Творец») with Apple's on-device
// recognizer only (requiresOnDeviceRecognition), no cloud and no keys. Listening pauses while the owner asks a
// question or the assistant speaks. The words are matched in WorkshopHUDCore (HUDWakeWord).
// Вызов Мастерской голосом: Mac слушает слово «Creator» («Креатор», «Творец») только распознавателем Apple на
// устройстве, без облака и ключей. Пока владелец задаёт вопрос или ассистент говорит, слушание на паузе.

extension Notification.Name {
    /// The main window shows the workshop HUD. / Главное окно показывает HUD Мастерской.
    static let workshopSummon = Notification.Name("colidev.workshop.summon")
}

@MainActor
final class WorkshopWakeListener: ObservableObject {
    static let enabledKey = "workshop.wake.enabled"
    static let soundKey = "workshop.summon.sound"

    enum Status: Equatable { case off, listening, needsPermission, unavailable }

    @Published private(set) var status: Status = .off
    var onWake: () -> Void = {}

    private let engine = AVAudioEngine()
    private let feed = RequestFeed()
    private var task: SFSpeechRecognitionTask?
    private var counted = 0
    private var cycle = 0
    private var failures = 0
    private var lastWake = Date.distantPast
    private var language: AppLanguage = .ru
    private var paused = false

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    static var permissionsGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized && SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// Starts or stops as settings, permissions and pauses say. The system permission windows open only when
    /// the owner turns listening on in Settings (`askPermissions`), never by themselves.
    /// Включает или выключает слушание по настройкам, разрешениям и паузам. Окна разрешений macOS открываются
    /// только когда владелец включает слушание в настройках, а не сами.
    func refresh(language: AppLanguage, paused: Bool, askPermissions: Bool = false) async {
        if language != self.language { stop() }
        self.language = language
        self.paused = paused
        guard Self.isEnabled else { stop(); status = .off; return }
        if askPermissions { await Self.requestPermissions() }
        guard Self.permissionsGranted else { stop(); status = .needsPermission; return }
        if paused { stop(); return }
        if task == nil { start() }
    }

    static func requestPermissions() async {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined { _ = await AVCaptureDevice.requestAccess(for: .audio) }
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                SFSpeechRecognizer.requestAuthorization { _ in done.resume() }
            }
        }
    }

    private func start() {
        guard let recognizer = SFSpeechRecognizer(locale: WorkshopVoice.locale(language)), recognizer.supportsOnDeviceRecognition else {
            status = .unavailable
            return
        }
        if !engine.isRunning {
            let input = engine.inputNode
            input.removeTap(onBus: 0)
            let feed = self.feed
            input.installTap(onBus: 0, bufferSize: 2048, format: input.outputFormat(forBus: 0)) { buffer, _ in feed.append(buffer) }
            engine.prepare()
            do { try engine.start() } catch { status = .unavailable; return }
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = HUDWakeWord.hints
        feed.set(request)
        counted = 0
        cycle += 1
        let current = cycle
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString ?? ""
            let done = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in self?.heard(text, done: done, failed: error != nil, cycle: current) }
        }
        status = .listening
        // A fresh task every 50 s keeps the transcript short. / Новая задача каждые 50 с, чтобы текст не рос.
        DispatchQueue.main.asyncAfter(deadline: .now() + 50) { [weak self] in
            guard let self, self.cycle == current, self.task != nil else { return }
            self.restart(after: 0)
        }
    }

    private func heard(_ text: String, done: Bool, failed: Bool, cycle current: Int) {
        guard current == cycle else { return }
        let total = HUDWakeWord.count(in: text)
        if total > counted {
            counted = total
            failures = 0
            if Date().timeIntervalSince(lastWake) > 3 {
                lastWake = Date()
                onWake()
            }
        }
        if done {
            failures = failed ? failures + 1 : 0
            // Silence ends a task with an error; back off if it keeps failing. / При частых ошибках — пауза.
            restart(after: failures > 5 ? 10 : 0.3)
        }
    }

    private func restart(after delay: TimeInterval) {
        feed.set(nil)
        task?.cancel()
        task = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.paused, Self.isEnabled, Self.permissionsGranted, self.task == nil else { return }
            self.start()
        }
    }

    func stop() {
        cycle += 1
        feed.set(nil)
        task?.cancel()
        task = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        if status == .listening { status = .off }
    }
}

/// The audio tap runs off the main thread; it feeds whichever request is current. / Буфер звука идёт в текущий запрос.
private final class RequestFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ next: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        request?.endAudio()
        request = next
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        request?.append(buffer)
        lock.unlock()
    }
}

// MARK: - Settings / настройки

/// "Workshop: calling" in Settings: the wake word, the hot key, the sound and where to give permissions.
/// «Мастерская: вызов» в настройках: слово, горячая клавиша, звук и где дать разрешения.
struct WorkshopSummonSection: View {
    @EnvironmentObject private var store: LearningStore
    @ObservedObject private var wake = WorkshopHub.shared.wake
    @AppStorage(WorkshopWakeListener.enabledKey) private var wakeEnabled = true
    @AppStorage(WorkshopWakeListener.soundKey) private var sound = true
    @AppStorage(HUDShortcut.defaultsKey) private var shortcutID = HUDShortcut.all[0].id
    @State private var shortcutTaken = false

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        Section {
            Toggle(isOn: $wakeEnabled) { Text(text("settings.workshop.wake")) }
                .onChange(of: wakeEnabled) { _ in
                    Task { await WorkshopHub.shared.refreshWake(askPermissions: true) }
                }
            Text(statusText).font(.caption).foregroundStyle(wake.status == .listening ? Color.secondary : Color.orange)
            if wakeEnabled && wake.status == .needsPermission {
                HStack {
                    Button(text("settings.workshop.openMicrophone")) { openPrivacy("Privacy_Microphone") }
                    Button(text("settings.workshop.openSpeech")) { openPrivacy("Privacy_SpeechRecognition") }
                }
            }
            Picker(text("settings.workshop.shortcut"), selection: $shortcutID) {
                ForEach(HUDShortcut.all) { Text($0.title).tag($0.id) }
            }
            .onChange(of: shortcutID) { id in
                shortcutTaken = !WorkshopHub.shared.setSummonShortcut(HUDShortcut.find(id))
            }
            if shortcutTaken {
                Text(text("settings.workshop.shortcutTaken")).font(.caption).foregroundStyle(.orange)
            }
            Toggle(isOn: $sound) { Text(text("settings.workshop.sound")) }
            Text(String(format: text("settings.workshop.help"), HUDShortcut.voice.title)).font(.caption).foregroundStyle(.secondary)
        } header: {
            Text(text("settings.workshop.title"))
        }
    }

    private var statusText: String {
        guard wakeEnabled else { return text("settings.workshop.wakeOff") }
        switch wake.status {
        case .listening: return text("settings.workshop.wakeOn")
        case .needsPermission: return text("settings.workshop.needsPermission")
        case .unavailable: return text("settings.workshop.unavailable")
        case .off: return text("settings.workshop.wakePaused")
        }
    }

    private func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
}
