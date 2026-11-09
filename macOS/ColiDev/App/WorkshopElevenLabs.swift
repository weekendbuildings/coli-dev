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

/// The voice of the answers: ElevenLabs first when a key is stored, the best installed macOS voice otherwise.
/// Голос ответов: ElevenLabs, если есть ключ, иначе лучший установленный голос macOS.
final class WorkshopSpeaker: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate, @unchecked Sendable {
    static let lastFailureKey = "workshop.voice.elevenlabs.lastFailure"

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var fetch: Task<Void, Never>?
    private var cooldownUntil = Date.distantPast
    var onSpeakingChanged: ((Bool) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    static func bestVoice(languagePrefix: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(languagePrefix) }
        return voices.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: languagePrefix == "ru" ? "ru-RU" : "en-US")
    }

    func speak(_ text: String, language: String) {
        stop()
        guard Date() >= cooldownUntil, let key = VoiceKeychain.read(),
              let request = ElevenLabsVoice.request(text: text, voiceID: UserDefaults.standard.string(forKey: ElevenLabsVoice.voiceDefaultsKey) ?? "",
                                                     key: key) else {
            speakWithMac(text, language: language)
            return
        }
        onSpeakingChanged?(true)
        fetch = Task { [weak self] in
            var audio = Data()
            var failure: ElevenLabsVoice.Failure?
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                audio = data
                failure = ElevenLabsVoice.failure(status: (response as? HTTPURLResponse)?.statusCode ?? 0, body: data)
            } catch {
                failure = .network
            }
            if Task.isCancelled { return }
            await MainActor.run { self?.fetched(audio, failure: failure, text: text, language: language) }
        }
    }

    private func fetched(_ audio: Data, failure: ElevenLabsVoice.Failure?, text: String, language: String) {
        fetch = nil
        if failure == nil, let player = try? AVAudioPlayer(data: audio) {
            player.delegate = self
            self.player = player
            if player.play() {
                UserDefaults.standard.removeObject(forKey: Self.lastFailureKey)
                return
            }
        }
        let reason = failure ?? .audio
        UserDefaults.standard.set(reason.rawValue, forKey: Self.lastFailureKey)
        if reason == .key || reason == .quota { cooldownUntil = Date().addingTimeInterval(ElevenLabsVoice.cooldown) }
        speakWithMac(text, language: language)
    }

    private func speakWithMac(_ text: String, language: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(languagePrefix: language)
        synthesizer.speak(utterance)
    }

    func stop() {
        let wasBusy = fetch != nil || player != nil
        fetch?.cancel()
        fetch = nil
        player?.stop()
        player = nil
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        if wasBusy { onSpeakingChanged?(false) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) { onSpeakingChanged?(true) }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { onSpeakingChanged?(false) }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { onSpeakingChanged?(false) }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        onSpeakingChanged?(false)
    }
}

// MARK: - Settings / настройки

/// "Answer voice" in Settings: the ElevenLabs key goes straight to the Keychain and is never shown.
/// «Голос ответа» в настройках: ключ ElevenLabs сразу уходит в Связку ключей и больше не показывается.
struct WorkshopVoiceSection: View {
    @EnvironmentObject private var store: LearningStore
    @AppStorage(ElevenLabsVoice.voiceDefaultsKey) private var voiceID = ""
    @AppStorage(WorkshopSpeaker.lastFailureKey) private var lastFailure = ""
    @State private var draft = ""
    @State private var hasKey = VoiceKeychain.exists
    @State private var saveFailed = false

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

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
            TextField(text("settings.voice.voiceID"), text: $voiceID, prompt: Text(ElevenLabsVoice.defaultVoiceID))
            if hasKey, !lastFailure.isEmpty {
                Text(text("settings.voice.failed.\(lastFailure)")).font(.caption).foregroundStyle(.orange)
            }
            Text(String(format: text("settings.voice.help"), String(ElevenLabsVoice.maxCharacters))).font(.caption).foregroundStyle(.secondary)
        } header: {
            Text(text("settings.voice.title"))
        }
    }
}
