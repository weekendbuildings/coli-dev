import AVFoundation
import Foundation
import Security
import SwiftUI

// Spoken answers through ElevenLabs when the owner has put a key in Settings. The key lives only in the Keychain and is
// never shown again. No key, no network, a bad key or a spent quota → the macOS voice, at once. The request and the
// fallback rules are in WorkshopHUDCore (ElevenLabsVoice) and checked by scripts/verify_workshop_hud.swift.
// Ответ голосом ElevenLabs, если владелец вставил ключ в настройках. Ключ хранится только в Связке ключей и больше не
// показывается. Нет ключа, сети, ключ неверный или кончился лимит → сразу системный голос macOS.

enum VoiceKeychain {
    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: ElevenLabsVoice.keychainService,
         kSecAttrAccount as String: ElevenLabsVoice.keychainAccount]
    }

    static func read() -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        let key = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    /// Whether a key is stored, without reading it. / Есть ли ключ, не читая его.
    static var exists: Bool {
        var query = base
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
    }

    static func save(_ key: String) -> Bool {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(clean.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() { SecItemDelete(base as CFDictionary) }
}

/// The voice of the answers: ElevenLabs sentence by sentence when a key is stored (the next sentence is fetched while
/// the current one plays), the best installed macOS voice otherwise. If the network or the quota goes mid-answer, the
/// rest of the answer goes on in the macOS voice. Short phrases are cached on disk and cost no quota the second time.
/// Голос ответов: ElevenLabs по предложениям, если есть ключ (следующее загружается, пока звучит текущее), иначе лучший
/// установленный голос macOS. Если посреди ответа пропала сеть или кончился лимит, остаток звучит голосом macOS.
/// Короткие фразы хранятся на диске и второй раз не тратят лимит.
final class WorkshopSpeaker: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate, @unchecked Sendable {
    static let lastFailureKey = "workshop.voice.elevenlabs.lastFailure"

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var playing: CheckedContinuation<Bool, Never>?
    private var job: Task<Void, Never>?
    private var cooldownUntil = Date.distantPast
    private var macPending = 0
    var onSpeakingChanged: ((Bool) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// The offline voice: the best installed quality (Premium, then Enhanced), a male voice when qualities tie. Nothing is
    /// downloaded. / Голос без сети: лучшее установленное качество, при равенстве — мужской. Ничего не скачивается.
    static func bestVoice(languagePrefix: String) -> AVSpeechSynthesisVoice? {
        func score(_ voice: AVSpeechSynthesisVoice) -> Int { voice.quality.rawValue * 10 + (voice.gender == .male ? 1 : 0) }
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(languagePrefix) }
        return voices.max { score($0) < score($1) } ?? AVSpeechSynthesisVoice(language: languagePrefix == "ru" ? "ru-RU" : "en-US")
    }

    static var cacheFolder: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ColiDev/voice", isDirectory: true)
    }

    static func cached(_ text: String, voiceID: String) -> Data? {
        guard ElevenLabsVoice.isCacheable(text) else { return nil }
        return try? Data(contentsOf: cacheFolder.appendingPathComponent(ElevenLabsVoice.cacheName(text: text, voiceID: voiceID)))
    }

    private static func store(_ audio: Data, text: String, voiceID: String) {
        guard ElevenLabsVoice.isCacheable(text), !audio.isEmpty else { return }
        try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        try? audio.write(to: cacheFolder.appendingPathComponent(ElevenLabsVoice.cacheName(text: text, voiceID: voiceID)), options: .atomic)
    }

    func speak(_ text: String, language: String) {
        stop()
        let chunks = ElevenLabsVoice.sentences(text)
        guard !chunks.isEmpty else { return }
        let voiceID = UserDefaults.standard.string(forKey: ElevenLabsVoice.voiceDefaultsKey) ?? ""
        let key = Date() >= cooldownUntil ? VoiceKeychain.read() : nil
        // Cached phrases play even with no key or network. / Фразы из кэша звучат и без ключа и сети.
        guard key != nil || chunks.allSatisfy({ Self.cached($0, voiceID: voiceID) != nil }) else {
            speakWithMac(chunks.joined(separator: " "), language: language)
            return
        }
        onSpeakingChanged?(true)
        job = Task { @MainActor [weak self] in await self?.run(chunks, voiceID: voiceID, key: key, language: language) }
    }

    @MainActor private func run(_ chunks: [String], voiceID: String, key: String?, language: String) async {
        var next: Task<Result<Data, ElevenLabsVoice.Failure>, Never>? = fetch(chunks[0], voiceID: voiceID, key: key)
        for index in chunks.indices {
            guard let current = next, !Task.isCancelled else { return }
            // Fetch the next sentence while this one plays. / Следующее предложение грузится, пока звучит текущее.
            next = index + 1 < chunks.count ? fetch(chunks[index + 1], voiceID: voiceID, key: key) : nil
            let reason: ElevenLabsVoice.Failure
            switch await current.value {
            case .success(let audio):
                if await play(audio) { continue }
                if Task.isCancelled { next?.cancel(); return }
                reason = .audio
            case .failure(let failure):
                reason = failure
            }
            next?.cancel()
            if Task.isCancelled { return }
            note(reason)
            job = nil
            speakWithMac(chunks[index...].joined(separator: " "), language: language)
            return
        }
        UserDefaults.standard.removeObject(forKey: Self.lastFailureKey)
        job = nil
        onSpeakingChanged?(false)
    }

    private func fetch(_ text: String, voiceID: String, key: String?) -> Task<Result<Data, ElevenLabsVoice.Failure>, Never> {
        Task {
            if let audio = Self.cached(text, voiceID: voiceID) { return .success(audio) }
            guard let key, let request = ElevenLabsVoice.request(text: text, voiceID: voiceID, key: key) else { return .failure(.key) }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let failure = ElevenLabsVoice.failure(status: (response as? HTTPURLResponse)?.statusCode ?? 0, body: data) {
                    return .failure(failure)
                }
                Self.store(data, text: text, voiceID: voiceID)
                return .success(data)
            } catch {
                return .failure(.network)
            }
        }
    }

    @MainActor private func play(_ audio: Data) async -> Bool {
        guard !Task.isCancelled, let player = try? AVAudioPlayer(data: audio) else { return false }
        return await withCheckedContinuation { continuation in
            player.delegate = self
            self.player = player
            playing = continuation
            if !player.play() {
                playing = nil
                self.player = nil
                continuation.resume(returning: false)
            }
        }
    }

    private func note(_ reason: ElevenLabsVoice.Failure) {
        UserDefaults.standard.set(reason.rawValue, forKey: Self.lastFailureKey)
        if reason == .key || reason == .quota { cooldownUntil = Date().addingTimeInterval(ElevenLabsVoice.cooldown) }
    }

    /// Sentence by sentence, each in a voice of its own language. / По предложениям, каждое голосом своего языка.
    private func speakWithMac(_ text: String, language: String) {
        let sentences = ElevenLabsVoice.sentences(text)
        macPending += sentences.count
        for sentence in sentences {
            let utterance = AVSpeechUtterance(string: sentence)
            utterance.voice = Self.bestVoice(languagePrefix: ElevenLabsVoice.language(of: sentence) ?? language)
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        let busy = job != nil || player != nil
        job?.cancel()
        job = nil
        player?.stop()
        player = nil
        playing?.resume(returning: false)
        playing = nil
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        macPending = 0
        if busy { onSpeakingChanged?(false) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) { onSpeakingChanged?(true) }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { macFinished() }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { macFinished() }

    /// "Speaking" ends after the last sentence, not between sentences. / «Говорит» кончается после последнего предложения.
    private func macFinished() {
        macPending = max(0, macPending - 1)
        if macPending == 0 { onSpeakingChanged?(false) }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        playing?.resume(returning: flag)
        playing = nil
    }
}

// MARK: - Settings / настройки

/// "Answer voice" in Settings: the ElevenLabs key goes straight to the Keychain and is never shown; the voice is chosen
/// from the premade ones (or by ID) and can be heard with "Listen".
/// «Голос ответа»: ключ ElevenLabs сразу уходит в Связку ключей и не показывается; голос выбирается из готовых (или по ID)
/// и прослушивается кнопкой.
struct WorkshopVoiceSection: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var workshop: WorkshopModel
    @AppStorage(ElevenLabsVoice.voiceDefaultsKey) private var voiceID = ""
    @AppStorage(WorkshopSpeaker.lastFailureKey) private var lastFailure = ""
    @State private var draft = ""
    @State private var hasKey = VoiceKeychain.exists
    @State private var saveFailed = false
    @State private var custom = false

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private static let customTag = "custom"

    private var choice: Binding<String> {
        Binding(
            get: {
                if custom { return Self.customTag }
                let current = ElevenLabsVoice.voiceID(voiceID)
                return ElevenLabsVoice.voices.contains { $0.id == current } ? current : Self.customTag
            },
            set: { value in
                custom = value == Self.customTag
                if !custom { voiceID = value }
            }
        )
    }

    var body: some View {
        Section {
            Text(text(hasKey ? "settings.voice.keySaved" : "settings.voice.noKey")).font(.caption).foregroundStyle(.secondary)
            HStack {
                SecureField(text("settings.voice.keyField"), text: $draft)
                    .textContentType(.password)
                Button(text("settings.voice.save")) {
                    saveFailed = !VoiceKeychain.save(draft)
                    draft = ""
                    hasKey = VoiceKeychain.exists
                    if !saveFailed { lastFailure = "" }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if hasKey {
                    Button(text("settings.voice.delete"), role: .destructive) {
                        VoiceKeychain.delete()
                        hasKey = VoiceKeychain.exists
                    }
                }
            }
            if saveFailed { Text(text("settings.voice.saveFailed")).font(.caption).foregroundStyle(.orange) }
            HStack {
                Picker(text("settings.voice.voice"), selection: choice) {
                    ForEach(ElevenLabsVoice.voices) { Text("\($0.name) — \($0.note)").tag($0.id) }
                    Text(text("settings.voice.custom")).tag(Self.customTag)
                }
                Button(text("settings.voice.preview")) { workshop.voice.preview(language: store.language) }
            }
            if choice.wrappedValue == Self.customTag {
                TextField(text("settings.voice.voiceID"), text: $voiceID, prompt: Text(ElevenLabsVoice.defaultVoiceID))
            }
            if hasKey, !lastFailure.isEmpty {
                Text(text("settings.voice.failed.\(lastFailure)")).font(.caption).foregroundStyle(.orange)
            }
            Text(String(format: text("settings.voice.help"), String(ElevenLabsVoice.maxCharacters))).font(.caption).foregroundStyle(.secondary)
        } header: {
            Text(text("settings.voice.title"))
        }
    }
}
