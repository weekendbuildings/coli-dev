import AVFoundation
import Foundation
import Speech

// Voice of the workshop: on-device speech recognition and spoken answers. Audio never leaves the Mac:
// SpeechAnalyzer on macOS 26+, otherwise SFSpeechRecognizer with requiresOnDeviceRecognition; no Whisper,
// no server recognition. The route itself (`VoiceRoute`) is checked in scripts/verify_workshop.swift.
// Голос Мастерской: распознавание речи на устройстве и ответ голосом. Звук не уходит с Mac:
// SpeechAnalyzer на macOS 26+, иначе SFSpeechRecognizer только на устройстве; без Whisper и сервера.

@MainActor
final class WorkshopVoice: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var route: VoiceRoute?
    @Published private(set) var analyzerNeedsDownload = false
    @Published private(set) var isDownloading = false
    @Published private(set) var isSpeaking = false
    @Published var errorText: String?

    private let engine = AVAudioEngine()
    private var sfRequest: SFSpeechAudioBufferRecognitionRequest?
    private var sfTask: SFSpeechRecognitionTask?
    private var sfFinal: CheckedContinuation<Void, Never>?
    private var analyzerSession: AnyObject?
    private var isStarting = false
    private var releasedWhileStarting = false
    private let speaker = WorkshopSpeaker()

    init() {
        speaker.onSpeakingChanged = { [weak self] speaking in
            Task { @MainActor in self?.isSpeaking = speaking }
        }
    }

    static func locale(_ language: AppLanguage) -> Locale {
        Locale(identifier: language == .ru ? "ru-RU" : "en-US")
    }

    // MARK: Route / маршрут

    /// Looks at the microphone, permissions and on-device models. / Смотрит микрофон, разрешения и модели на устройстве.
    func environment(language: AppLanguage) async -> VoiceEnvironment {
        let locale = Self.locale(language)
        let microphone: VoicePermission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: microphone = .granted
        case .denied, .restricted: microphone = .denied
        default: microphone = .undetermined
        }
        let speech: VoicePermission
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: speech = .granted
        case .denied, .restricted: speech = .denied
        default: speech = .undetermined
        }
        var analyzerReady = false
        var analyzerNeedsDownload = false
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            let state = await AnalyzerSession.state(for: locale)
            analyzerReady = state == .ready
            analyzerNeedsDownload = state == .needsDownload
        }
        #endif
        let onDevice = SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition ?? false
        return VoiceEnvironment(hasMicrophone: AVCaptureDevice.default(for: .audio) != nil, microphone: microphone,
                                speech: speech, analyzerReady: analyzerReady, analyzerNeedsDownload: analyzerNeedsDownload,
                                onDeviceRecognizer: onDevice)
    }

    func refreshRoute(language: AppLanguage) async {
        let environment = await environment(language: language)
        route = VoiceRoute.decide(environment)
        analyzerNeedsDownload = environment.analyzerNeedsDownload && route != .speechAnalyzer
    }

    /// Asks macOS for the microphone and speech recognition; the owner presses "Allow" in the system window.
    /// Просит у macOS микрофон и распознавание речи; владелец нажимает «Разрешить» в окне системы.
    private func requestPermissions() async {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
            }
        }
    }

    /// Downloads Apple's on-device speech model after the owner clicks the button.
    /// Скачивает модель распознавания Apple на устройство, когда владелец нажал кнопку.
    func downloadAnalyzerModel(language: AppLanguage) async {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            isDownloading = true
            defer { isDownloading = false }
            do {
                try await AnalyzerSession.download(locale: Self.locale(language))
            } catch {
                errorText = error.localizedDescription
            }
            await refreshRoute(language: language)
        }
        #endif
    }

    // MARK: Listening / слушаем

    func start(language: AppLanguage) async {
        // Repeated press events and a release during the permission window must not start a second
        // or an endless recording. / Повторные нажатия и отпускание во время окна разрешения не должны
        // запускать вторую или бесконечную запись.
        guard !isListening, !isStarting else { return }
        isStarting = true
        releasedWhileStarting = false
        defer { isStarting = false }
        stopSpeaking()
        errorText = nil
        transcript = ""
        await requestPermissions()
        await refreshRoute(language: language)
        guard let route else { return }
        do {
            switch route {
            case .unavailable:
                return
            case .speechAnalyzer:
                #if compiler(>=6.2)
                if #available(macOS 26, *) {
                    let session = AnalyzerSession()
                    try await session.start(locale: Self.locale(language), engine: engine) { [weak self] text in
                        self?.transcript = text
                    }
                    analyzerSession = session
                }
                #endif
            case .onDeviceRecognizer:
                try startRecognizer(locale: Self.locale(language))
            }
            isListening = true
            if releasedWhileStarting {
                _ = await stop()
                transcript = ""
            }
        } catch {
            stopEngine()
            errorText = error.localizedDescription
        }
    }

    /// Stops listening and returns what was heard. / Останавливает запись и возвращает услышанное.
    func stop() async -> String {
        guard isListening else {
            if isStarting { releasedWhileStarting = true }
            return ""
        }
        isListening = false
        #if compiler(>=6.2)
        if #available(macOS 26, *), let session = analyzerSession as? AnalyzerSession {
            stopEngine()
            transcript = await session.finish()
            analyzerSession = nil
            return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        stopEngine()
        sfRequest?.endAudio()
        // Wait up to 2 s for the final result. / Ждём итог не дольше 2 с.
        if sfTask != nil {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                sfFinal = continuation
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.resumeFinal() }
            }
        }
        sfTask?.cancel()
        sfTask = nil
        sfRequest = nil
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resumeFinal() {
        sfFinal?.resume()
        sfFinal = nil
    }

    private func startRecognizer(locale: Locale) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition else {
            throw NSError(domain: "WorkshopVoice", code: 1)
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        sfRequest = request
        sfTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = text }
                if isFinal || error != nil { self.resumeFinal() }
            }
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()
    }

    private func stopEngine() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
    }

    // MARK: Speaking / говорим

    func speak(_ markdown: String, language: AppLanguage) {
        let text = SpokenText.from(markdown: markdown, codeWord: L10n.text("workshop.voice.codeOnScreen", language))
        guard !text.isEmpty else { return }
        speaker.speak(text, language: language == .ru ? "ru" : "en")
    }

    func stopSpeaking() { speaker.stop() }
}

