import AppKit
import SwiftUI

// «Память»: the Obsidian vault read inside the app — list, search and the note as text. Plain file reading only: no
// Obsidian API key, nothing is written. «Открыть в Obsidian» hands the note to Obsidian. Helpers: MemoryVault (HUD core).
// «Память»: хранилище Obsidian внутри приложения — список, поиск и заметка. Только чтение файлов: без ключа API
// Obsidian, ничего не записывается. «Открыть в Obsidian» передаёт заметку в Obsidian.

struct MemoryNote: Identifiable, Equatable {
    let url: URL
    let relative: String
    let modified: Date
    var id: String { url.path }
    var title: String { url.deletingPathExtension().lastPathComponent }
    var folder: String { (relative as NSString).deletingLastPathComponent }
}

@MainActor
final class MemoryModel: ObservableObject {
    @Published private(set) var notes: [MemoryNote] = []
    @Published private(set) var shown: [MemoryNote] = []
    @Published private(set) var loading = false
    @Published var query = "" { didSet { search() } }
    @Published var selected: MemoryNote? { didSet { read() } }
    @Published private(set) var text = ""
    private var searchTask: Task<Void, Never>?

    var vault: URL? {
        guard let path = UserDefaults.standard.string(forKey: MemoryVault.defaultsKey), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    func load() {
        guard let vault else { notes = []; shown = []; return }
        loading = true
        Task.detached(priority: .userInitiated) {
            var found: [MemoryNote] = []
            let base = vault.standardizedFileURL.path
            let walker = FileManager.default.enumerator(at: vault, includingPropertiesForKeys: [.contentModificationDateKey],
                                                       options: [.skipsHiddenFiles, .skipsPackageDescendants])
            while let url = walker?.nextObject() as? URL, found.count < MemoryVault.maxFiles {
                let relative = String(url.standardizedFileURL.path.dropFirst(base.count + 1))
                guard MemoryVault.isNote(relativePath: relative) else { continue }
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                found.append(MemoryNote(url: url, relative: relative, modified: modified))
            }
            let sorted = found.sorted { $0.modified > $1.modified }
            await MainActor.run {
                self.notes = sorted
                self.loading = false
                self.search()
            }
        }
    }

    private func search() {
        searchTask?.cancel()
        let query = self.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { shown = notes; return }
        let notes = self.notes
        searchTask = Task.detached(priority: .userInitiated) {
            var hits: [MemoryNote] = []
            for note in notes {
                if Task.isCancelled { return }
                let text = (try? Data(contentsOf: note.url, options: .mappedIfSafe)).map { String(decoding: $0.prefix(MemoryVault.maxBytes), as: UTF8.self) } ?? ""
                if MemoryVault.matches(query: query, name: note.relative, text: text) { hits.append(note) }
                if hits.count >= 300 { break }
            }
            let found = hits
            await MainActor.run { if !Task.isCancelled { self.shown = found } }
        }
    }

    private func read() {
        guard let selected, let data = try? Data(contentsOf: selected.url) else { text = ""; return }
        text = MemoryVault.readable(MemoryVault.body(String(decoding: data.prefix(MemoryVault.maxBytes), as: UTF8.self)))
    }
}

struct MemoryView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = MemoryModel()

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(text("memory.title"), systemImage: "brain").font(.headline)
                Spacer()
                if let vault = model.vault {
                    Text(PracticeEnvironment.tilde(vault)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Button(text("memory.choose")) { if MemoryFolderPicker.choose() { model.load() } }
                Button(text("workshop.close")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            if model.vault == nil {
                VStack(spacing: 12) {
                    Text(text("memory.noVault")).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button(text("memory.choose")) { if MemoryFolderPicker.choose() { model.load() } }.buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    VStack(spacing: 0) {
                        TextField(text("memory.search"), text: $model.query).textFieldStyle(.roundedBorder).padding(8)
                        List(model.shown, selection: Binding(get: { model.selected?.id }, set: { id in model.selected = model.shown.first { $0.id == id } })) { note in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title).lineLimit(1)
                                Text(note.folder.isEmpty ? "/" : note.folder).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .tag(note.id)
                        }
                        Text(model.loading ? text("memory.loading") : String(format: text("memory.count"), String(model.shown.count), String(model.notes.count)))
                            .font(.caption).foregroundStyle(.secondary).padding(6)
                    }
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
                    VStack(alignment: .leading, spacing: 0) {
                        if let note = model.selected {
                            HStack {
                                Text(note.title).font(.title3.weight(.semibold)).lineLimit(2)
                                Spacer()
                                Button(text("memory.openInObsidian")) {
                                    if let url = MemoryVault.obsidianURL(path: note.url.path) { NSWorkspace.shared.open(url) }
                                }
                            }
                            .padding(12)
                            Divider()
                            ScrollView { WorkshopMarkdown(source: model.text).padding(16).frame(maxWidth: .infinity, alignment: .leading) }
                        } else {
                            Text(text("memory.pick")).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(minWidth: 380)
                }
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .onAppear { model.load() }
    }
}

enum MemoryFolderPicker {
    /// The owner picks the vault folder; only its path is stored. / Владелец выбирает папку хранилища; хранится только путь.
    @MainActor static func choose() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        UserDefaults.standard.set(url.path, forKey: MemoryVault.defaultsKey)
        return true
    }
}

/// «Память» in Settings: the vault folder. / «Память» в настройках: папка хранилища.
struct WorkshopMemorySection: View {
    @EnvironmentObject private var store: LearningStore
    @AppStorage(MemoryVault.defaultsKey) private var vault = ""

    var body: some View {
        Section {
            HStack {
                Text(vault.isEmpty ? L10n.text("memory.noVaultShort", store.language) : PracticeEnvironment.tilde(URL(fileURLWithPath: vault)))
                    .foregroundStyle(vault.isEmpty ? .secondary : .primary).lineLimit(1)
                Spacer()
                Button(L10n.text("memory.choose", store.language)) { _ = MemoryFolderPicker.choose() }
            }
            Text(L10n.text("memory.help", store.language)).font(.caption).foregroundStyle(.secondary)
        } header: {
            Text(L10n.text("memory.settingsTitle", store.language))
        }
    }
}
