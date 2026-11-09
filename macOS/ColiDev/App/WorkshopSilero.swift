import Foundation

// The offline voice: Silero (v5_6_ru for Russian, v3_en for English) as a small local service on 127.0.0.1, started by
// the app from the environment that SileroTTS/install.sh creates. Without that environment the macOS voice speaks.
// Голос без сети: Silero (v5_6_ru для русского, v3_en для английского) как маленькая локальная служба на 127.0.0.1;
// приложение запускает её из окружения, которое создаёт SileroTTS/install.sh. Без него говорит голос macOS.

final class SileroVoice: @unchecked Sendable {
    static let shared = SileroVoice()
    static let ruSpeakerKey = "workshop.voice.silero.ru"
    static let enSpeakerKey = "workshop.voice.silero.en"
    static let ruSpeakers = ["eugene", "aidar", "baya", "kseniya", "xenia"]
    static let enSpeakers = (0..<12).map { "en_\($0)" }

    static var root: URL {
        if let custom = ProcessInfo.processInfo.environment["COLIDEV_TTS_DIR"], !custom.isEmpty { return URL(fileURLWithPath: custom) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/ColiDev-tts", isDirectory: true)
    }
    static var python: URL { root.appendingPathComponent("venv/bin/python") }
    static var models: URL { root.appendingPathComponent("models", isDirectory: true) }

    static func hasModel(_ language: String) -> Bool {
        FileManager.default.fileExists(atPath: models.appendingPathComponent(language == "en" ? "v3_en.pt" : "v5_6_ru.pt").path)
    }

    static var installed: Bool { FileManager.default.isExecutableFile(atPath: python.path) && (hasModel("ru") || hasModel("en")) }

    static func speaker(_ language: String) -> String {
        let key = language == "en" ? enSpeakerKey : ruSpeakerKey
        return UserDefaults.standard.string(forKey: key) ?? (language == "en" ? enSpeakers[0] : ruSpeakers[0])
    }

    private let lock = NSLock()
    private var process: Process?
    private var port: Int?

    /// Starts the service once; the first start loads PyTorch (a few seconds). / Первый запуск загружает PyTorch.
    private func ensureStarted() async -> Int? {
        lock.lock()
        if let port, process?.isRunning == true { lock.unlock(); return port }
        lock.unlock()
        guard Self.installed, let server = Bundle.main.resourceURL?.appendingPathComponent("SileroTTS/server.py"),
              FileManager.default.fileExists(atPath: server.path) else { return nil }
        let portFile = FileManager.default.temporaryDirectory.appendingPathComponent("colidev-silero-\(ProcessInfo.processInfo.processIdentifier).port")
        try? FileManager.default.removeItem(at: portFile)
        let child = Process()
        child.executableURL = Self.python
        child.arguments = ["-I", server.path, "--models", Self.models.path, "--port-file", portFile.path,
                           "--parent-pid", String(ProcessInfo.processInfo.processIdentifier)]
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        do { try child.run() } catch { return nil }
        for _ in 0..<100 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if let text = try? String(contentsOf: portFile, encoding: .utf8), let found = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                lock.lock()
                process = child
                port = found
                lock.unlock()
                return found
            }
            if !child.isRunning { return nil }
        }
        child.terminate()
        return nil
    }

    /// WAV for one sentence, from the cache or the service; nil means use the macOS voice.
    /// WAV одного предложения из кэша или от службы; nil — говорит голос macOS.
    func audio(_ sentence: String, language: String) async -> Data? {
        let lang = language == "en" ? "en" : "ru"
        guard Self.hasModel(lang) else { return nil }
        let speaker = Self.speaker(lang)
        let name = ElevenLabsVoice.cacheName(text: sentence, voiceID: "silero-\(lang)-\(speaker)")
        let cached = WorkshopSpeaker.cacheFolder.appendingPathComponent(name)
        if ElevenLabsVoice.isCacheable(sentence), let data = try? Data(contentsOf: cached) { return data }
        guard let port = await ensureStarted(), let url = URL(string: "http://127.0.0.1:\(port)/tts"),
              let body = try? JSONSerialization.data(withJSONObject: ["text": sentence, "lang": lang, "speaker": speaker]) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 40)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count > 44 else { return nil }
        if ElevenLabsVoice.isCacheable(sentence) {
            try? FileManager.default.createDirectory(at: WorkshopSpeaker.cacheFolder, withIntermediateDirectories: true)
            try? data.write(to: cached, options: .atomic)
        }
        return data
    }

    func stop() {
        lock.lock()
        process?.terminate()
        process = nil
        port = nil
        lock.unlock()
    }
}