/// AVSpeechSynthesizer with the best installed voice for the language. / Лучший установленный голос для языка.
final class WorkshopSpeaker: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
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
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(languagePrefix: language)
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) { onSpeakingChanged?(true) }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { onSpeakingChanged?(false) }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { onSpeakingChanged?(false) }
}

#if compiler(>=6.2)
/// macOS 26+ SpeechAnalyzer with SpeechTranscriber: microphone buffers are converted to the analyzer's format.
/// SpeechAnalyzer на macOS 26+: звук микрофона переводится в формат анализатора.
@available(macOS 26, *)
final class AnalyzerSession {
    enum State { case ready, needsDownload, unsupported }

    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var results: Task<Void, Never>?
    private let lock = NSLock()
    private var finalText = ""
    private var volatileText = ""

    private static func transcriber(_ locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
    }

    static func state(for wanted: Locale) async -> State {
        guard SpeechTranscriber.isAvailable, let locale = await SpeechTranscriber.supportedLocale(equivalentTo: wanted) else {
            return .unsupported
        }
        switch await AssetInventory.status(forModules: [transcriber(locale)]) {
        case .installed: return .ready
        case .supported, .downloading: return .needsDownload
        default: return .unsupported
        }
    }

    static func download(locale wanted: Locale) async throws {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: wanted) else { return }
        try await AssetInventory.assetInstallationRequest(supporting: [transcriber(locale)])?.downloadAndInstall()
    }

    func start(locale wanted: Locale, engine: AVAudioEngine, onText: @escaping @MainActor (String) -> Void) async throws {
        let locale = await SpeechTranscriber.supportedLocale(equivalentTo: wanted) ?? wanted
        let transcriber = Self.transcriber(locale)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw NSError(domain: "WorkshopVoice", code: 2)
        }
        try await analyzer.prepareToAnalyze(in: format)
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.analyzer = analyzer
        self.input = continuation
        results = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }
                    let text = String(result.text.characters)
                    self.lock.lock()
                    if result.isFinal { self.finalText += text; self.volatileText = "" } else { self.volatileText = text }
                    let shown = self.finalText + self.volatileText
                    self.lock.unlock()
                    await onText(shown)
                }
            } catch {}
        }
        try await analyzer.start(inputSequence: stream)
        let node = engine.inputNode
        let inputFormat = node.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: format) else { throw NSError(domain: "WorkshopVoice", code: 3) }
        node.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            if let converted = Self.convert(buffer, with: converter, to: format) {
                continuation.yield(AnalyzerInput(buffer: converted))
            }
        }
        engine.prepare()
        try engine.start()
    }

    /// Ends the input, waits for the last words and returns the whole text. / Завершает ввод и возвращает весь текст.
    func finish() async -> String {
        input?.finish()
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await results?.value
        lock.lock(); defer { lock.unlock() }
        return finalText + volatileText
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var fed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            if fed { state.pointee = .noDataNow; return nil }
            fed = true
            state.pointee = .haveData
            return buffer
        }
        return status == .error || output.frameLength == 0 ? nil : output
    }
}
#endif
