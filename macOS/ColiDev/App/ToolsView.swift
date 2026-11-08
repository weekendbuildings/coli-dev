import AppKit
import SwiftUI

private enum ToolStatusState {
    case ready, missing, checking

    var symbol: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .missing: return "xmark.circle.fill"
        case .checking: return "clock"
        }
    }

    var tint: Color {
        switch self {
        case .ready: return ColiDevVisualSystem.managementSources.color
        case .missing: return ColiDevVisualSystem.managementReviewDue.color
        case .checking: return Color.secondary
        }
    }
}

private struct ToolStatusLine: Identifiable {
    let text: String
    let state: ToolStatusState
    var id: String { text }
}

private struct ToolCard<Actions: View>: View {
    let id: String
    let title: String
    let purpose: String
    var rule: String?
    var statuses: [ToolStatusLine] = []
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityIdentifier("tools.title.\(id)")
            Text(purpose)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let rule {
                Label(rule, systemImage: "exclamationmark.shield")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(statuses) { status in
                Label {
                    Text(status.text).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: status.state.symbol).foregroundStyle(status.state.tint)
                }
                .font(.callout)
                .accessibilityIdentifier("tools.status.\(id)")
            }
            actions()
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .coliContentCard(tint: AppPalette.accent.color)
    }
}

