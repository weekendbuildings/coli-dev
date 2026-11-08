import Foundation

/// Чистая логика экрана «Инструменты»: пути, экранирование и текст скрипта запуска.
/// Pure logic for the Tools screen: paths, shell quoting and the launch script text.
enum ToolLaunch {
    static let ollamaTagsURL = "http://127.0.0.1:11434/api/tags"
    static let ollamaAgentModel = "qwen35-agent"
    static let obsidianRESTURL = "http://127.0.0.1:27123/"
    static let notebookURL = "https://notebook.google.com"
    static let workFolderDefaultsKey = "colidev.tools.workFolder"

    static func openCodeCandidates() -> [String] {
        ["/opt/homebrew/bin/opencode"]
    }

    static func hermesCandidates(home: String) -> [String] {
        ["\(home)/.local/bin/hermes"]
    }

    /// OpenClaw ставится через `npm -g`, поэтому смотрим и в его типичные папки.
    /// OpenClaw is installed with `npm -g`, so its usual global folders are checked too.
    static func openClawCandidates(home: String) -> [String] {
        [
            "/opt/homebrew/bin/openclaw",
            "/opt/homebrew/lib/node_modules/openclaw/openclaw.mjs",
            "/usr/local/bin/openclaw",
            "\(home)/.npm-global/bin/openclaw",
        ]
    }

    static func firstExecutable(
        in candidates: [String],
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> String? {
        candidates.first(where: isExecutable)
    }

    static func defaultWorkFolder(
        home: String,
        directoryExists: (String) -> Bool = { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    ) -> String {
        let project = "\(home)/Desktop/coli-dev 4/coli-dev"
        return directoryExists(project) ? project : home
    }

    /// В одинарных кавычках оболочка ничего не раскрывает: путь и текст задачи остаются просто текстом.
    /// Nothing expands inside single quotes: the path and the task text stay plain text.
    static func shellQuoted(_ value: String) -> String {
        let clean: String = value.replacingOccurrences(of: "\0", with: "")
        return "'" + clean.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Скрипт удаляет себя, переходит в папку и заменяется агентом. Флагов автоодобрения здесь нет.
    /// The script removes itself, enters the folder and becomes the agent. No auto-approve flags here.
    static func scriptText(
        directory: String,
        executable: String,
        arguments: [String] = [],
        missingFolderMessage: String
    ) -> String {
        let command: [String] = [executable] + arguments
        let quotedCommand: String = command.map(shellQuoted).joined(separator: " ")
        let lines: [String] = [
            "#!/bin/zsh",
            "rm -f -- \"$0\"",
            "export PATH=\"/opt/homebrew/bin:$HOME/.local/bin:$PATH\"",
            "cd -- \(shellQuoted(directory)) || { print -r -- \(shellQuoted(missingFolderMessage)); exit 1; }",
            "exec \(quotedCommand)",
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    /// Файл `.command` с правами только для владельца: Finder откроет его в Терминале.
    /// An owner-only `.command` file: Finder opens it in Terminal.
    static func writeScript(_ text: String, toolID: String, in temporaryDirectory: URL) throws -> URL {
        let url: URL = temporaryDirectory.appendingPathComponent("colidev-\(toolID)-\(UUID().uuidString).command")
        try Data(text.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    static func ollamaHasModel(_ model: String, tagsJSON: Data) -> Bool {
        struct Tags: Decodable {
            struct Model: Decodable { let name: String }
            let models: [Model]
        }
        guard let tags = try? JSONDecoder().decode(Tags.self, from: tagsJSON) else { return false }
        return tags.models.contains { $0.name == model || $0.name.hasPrefix(model + ":") }
    }
}
