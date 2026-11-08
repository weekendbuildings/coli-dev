import AppKit
import SwiftUI

// The "Explain / Check my code" panel in every lesson and Skillbox topic, plus the model order in settings.
// Панель «Объясни / Проверь мой код» в каждом уроке и теме Skillbox и порядок моделей в настройках.

extension OrchestratorClient {
    static func streamAssistant(_ body: AssistantAskBody, onEvent: @MainActor (AssistantStreamEvent) -> Void) async throws {
        guard let url = URL(string: LearningStore.orchestratorBaseURL + "/assistant/ask/stream") else {
            throw ClientError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.unavailable
        }
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if let event = AssistantStreamEvent.parse(line: line) { onEvent(event) }
        }
    }

    static func assistantModels(check: Bool) async throws -> AssistantModelsPayload {
        guard let url = URL(string: LearningStore.orchestratorBaseURL + "/settings/assistant-models" + (check ? "?check=true" : "")) else {
            throw ClientError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = check ? 40 : 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.unavailable
        }
        return try JSONDecoder().decode(AssistantModelsPayload.self, from: data)
    }

    static func saveAssistantModels(order: [String], disabled: [String]) async throws -> AssistantModelsPayload {
        guard let url = URL(string: LearningStore.orchestratorBaseURL + "/settings/assistant-models") else {
            throw ClientError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["order": order, "disabled": disabled])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.unavailable
        }
        return try JSONDecoder().decode(AssistantModelsPayload.self, from: data)
    }
}

/// What opens the panel: the context, the prompt for "Explain" and whether to start explaining at once.
/// Что открывает панель: контекст, подсказка для «Объясни» и начинать ли объяснение сразу.
struct LessonAssistantRequest: Identifiable {
    let id = UUID()
    let context: AssistantLessonContext
    let explainPrompt: String
    var startExplaining = false
}

