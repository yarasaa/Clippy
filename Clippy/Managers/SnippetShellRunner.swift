//
//  SnippetShellRunner.swift
//  Clippy
//
//  Runs the `{{SHELL:…}}` placeholder in a snippet.
//
//  Deliberately outside `KeywordExpansionManager`. That class is
//  main-actor isolated — it reads the CoreData view context for
//  `{{CLIPBOARD}}` and nested snippets — and running a subprocess there
//  means the UI waits for the subprocess. Everything here is pure
//  string and Process work with no shared state, so it is safe to call
//  from a background queue, which is the only place it should be
//  called from.
//

import Foundation

nonisolated enum SnippetShellRunner {

    /// Longest a snippet command may run before it is killed. A
    /// placeholder that hasn't produced its text in five seconds is not
    /// doing what a snippet placeholder is for.
    private static let timeout: TimeInterval = 5

    /// Most output spliced into a snippet. Anything past this is still
    /// drained (see `run`) but discarded — the cap is about not pasting
    /// a megabyte into someone's email, not about the child process.
    private static let maxOutputBytes = 1 << 20   // 1 MB

    private static let placeholderRegex = try! NSRegularExpression(pattern: #"\{\{SHELL:([^}]+)\}\}"#)

    /// Whether `content` has anything for this runner to do. Lets the
    /// caller skip the background hop entirely for the overwhelming
    /// majority of snippets, which contain no shell placeholder at all.
    static func hasPlaceholder(in content: String) -> Bool {
        content.contains("{{SHELL:")
    }

    /// Replace every `{{SHELL:cmd}}` with the command's output.
    ///
    /// Call this off the main thread.
    static func resolve(in content: String) -> String {
        var result = content
        let matches = placeholderRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        // Reversed so each replacement leaves the earlier ranges valid.
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let fullRange = Range(match.range, in: content),
                  let commandRange = Range(match.range(at: 1), in: content) else { continue }

            let command = String(content[commandRange]).trimmingCharacters(in: .whitespaces)
            result.replaceSubrange(fullRange, with: run(command))
        }
        return result
    }

    private static func run(_ command: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        // Without this a command that reads stdin inherits ours and
        // waits forever for input that never comes.
        task.standardInput = FileHandle.nullDevice

        let exited = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in exited.signal() }

        do {
            try task.run()
        } catch {
            NSLog("[Clippy] Snippet shell command failed to launch: \(error.localizedDescription)")
            return "[SHELL failed]"
        }

        // Drain the pipe WHILE the command runs.
        //
        // This is the whole point of the rewrite. Reading only after
        // `waitUntilExit()` deadlocks: the pipe buffer is 64 KB, and once
        // it fills the command blocks trying to write while we block
        // waiting for it to exit. Neither side can ever move again, and
        // because this used to run on the main actor it took the entire
        // app with it — force quit was the only way out. stdout and
        // stderr share this pipe, so the buffer filled twice as fast.
        //
        // Draining past `maxOutputBytes` rather than stopping is
        // deliberate: stop reading and the child blocks on write, which
        // is the same deadlock by a different route.
        let handle = pipe.fileHandleForReading
        var collected = Data()
        let readerDone = DispatchSemaphore(value: 0)

        Thread.detachNewThread {
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }          // EOF
                if collected.count < maxOutputBytes {
                    collected.append(chunk)
                }
            }
            readerDone.signal()
        }

        var timedOut = false
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            task.terminate()                        // SIGTERM
            if exited.wait(timeout: .now() + 1) == .timedOut {
                kill(task.processIdentifier, SIGKILL)
                _ = exited.wait(timeout: .now() + 1)
            }
        }

        // The reader exits on EOF, which arrives once the child and any
        // children holding the write end are gone. Bounded so a stray
        // grandchild keeping the pipe open can't strand this thread.
        _ = readerDone.wait(timeout: .now() + 1)
        try? handle.close()

        if timedOut {
            NSLog("[Clippy] Snippet shell command timed out after \(Int(timeout))s: \(command)")
            return "[SHELL timed out]"
        }

        // An empty result is a normal outcome — plenty of commands
        // legitimately print nothing — so it is left empty rather than
        // marked. Only launch failure and timeout get a marker, because
        // those mean the snippet itself is broken and silently pasting
        // nothing would hide that.
        guard let output = String(data: collected.prefix(maxOutputBytes), encoding: .utf8) else { return "" }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
