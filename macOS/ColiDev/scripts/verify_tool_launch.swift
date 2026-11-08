import Foundation

// Проверяет запуск инструментов: опасный текст не исполняется, а до агента доходит как есть.
// Verifies tool launching: hostile text is not executed and reaches the agent unchanged.

func require(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

@main
struct VerifyToolLaunch {
    static func main() throws {
        require(ToolLaunch.shellQuoted("a b") == "'a b'", "spaces stay inside quotes")
        require(ToolLaunch.shellQuoted("it's") == "'it'\\''s'", "an apostrophe is escaped")

        let root: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("verify-tool-launch-\(UUID().uuidString)", isDirectory: true)
        let folder: URL = root.appendingPathComponent("coli dev's $HOME `x`", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let trap: URL = root.appendingPathComponent("trap")
        let message = "задача'; touch \(trap.path); echo '$(touch \(trap.path)) `touch \(trap.path)` !x\nвторая строка"
        let printer: URL = root.appendingPathComponent("print args")
        try Data("#!/bin/zsh\npwd\nfor a in \"$@\"; do print -r -- \"$a\"; done\n".utf8).write(to: printer)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: printer.path)

        let script: String = ToolLaunch.scriptText(
            directory: folder.path,
            executable: printer.path,
            arguments: ["--message", message],
            missingFolderMessage: "missing"
        )
        for flag in ["--auto", "--yolo"] {
            require(!script.contains(flag), "the script must not auto-approve: \(flag)")
        }
        let file: URL = try ToolLaunch.writeScript(script, toolID: "test", in: root)
        require(file.pathExtension == "command", "Terminal opens only .command files")
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        require((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700, "owner-only executable")

        let output = Pipe()
        let process = Process()
        process.executableURL = file
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        require(process.terminationStatus == 0, "the script finishes cleanly")
        let expected: String = [folder.resolvingSymlinksInPath().path, "--message", message].joined(separator: "\n") + "\n"
        require(
            printed == expected || printed == [folder.path, "--message", message].joined(separator: "\n") + "\n",
            "folder and task text must reach the agent unchanged: \(printed)"
        )
        require(!FileManager.default.fileExists(atPath: trap.path), "task text must never run as a command")
        require(!FileManager.default.fileExists(atPath: file.path), "the temporary script removes itself")

        let missing = ToolLaunch.scriptText(
            directory: root.appendingPathComponent("no such folder").path,
            executable: printer.path,
            missingFolderMessage: "no folder"
        )
        let missingFile: URL = try ToolLaunch.writeScript(missing, toolID: "missing", in: root)
        let missingRun = Process()
        missingRun.executableURL = missingFile
        missingRun.standardOutput = Pipe()
        missingRun.standardError = Pipe()
        try missingRun.run()
        missingRun.waitUntilExit()
        require(missingRun.terminationStatus == 1, "a missing folder must stop before the agent starts")

        require(
            ToolLaunch.firstExecutable(in: ["/a", "/b"], isExecutable: { $0 == "/b" }) == "/b",
            "the first working path wins"
        )
        require(
            ToolLaunch.firstExecutable(in: ["/a"], isExecutable: { _ in false }) == nil,
            "a missing tool is reported as missing"
        )
        require(
            ToolLaunch.defaultWorkFolder(home: "/h", directoryExists: { _ in true }) == "/h/Desktop/coli-dev 4/coli-dev",
            "the project folder is the default"
        )
        require(
            ToolLaunch.defaultWorkFolder(home: "/h", directoryExists: { _ in false }) == "/h",
            "home is the fallback folder"
        )

        let tags = Data(#"{"models":[{"name":"bge-m3:latest"},{"name":"qwen35-agent:latest"}]}"#.utf8)
        require(ToolLaunch.ollamaHasModel("qwen35-agent", tagsJSON: tags), "the agent model is found by tag")
        require(!ToolLaunch.ollamaHasModel("qwen3", tagsJSON: tags), "a name prefix is not the model")
        require(!ToolLaunch.ollamaHasModel("qwen35-agent", tagsJSON: Data("{}".utf8)), "bad JSON means no model")

        print("OK: tool launch")
    }
}