/// Экран запускает только то, что уже стоит на Mac: ничего не устанавливает и не встраивает.
/// The screen only launches what is already on this Mac: it installs and bundles nothing.
struct ToolsView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var backendSupervisor: LocalBackendSupervisor
    @AppStorage(ToolLaunch.workFolderDefaultsKey) private var rememberedFolder = ""
    @State private var openCodePath: String?
    @State private var hermesPath: String?
    @State private var openClawPath: String?
    @State private var didCheckPaths = false
    @State private var ollamaResponds: Bool?
    @State private var ollamaHasModel = false
    @State private var obsidianResponds: Bool?
    @State private var openClawTask = ""
    @State private var launchError: String?

    let openServiceKeys: () -> Void

    private let probeSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 2
        return URLSession(configuration: configuration)
    }()

    private var home: String { FileManager.default.homeDirectoryForCurrentUser.path }
    private var workFolder: String {
        rememberedFolder.isEmpty ? ToolLaunch.defaultWorkFolder(home: home) : rememberedFolder
    }

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(text("tools.title"))
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityIdentifier("tools.screen")
                Text(text("tools.subtitle"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let launchError {
                    Label(launchError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(ColiDevVisualSystem.managementReviewDue.color)
                        .accessibilityIdentifier("tools.error")
                }
                openCodeCard
                hermesCard
                openClawCard
                ollamaCard
                obsidianCard
                notebookCard
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppPalette.canvas.color)
        .task {
            if await backendSupervisor.ensureRunning() {
                await store.refreshProviderSecretStatuses()
            }
        }
        .task {
            // Статус живой: Ollama и Obsidian могут включить, пока экран открыт.
            // The status is live: Ollama and Obsidian may start while this screen is open.
            while !Task.isCancelled {
                await refreshStatuses()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    private var openCodeCard: some View {
        ToolCard(
            id: "opencode",
            title: "OpenCode",
            purpose: text("tools.opencode.purpose"),
            rule: text("tools.opencode.rule"),
            statuses: [pathStatus(openCodePath, expected: ToolLaunch.openCodeCandidates()[0])]
        ) {
            folderLaunchRow(toolID: "opencode", executable: openCodePath, arguments: [])
        }
    }

    private var hermesCard: some View {
        ToolCard(
            id: "hermes",
            title: "Hermes",
            purpose: text("tools.hermes.purpose"),
            rule: text("tools.hermes.rule"),
            statuses: [pathStatus(hermesPath, expected: ToolLaunch.hermesCandidates(home: home)[0])]
        ) {
            folderLaunchRow(toolID: "hermes", executable: hermesPath, arguments: ["chat", "-t", "file"])
        }
    }

    private var openClawCard: some View {
        ToolCard(
            id: "openclaw",
            title: "OpenClaw",
            purpose: text("tools.openclaw.purpose"),
            rule: text("tools.openclaw.rule"),
            statuses: [pathStatus(openClawPath, expected: ToolLaunch.openClawCandidates(home: home)[0])]
        ) {
            HStack(spacing: 10) {
                TextField(text("tools.openclaw.task"), text: $openClawTask)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("tools.openclaw.task")
                Button(text("tools.open"), action: launchOpenClaw)
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent.color)
                    .disabled(
                        openClawPath == nil
                        || openClawTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    .accessibilityIdentifier("tools.action.openclaw")
            }
        }
    }

    private var ollamaCard: some View {
        ToolCard(
            id: "ollama",
            title: "Ollama",
            purpose: text("tools.ollama.purpose"),
            statuses: [ollamaStatus]
        ) {
            EmptyView()
        }
    }

    private var obsidianCard: some View {
        ToolCard(
            id: "obsidian",
            title: "Obsidian",
            purpose: text("tools.obsidian.purpose"),
            statuses: [obsidianKeyStatus, obsidianPortStatus]
        ) {
            HStack(spacing: 10) {
                Button(text("tools.obsidian.open")) { openLink("obsidian://open") }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent.color)
                    .accessibilityIdentifier("tools.action.obsidian")
                Button(text("tools.obsidian.keys"), action: openServiceKeys)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("tools.action.obsidian-keys")
            }
        }
    }

    private var notebookCard: some View {
        ToolCard(
            id: "notebook",
            title: "Gemini Notebook",
            purpose: text("tools.notebook.purpose"),
            rule: text("tools.notebook.hint")
        ) {
            Button(text("tools.open")) { openLink(ToolLaunch.notebookURL) }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.accent.color)
                .accessibilityIdentifier("tools.action.notebook")
        }
    }

    private func folderLaunchRow(toolID: String, executable: String?, arguments: [String]) -> some View {
        HStack(spacing: 10) {
            Button(text("tools.runInFolder")) {
                guard let executable, let folder = chooseFolder() else { return }
                launch(toolID: toolID, directory: folder, executable: executable, arguments: arguments)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.accent.color)
            .disabled(executable == nil)
            .accessibilityIdentifier("tools.action.\(toolID)")
            Text(String(format: text("tools.folder"), workFolder))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func pathStatus(_ path: String?, expected: String) -> ToolStatusLine {
        if !didCheckPaths {
            return ToolStatusLine(text: text("tools.checking"), state: .checking)
        }
        if let path {
            return ToolStatusLine(text: String(format: text("tools.found"), path), state: .ready)
        }
        return ToolStatusLine(text: String(format: text("tools.notFound"), expected), state: .missing)
    }

    private var ollamaStatus: ToolStatusLine {
        switch ollamaResponds {
        case nil:
            return ToolStatusLine(text: text("tools.checking"), state: .checking)
        case false?:
            return ToolStatusLine(text: text("tools.ollama.down"), state: .missing)
        case true?:
            return ollamaHasModel
                ? ToolStatusLine(text: String(format: text("tools.ollama.ready"), ToolLaunch.ollamaAgentModel), state: .ready)
                : ToolStatusLine(text: String(format: text("tools.ollama.noModel"), ToolLaunch.ollamaAgentModel), state: .missing)
        }
    }

    // Значение ключа сюда не приходит: backend сообщает только, сохранён ли он.
    // The key value never reaches this screen: the backend only reports whether it is saved.
    private var obsidianKeyStatus: ToolStatusLine {
        guard let status = store.providerSecretStatuses["obsidian"] else {
            return ToolStatusLine(text: text("tools.obsidian.keyUnknown"), state: .checking)
        }
        return status.configured
            ? ToolStatusLine(text: text("tools.obsidian.keyReady"), state: .ready)
            : ToolStatusLine(text: text("tools.obsidian.keyMissing"), state: .missing)
    }

    private var obsidianPortStatus: ToolStatusLine {
        switch obsidianResponds {
        case nil:
            return ToolStatusLine(text: text("tools.checking"), state: .checking)
        case true?:
            return ToolStatusLine(text: text("tools.obsidian.portOpen"), state: .ready)
        case false?:
            return ToolStatusLine(text: text("tools.obsidian.portClosed"), state: .missing)
        }
    }

    private func refreshStatuses() async {
        openCodePath = ToolLaunch.firstExecutable(in: ToolLaunch.openCodeCandidates())
        hermesPath = ToolLaunch.firstExecutable(in: ToolLaunch.hermesCandidates(home: home))
        openClawPath = ToolLaunch.firstExecutable(in: ToolLaunch.openClawCandidates(home: home))
        didCheckPaths = true

        let tags: Data? = await probe(ToolLaunch.ollamaTagsURL)
        ollamaResponds = tags != nil
        ollamaHasModel = tags.map { ToolLaunch.ollamaHasModel(ToolLaunch.ollamaAgentModel, tagsJSON: $0) } ?? false
        obsidianResponds = await probe(ToolLaunch.obsidianRESTURL) != nil
    }

    /// Любой HTTP-ответ, даже 401, значит, что служба на месте.
    /// Any HTTP answer, even 401, means the service is there.
    private func probe(_ address: String) async -> Data? {
        guard let url = URL(string: address) else { return nil }
        return try? await probeSession.data(from: url).0
    }

    private func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: workFolder, isDirectory: true)
        panel.prompt = text("tools.folderPrompt")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        rememberedFolder = url.path
        return url
    }

    private func launchOpenClaw() {
        guard let openClawPath else { return }
        let task: String = openClawTask.trimmingCharacters(in: .whitespacesAndNewlines)
        launch(
            toolID: "openclaw",
            directory: URL(fileURLWithPath: home).appendingPathComponent("agent-work", isDirectory: true),
            executable: openClawPath,
            arguments: ["agent", "--local", "--session-id", "work", "--message", task]
        )
    }

    private func launch(toolID: String, directory: URL, executable: String, arguments: [String]) {
        launchError = nil
        let script: String = ToolLaunch.scriptText(
            directory: directory.path,
            executable: executable,
            arguments: arguments,
            missingFolderMessage: String(format: text("tools.folderMissing"), directory.path)
        )
        do {
            let url: URL = try ToolLaunch.writeScript(
                script,
                toolID: toolID,
                in: FileManager.default.temporaryDirectory
            )
            if !NSWorkspace.shared.open(url) {
                launchError = text("tools.launchFailed")
            }
        } catch {
            launchError = text("tools.launchFailed")
        }
    }

    private func openLink(_ address: String) {
        launchError = nil
        guard let url = URL(string: address), NSWorkspace.shared.open(url) else {
            launchError = String(format: text("tools.openFailed"), address)
            return
        }
    }
}