struct LessonAssistantView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    let request: LessonAssistantRequest

    @State private var conversation = AssistantConversation()
    @State private var current = AssistantAnswerState()
    @State private var pending: (shown: String, sent: String, code: String?)?
    @State private var question = ""
    @State private var code = ""
    @State private var showingCode = false
    @State private var task: Task<Void, Never>?
    @State private var isSavingNote = false
    @State private var noteStatus: String?

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private var isAnswering: Bool { task != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if conversation.isEmpty && pending == nil {
                            Text(text(request.context.isSkillbox ? "assistant.intro.skillbox" : "assistant.intro"))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(conversation.exchanges) { exchange in
                            exchangeView(exchange)
                        }
                        if let pending {
                            questionBubble(pending.shown, code: pending.code)
                            liveAnswer
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(18)
                }
                .onChange(of: current.text) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
            Divider()
            composer
        }
        .frame(minWidth: 680, minHeight: 560)
        .onAppear {
            if request.startExplaining && conversation.isEmpty && !isAnswering { explain() }
        }
        .onDisappear { task?.cancel() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(text("assistant.title")).font(.title3.weight(.semibold))
                Text(request.context.title).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Button(text("assistant.saveObsidian")) { saveToObsidian() }
                .disabled(conversation.isEmpty || isSavingNote)
                .help(text("assistant.saveObsidian.help"))
                .accessibilityIdentifier("assistant.saveObsidian")
            Button(text("assistant.close")) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
        .overlay(alignment: .bottomLeading) {
            if let noteStatus {
                Text(noteStatus).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 2)
            }
        }
    }

    private func questionBubble(_ shown: String, code: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(shown).font(.callout.weight(.medium))
            if let code, !code.isEmpty {
                codeBlock(code)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private func exchangeView(_ exchange: AssistantExchange) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            questionBubble(exchange.shownQuestion, code: exchange.code)
            markdown(exchange.answer)
            answeredByLine(label: exchange.answeredBy, model: exchange.model, skipped: exchange.skipped)
        }
    }

    @ViewBuilder
    private var liveAnswer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !current.skipped.isEmpty && current.answeredBy == nil {
                skippedLine(current.skipped)
            }
            if let trying = current.trying {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(String(format: text("assistant.trying"), trying)).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("assistant.trying")
            }
            if !current.text.isEmpty {
                markdown(current.text)
            }
            if let error = current.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("assistant.error")
            }
        }
    }

    private func answeredByLine(label: String, model: String, skipped: [AssistantSkip]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(String(format: text("assistant.answeredBy"), label, model), systemImage: "checkmark.seal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("assistant.answeredBy")
            if !skipped.isEmpty { skippedLine(skipped) }
        }
    }

    private func skippedLine(_ skipped: [AssistantSkip]) -> some View {
        Text(text("assistant.skipped") + " " + skipped.map { "\($0.label) — \(text(AssistantReason.key($0.reason)))" }.joined(separator: "; "))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func markdown(_ source: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(LessonMarkdown.segments(source).enumerated()), id: \.offset) { _, block in
                switch block {
                case .prose(let prose):
                    Text(LessonMarkdown.attributed(prose))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                case .code(let code):
                    codeBlock(code)
                }
            }
        }
    }

    private func codeBlock(_ code: String) -> some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
        }
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button { explain() } label: { Label(text("assistant.explain"), systemImage: "lightbulb") }
                    .disabled(isAnswering)
                    .accessibilityIdentifier("assistant.explain")
                Button { showingCode.toggle() } label: {
                    Label(text("assistant.checkCode"), systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .disabled(isAnswering)
                .accessibilityIdentifier("assistant.checkCode")
                Spacer()
                if isAnswering {
                    Button(role: .cancel) { task?.cancel() } label: { Label(text("assistant.stop"), systemImage: "stop.circle") }
                }
            }
            if showingCode {
                VStack(alignment: .leading, spacing: 6) {
                    Text(text("assistant.codeHint")).font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $code)
                        .font(.system(.callout, design: .monospaced))
                        .frame(minHeight: 120, maxHeight: 200)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                        .accessibilityIdentifier("assistant.code")
                    Button(text("assistant.checkCode.send")) { checkCode() }
                        .disabled(isAnswering || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("assistant.checkCode.send")
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(text(conversation.isEmpty ? "assistant.placeholder" : "assistant.followUp"), text: $question, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(sendQuestion)
                    .accessibilityIdentifier("assistant.question")
                Button(text("assistant.send"), action: sendQuestion)
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnswering || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            Text(text("assistant.privacy")).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func explain() {
        ask(shown: text("assistant.explain"), sent: request.explainPrompt, code: nil)
    }

    private func checkCode() {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ask(shown: text("assistant.checkCode"), sent: text("assistant.checkCode.prompt"), code: trimmed)
    }

    private func sendQuestion() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAnswering else { return }
        question = ""
        ask(shown: trimmed, sent: trimmed, code: nil)
    }

    private func ask(shown: String, sent: String, code: String?) {
        guard !isAnswering else { return }
        current = AssistantAnswerState()
        pending = (shown, sent, code)
        let body = AssistantAskBody(language: store.language.rawValue, context: request.context, question: sent,
                                    code: code, history: conversation.history)
        task = Task { @MainActor in
            defer { task = nil }
            do {
                try await OrchestratorClient.streamAssistant(body) { current.apply($0) }
                if !current.finished { current.error = text("assistant.error.incomplete") }
            } catch is CancellationError {
                current.error = text("assistant.stopped")
            } catch {
                current.error = Task.isCancelled ? text("assistant.stopped") : text("assistant.error.backend")
            }
            if let answeredBy = current.answeredBy, !current.text.isEmpty {
                conversation.record(AssistantExchange(shownQuestion: shown, sentQuestion: sent, code: code, answer: current.text,
                                                      answeredBy: answeredBy, model: current.model ?? "",
                                                      skipped: current.skipped))
                pending = nil
                current = AssistantAnswerState()
                if code != nil { showingCode = false }
            }
        }
    }

    private func saveToObsidian() {
        guard !conversation.isEmpty, !isSavingNote else { return }
        let now = Date()
        let path = AssistantObsidianNote.path(context: request.context, date: now)
        let note = AssistantObsidianNote.markdown(context: request.context, exchanges: conversation.exchanges, date: now,
                                                  answeredByLabel: text("assistant.note.answeredBy"),
                                                  questionLabel: text("assistant.note.question"),
                                                  codeLabel: text("assistant.note.code"))
        isSavingNote = true
        noteStatus = nil
        Task { @MainActor in
            defer { isSavingNote = false }
            do {
                try await OrchestratorClient.saveObsidianNote(path: path, content: note)
                noteStatus = String(format: text("module.obsidianSaved"), path)
            } catch {
                noteStatus = text("module.obsidianSaveFailed")
            }
        }
    }
}

/// Settings: order of assistant models and whether each one has a key and answers. Key values are never shown.
/// Настройки: порядок моделей ассистента, есть ли ключ и отвечает ли. Значения ключей не показываются.
struct AssistantModelsSettingsView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var payload: AssistantModelsPayload?
    @State private var isChecking = false
    @State private var failed = false

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        GroupBox(label: Text(text("assistant.settings.title"))) {
            VStack(alignment: .leading, spacing: 10) {
                Text(text("assistant.settings.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let payload {
                    ForEach(Array(payload.providers.enumerated()), id: \.element.id) { index, row in
                        rowView(row, index: index, count: payload.providers.count)
                    }
                } else if failed {
                    Text(text("management.serviceUnavailable")).font(.caption).foregroundStyle(.orange)
                } else {
                    ProgressView().controlSize(.small)
                }
                HStack {
                    Button(text("assistant.settings.check")) { Task { await load(check: true) } }
                        .disabled(isChecking)
                        .accessibilityIdentifier("assistant.settings.check")
                    if isChecking { ProgressView().controlSize(.small) }
                }
            }
            .padding(.top, 6)
        }
        .task { await load(check: false) }
    }

    private func rowView(_ row: AssistantModelRow, index: Int, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(index + 1).").monospacedDigit().foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(row.label) · \(row.model)").font(.callout.weight(.medium))
                Text(statusText(row)).font(.caption).foregroundStyle(statusColor(row))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button { Task { await save(order: AssistantModelOrder.move(row.id, by: -1, in: payload?.order ?? []), disabled: payload?.disabled ?? []) } } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(index == 0)
            .accessibilityLabel(text("assistant.settings.up"))
            Button { Task { await save(order: AssistantModelOrder.move(row.id, by: 1, in: payload?.order ?? []), disabled: payload?.disabled ?? []) } } label: {
                Image(systemName: "arrow.down")
            }
            .disabled(index == count - 1)
            .accessibilityLabel(text("assistant.settings.down"))
            Toggle("", isOn: Binding(
                get: { row.enabled },
                set: { enabled in
                    Task { await save(order: payload?.order ?? [], disabled: AssistantModelOrder.toggle(row.id, enabled: enabled, disabled: payload?.disabled ?? [])) }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(row.tier == "paid")
            .accessibilityIdentifier("assistant.settings.toggle.\(row.id)")
        }
    }

    private func statusText(_ row: AssistantModelRow) -> String {
        var parts = [text("assistant.tier.\(row.tier)")]
        if row.tier == "paid" {
            parts.append(text("assistant.reason.paid_blocked"))
        } else if row.keyProvider != nil {
            parts.append(text(row.configured ? "assistant.settings.keySet" : "assistant.settings.keyMissing"))
        }
        if let reachable = row.reachable {
            parts.append(reachable ? text("assistant.settings.answers") : text(AssistantReason.known.contains(row.detail) ? AssistantReason.key(row.detail) : "assistant.settings.noAnswer"))
        }
        if let remaining = row.remainingToday {
            parts.append(String(format: text("assistant.settings.remaining"), L10n.number(Double(remaining), fractionDigits: 0, store.language)))
        }
        return parts.joined(separator: " · ")
    }

    private func statusColor(_ row: AssistantModelRow) -> Color {
        switch row.reachable {
        case .some(true): return .green
        case .some(false): return .orange
        case .none: return .secondary
        }
    }

    private func load(check: Bool) async {
        isChecking = check
        defer { isChecking = false }
        do {
            payload = try await OrchestratorClient.assistantModels(check: check)
            failed = false
        } catch {
            failed = payload == nil
        }
    }

    private func save(order: [String], disabled: [String]) async {
        do {
            payload = try await OrchestratorClient.saveAssistantModels(order: order, disabled: disabled)
        } catch {
            failed = payload == nil
        }
    }
}
